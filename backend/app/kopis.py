"""KOPIS 공연예술통합전산망 (예술경영지원센터) — 오늘 올림픽공원 공연 일정.

2026-11-23 실호출로 확인한 내용
- 올림픽공원 = 공연시설 FC001247 (공연장 12개: KSPO DOME 15,000석, 티켓링크 라이브 아레나 5,003석, 올림픽홀 2,452석 …)
- 공연목록 pblprfr: stdate/eddate(최대 31일), shprfnmfct(공연시설명) → fcltynm 은 '올림픽공원'
- 공연상세 pblprfr/{mt20id}: fcltynm '올림픽공원 (올림픽홀)', mt13id(공연장), dtguidance '금요일(20:00), 토요일(18:00)'
- 공연시설상세 prfplc/{mt10id}: 공연장별 seatscale

원칙: 출처 표기 필수 — "(재)예술경영지원센터 공연예술통합전산망(www.kopis.or.kr)". 점수에는 반영하지 않는다.
예매처를 거쳐 등록된 공연 위주라 무료 행사 등은 빠질 수 있다.
"""
from __future__ import annotations

import logging
import os
import re
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from typing import Optional

import httpx

log = logging.getLogger(__name__)

BASE = "http://www.kopis.or.kr/openApi/restful"
FACILITY_ID = "FC001247"
FACILITY_NAME = "올림픽공원"
SOURCE_NAME = "(재)예술경영지원센터 공연예술통합전산망(www.kopis.or.kr)"
CACHE_TTL_SEC = 1800
WEEKDAY_NAMES = ["월요일", "화요일", "수요일", "목요일", "금요일", "토요일", "일요일"]
CAUTION_BEFORE = timedelta(hours=2)
CAUTION_AFTER = timedelta(hours=3)

_cache: dict[str, tuple[float, object]] = {}


@dataclass
class Show:
    id: str
    title: str
    hall: Optional[str]
    seats: Optional[int]
    times: list[str] = field(default_factory=list)   # 그날 시작 시각 'HH:MM'
    schedule_text: Optional[str] = None               # dtguidance 원문


# ---------------------------------------------------------------- 파싱
def parse_list(xml_text: str, day: date) -> list[str]:
    """공연목록에서 올림픽공원 공연 중 day 가 기간에 포함된 공연 ID."""
    ids = []
    for db in ET.fromstring(xml_text).findall("db"):
        if not (db.findtext("fcltynm") or "").strip().startswith(FACILITY_NAME):
            continue
        try:
            start = datetime.strptime(db.findtext("prfpdfrom") or "", "%Y.%m.%d").date()
            end = datetime.strptime(db.findtext("prfpdto") or "", "%Y.%m.%d").date()
        except ValueError:
            continue
        if start <= day <= end and db.findtext("mt20id"):
            ids.append(db.findtext("mt20id"))
    return ids


def parse_detail(xml_text: str) -> dict:
    db = ET.fromstring(xml_text).find("db")
    if db is None:
        return {}
    return {k: (db.findtext(k) or "").strip() for k in ("mt20id", "prfnm", "fcltynm", "mt13id", "dtguidance", "prfpdfrom", "prfpdto")}


def parse_halls(xml_text: str) -> dict[str, tuple[str, Optional[int]]]:
    """공연시설상세 → {공연장ID: (이름, 좌석수)}."""
    halls = {}
    db = ET.fromstring(xml_text).find("db")
    for h in (db.iter("mt13") if db is not None else []):
        hid = (h.findtext("mt13id") or "").strip()
        seats = re.sub(r"[^\d]", "", h.findtext("seatscale") or "")
        if hid:
            halls[hid] = ((h.findtext("prfplcnm") or "").strip(), int(seats) if seats else None)
    return halls


def times_for_day(dtguidance: str, day: date) -> list[str]:
    """'화요일 ~ 금요일(19:30), 토요일(14:00,18:00), HOL(15:00)' 에서 day 의 시작 시각들. HOL(공휴일)은 판단하지 않는다."""
    wd = day.weekday()
    out: list[str] = []
    for spec, times in re.findall(r"([^(),]+?)\s*\(([^)]*)\)", dtguidance or ""):
        spec = spec.strip()
        if "~" in spec:
            a, b = (s.strip() for s in spec.split("~", 1))
            if a in WEEKDAY_NAMES and b in WEEKDAY_NAMES:
                lo, hi = WEEKDAY_NAMES.index(a), WEEKDAY_NAMES.index(b)
                hit = lo <= wd <= hi if lo <= hi else (wd >= lo or wd <= hi)
            else:
                hit = False
        else:
            hit = spec == WEEKDAY_NAMES[wd]
        if hit:
            out += [t.strip() for t in times.split(",") if re.fullmatch(r"\d{1,2}:\d{2}", t.strip())]
    return sorted(set(out))


def hall_name(detail: dict, halls: dict) -> Optional[str]:
    if detail.get("mt13id") in halls:
        return halls[detail["mt13id"]][0]
    m = re.search(r"\((.+)\)\s*$", detail.get("fcltynm", ""))
    return m.group(1) if m else None


def has_weekday_schedule(dtguidance: str) -> bool:
    return any(name in (dtguidance or "") for name in WEEKDAY_NAMES)


def build_show(detail: dict, halls: dict, day: date) -> Optional[Show]:
    """공연 기간에 day 가 들어 있어도, 요일별 일정상 그날 공연이 없으면(휴연일) None."""
    if not detail.get("mt20id"):
        return None
    times = times_for_day(detail.get("dtguidance", ""), day)
    if not times and has_weekday_schedule(detail.get("dtguidance", "")):
        return None
    seats = halls.get(detail.get("mt13id"), (None, None))[1]
    return Show(
        id=detail["mt20id"],
        title=detail.get("prfnm") or "(공연명 없음)",
        hall=hall_name(detail, halls),
        seats=seats,
        times=times,
        schedule_text=detail.get("dtguidance") or None,
    )


# ---------------------------------------------------------------- 호출
class KopisClient:
    def __init__(self) -> None:
        self.key = os.getenv("KOPIS_API_KEY", "").strip()

    def _get(self, path: str, **params) -> str:
        cache_key = f"{path}|{sorted(params.items())}"
        hit = _cache.get(cache_key)
        if hit and time.monotonic() - hit[0] < CACHE_TTL_SEC:
            return hit[1]  # type: ignore[return-value]
        r = httpx.get(f"{BASE}/{path}", params={"service": self.key, **params}, timeout=15)
        r.raise_for_status()
        _cache[cache_key] = (time.monotonic(), r.text)
        return r.text

    def shows_on(self, day: date) -> Optional[list[Show]]:
        """day 에 올림픽공원에서 열리는 공연. 키가 없거나 실패하면 None (= 정보 없음)."""
        if not self.key:
            return None
        try:
            ymd = day.strftime("%Y%m%d")
            ids = parse_list(self._get("pblprfr", stdate=ymd, eddate=ymd, cpage=1, rows=100, shprfnmfct=FACILITY_NAME), day)
            halls = parse_halls(self._get(f"prfplc/{FACILITY_ID}")) if ids else {}
            shows = [build_show(parse_detail(self._get(f"pblprfr/{i}")), halls, day) for i in ids]
            return [s for s in shows if s]
        except Exception as exc:  # noqa: BLE001
            log.warning("KOPIS fetch failed: %s", exc)
            return None


# ---------------------------------------------------------------- 응답 변환
def to_event(show: Show, day: date) -> dict:
    parts = []
    if show.schedule_text:
        parts.append(f"공연 시간: {show.schedule_text}")
    else:
        parts.append("공연 시간 정보 없음")
    if show.seats:
        parts.append(f"공연장 규모 약 {show.seats:,}석")
    parts.append("출처: KOPIS")
    return {
        "id": f"kopis-{show.id}",
        "type": "event",
        "title": show.title,
        "date": day.isoformat(),
        "start_time": show.times[0] if show.times else None,
        "end_time": None,
        "location": f"{FACILITY_NAME} {show.hall}" if show.hall else FACILITY_NAME,
        "note": " · ".join(parts),
        "is_sample": False,
    }


def caution_for(t: datetime, shows: list[Show]) -> list[str]:
    """추천 시각 t 가 오늘 공연 시작 2시간 전 ~ 3시간 후 사이면 주의 문구."""
    out = []
    for s in shows:
        for hhmm in s.times:
            h, m = map(int, hhmm.split(":"))
            start = t.replace(hour=h, minute=m, second=0, microsecond=0)
            if start - CAUTION_BEFORE <= t <= start + CAUTION_AFTER:
                where = s.hall or "공원 내 공연장"
                size = f"(약 {s.seats:,}석)" if s.seats else ""
                out.append(f"오늘 {hhmm} {where}{size}에서 '{s.title}' 공연이 예정되어 있습니다. 공연 전후 공연장·출입구 주변이 붐빌 수 있습니다")
                break
    return out


def source_entry(fetched_at: datetime) -> dict:
    return {"name": SOURCE_NAME, "updated_at": fetched_at.isoformat(timespec="seconds")}
