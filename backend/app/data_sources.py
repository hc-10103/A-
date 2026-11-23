"""데이터 어댑터 계층.

- 데모 모드: sample_data.py (실제 값 아님)
- 실 모드: 서울시 실시간 도시데이터 어댑터
  · 응답 구조는 2026-11-23 공개 sample 키(광화문·덕수궁) 실제 응답으로 확인함
  · 올림픽공원 장소명/코드는 인증키로 아직 확인하지 못함 → SEOUL_CITYDATA_AREA 로 설정
- KSPO 어댑터: 미구현 (어떤 데이터셋을 쓸지 미정)

원칙: 데이터가 없으면 None 으로 두고 data_status 로 알린다. 임의 값으로 채우지 않는다.
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import time
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Optional
from urllib.parse import quote
from zoneinfo import ZoneInfo

import httpx

log = logging.getLogger(__name__)

KST = ZoneInfo("Asia/Seoul")
SHARED_DIR = Path(__file__).resolve().parents[2] / "shared"

FORECAST_HOURS = 12
CACHE_TTL_SEC = 300            # 서울시 인구 데이터 갱신 주기(5분)에 맞춘 캐시
STALE_AFTER = timedelta(minutes=90)  # 이보다 오래된 관측값은 '오래됨'으로 표시 (초기 설계값)


@dataclass
class HourlyCondition:
    time: datetime
    weather: Optional[str] = None          # 맑음 / 구름많음 / 흐림 / 비 / 눈 / 강수 없음 ...
    temperature_c: Optional[float] = None
    air_quality: Optional[str] = None      # 좋음 / 보통 / 나쁨 / 매우나쁨
    park_crowding: Optional[str] = None    # 서울시 공원 단위: 여유 / 보통 / 약간 붐빔 / 붐빔


@dataclass
class ConditionBundle:
    hours: list[HourlyCondition]
    data_status: str                       # sample / live / partial / unavailable
    sources: list[dict] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)
    events: Optional[list[dict]] = None    # 실 모드에서 서울시 EVENT_STTS 로 받은 행사 (None = 받지 못함)


def now_kst() -> datetime:
    return datetime.now(KST)


# ---------------------------------------------------------------- 정적 데이터
def load_courses() -> list[dict]:
    data = json.loads((SHARED_DIR / "courses.json").read_text(encoding="utf-8"))
    return data["courses"]


def load_sample_events(target: date) -> list[dict]:
    data = json.loads((SHARED_DIR / "events.sample.json").read_text(encoding="utf-8"))
    return [
        {**ev, "date": target.isoformat(), "is_sample": True}
        for ev in data["events"]
        if ev["date"] in ("DEMO", target.isoformat())
    ]


def load_events(target: date, demo: bool) -> list[dict]:
    if demo:
        return load_sample_events(target)
    bundle = SeoulCityDataAdapter().fetch()
    return filter_events_by_date(bundle.events or [], target)


def filter_events_by_date(events: list[dict], target: date) -> list[dict]:
    """기간이 target 을 포함하는 행사만 남긴다. 기간을 알 수 없는 행사는 남긴다."""
    out = []
    for ev in events:
        start, end = ev.get("_period") or (None, None)
        if start and end and not (start <= target <= end):
            continue
        clean = {k: v for k, v in ev.items() if k != "_period"}
        out.append({**clean, "date": target.isoformat()})
    return out


# ---------------------------------------------------------------- 조건 데이터
def get_conditions(demo: bool) -> ConditionBundle:
    now = now_kst()
    if demo:
        from .sample_data import build_sample_conditions

        return ConditionBundle(
            hours=build_sample_conditions(now),
            data_status="sample",
            sources=[{"name": "샘플 데이터 (데모 — 실제 관측값 아님)", "updated_at": now.isoformat(timespec="seconds")}],
        )
    return SeoulCityDataAdapter().fetch()


_cache: dict[str, tuple[float, dict]] = {}


class SeoulCityDataAdapter:
    """서울시 실시간 도시데이터 (data.seoul.go.kr, OA-21285).

    사용 필드 (sample 응답으로 확인):
      WEATHER_STTS[0]: WEATHER_TIME, TEMP, PRECPT_TYPE, AIR_IDX,
                       FCST24HOURS[]{FCST_DT 'YYYYMMDDHHMM', TEMP, PRECPT_TYPE, SKY_STTS, RAIN_CHANCE}
      LIVE_PPLTN_STTS[0]: PPLTN_TIME, AREA_CONGEST_LVL, FCST_PPLTN[]{FCST_TIME 'YYYY-MM-DD HH:MM', FCST_CONGEST_LVL}
      EVENT_STTS[]: EVENT_NM, EVENT_PERIOD 'YYYY-MM-DD~YYYY-MM-DD', EVENT_PLACE, URL
    대기질은 현재값(AIR_IDX)만 있고 시간별 예보가 없다.
    """

    BASE = "http://openapi.seoul.go.kr:8088/{key}/json/citydata/1/5/{area}"

    def __init__(self) -> None:
        self.key = os.getenv("SEOUL_OPEN_API_KEY", "").strip()
        self.area = os.getenv("SEOUL_CITYDATA_AREA", "").strip()

    def fetch(self) -> ConditionBundle:
        if not self.key or not self.area:
            return ConditionBundle(
                hours=[],
                data_status="unavailable",
                notes=["SEOUL_OPEN_API_KEY 또는 SEOUL_CITYDATA_AREA 가 설정되지 않아 실데이터를 가져오지 못했습니다."],
            )
        try:
            payload = self._get_json()
        except Exception as exc:  # noqa: BLE001 — 외부 API 실패는 상태로만 전달
            log.warning("Seoul citydata fetch failed: %s", exc)
            return ConditionBundle(hours=[], data_status="unavailable", notes=["서울시 도시데이터 호출에 실패했습니다."])
        return parse_citydata(payload, now_kst())

    def _get_json(self) -> dict:
        url = self.BASE.format(key=quote(self.key), area=quote(self.area))
        hit = _cache.get(url)
        if hit and time.monotonic() - hit[0] < CACHE_TTL_SEC:
            return hit[1]
        resp = httpx.get(url, timeout=10)
        resp.raise_for_status()
        payload = resp.json()
        _cache[url] = (time.monotonic(), payload)
        return payload


def parse_citydata(payload: dict, now: datetime) -> ConditionBundle:
    """서울시 도시데이터 응답 → ConditionBundle. now 는 테스트를 위해 주입한다."""
    result = payload.get("RESULT") or {}
    code = result.get("RESULT.CODE")
    if code and code != "INFO-000":
        return ConditionBundle(
            hours=[], data_status="unavailable", notes=[f"서울시 도시데이터 오류: {result.get('RESULT.MESSAGE') or code}"]
        )

    city = payload.get("CITYDATA") or {}
    weather = _first(city.get("WEATHER_STTS")) or {}
    people = _first(city.get("LIVE_PPLTN_STTS")) or {}
    notes: list[str] = []

    start = now.replace(minute=0, second=0, microsecond=0)
    end = start + timedelta(hours=FORECAST_HOURS)
    by_hour: dict[datetime, HourlyCondition] = {}

    def slot(t: datetime) -> HourlyCondition:
        return by_hour.setdefault(t, HourlyCondition(time=t))

    # 현재 시각: 관측값
    weather_time = _parse_time(weather.get("WEATHER_TIME"))
    ppltn_time = _parse_time(people.get("PPLTN_TIME"))
    if weather:
        cur = slot(start)
        cur.weather = _weather_label(weather.get("PRECPT_TYPE"), None)
        cur.temperature_c = _to_float(weather.get("TEMP"))
        cur.air_quality = _clean(weather.get("AIR_IDX"))
    if people:
        slot(start).park_crowding = _clean(people.get("AREA_CONGEST_LVL"))

    # 향후 시간: 예보값
    for row in weather.get("FCST24HOURS") or []:
        t = _parse_time(row.get("FCST_DT"))
        if t and start < t <= end:
            h = slot(t)
            h.weather = _weather_label(row.get("PRECPT_TYPE"), row.get("SKY_STTS"))
            h.temperature_c = _to_float(row.get("TEMP"))
    for row in people.get("FCST_PPLTN") or []:
        t = _parse_time(row.get("FCST_TIME"))
        if t and start < t <= end:
            slot(t).park_crowding = _clean(row.get("FCST_CONGEST_LVL"))

    hours = sorted(by_hour.values(), key=lambda h: h.time)
    if weather and weather.get("AIR_IDX"):
        notes.append("대기질은 현재 값만 제공되어 이후 시간대는 '정보 없음'으로 표시합니다.")

    stale = [name for name, t in (("날씨", weather_time), ("인구", ppltn_time)) if t and now - t > STALE_AFTER]
    if stale:
        notes.append(f"{'·'.join(stale)} 데이터가 {int(STALE_AFTER.total_seconds() // 60)}분 이상 갱신되지 않았습니다.")

    if not hours:
        status = "unavailable"
    elif weather and people and not stale:
        status = "live"
    else:
        status = "partial"

    sources = []
    if weather:
        sources.append({"name": "서울시 실시간 도시데이터 — 날씨·대기질", "updated_at": _iso(weather_time)})
    if people:
        sources.append({"name": "서울시 실시간 도시데이터 — 인구 혼잡(공원 단위)", "updated_at": _iso(ppltn_time)})

    events = [_to_event(ev) for ev in city.get("EVENT_STTS") or [] if ev.get("EVENT_NM")]
    return ConditionBundle(hours=hours, data_status=status, sources=sources, notes=notes, events=events)


class KspoAdapter:
    """국민체육진흥공단(KSPO) 데이터 어댑터 — 미구현.
    어떤 데이터셋(예: 시설·프로그램 정보)을 쓸지 팀에서 확정한 뒤 구현한다."""

    def fetch(self) -> None:
        raise NotImplementedError("KSPO 어댑터는 아직 구현되지 않았습니다 (데이터셋 미정).")


# ---------------------------------------------------------------- helpers
def _first(value):
    if isinstance(value, list):
        return value[0] if value else None
    return value


def _clean(value) -> Optional[str]:
    """서울시 API 는 값이 없을 때 '-', '', 'None' 문자열을 쓴다."""
    if value is None:
        return None
    s = str(value).strip()
    return None if s in ("", "-", "None", "null") else s


def _weather_label(precpt_type, sky) -> Optional[str]:
    """강수가 있으면 강수 형태(비/눈/비/눈/소나기)를, 없으면 하늘 상태를 쓴다."""
    p = _clean(precpt_type)
    if p and p != "없음":
        return p
    s = _clean(sky)
    if s:
        return s
    return "강수 없음" if p == "없음" else None


def _to_float(value) -> Optional[float]:
    try:
        return float(_clean(value))  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return None


def _parse_time(value) -> Optional[datetime]:
    value = _clean(value)
    if not value:
        return None
    for fmt in ("%Y%m%d%H%M", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(value, fmt).replace(tzinfo=KST)
        except ValueError:
            continue
    return None


def _iso(t: Optional[datetime]) -> Optional[str]:
    return t.isoformat(timespec="seconds") if t else None


def _to_event(ev: dict) -> dict:
    period = _clean(ev.get("EVENT_PERIOD")) or ""
    start = end = None
    if "~" in period:
        a, b = (x.strip() for x in period.split("~", 1))
        try:
            start, end = date.fromisoformat(a), date.fromisoformat(b)
        except ValueError:
            pass
    note = f"기간 {period}" if period else None
    return {
        "id": "seoul-" + hashlib.sha1(f"{ev.get('EVENT_NM')}|{period}".encode()).hexdigest()[:10],
        "type": "event",
        "title": ev["EVENT_NM"],
        "date": "",
        "start_time": None,
        "end_time": None,
        "location": _clean(ev.get("EVENT_PLACE")),
        "note": note,
        "is_sample": False,
        "_period": (start, end),
    }
