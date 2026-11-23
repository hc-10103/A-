"""데이터 어댑터 계층.

- 데모 모드: sample_data.py (실제 값 아님)
- 실 모드: 서울시 실시간 도시데이터 어댑터 (⚠ 응답 필드 미검증 — docs/API_CONTRACT.md 참고)
- KSPO 어댑터: 미구현 (어떤 데이터셋을 쓸지 미정)

원칙: 데이터가 없으면 None 으로 두고 data_status 로 알린다. 임의 값으로 채우지 않는다.
"""
from __future__ import annotations

import json
import logging
import os
from dataclasses import dataclass, field
from datetime import date, datetime
from pathlib import Path
from typing import Optional
from zoneinfo import ZoneInfo

import httpx

log = logging.getLogger(__name__)

KST = ZoneInfo("Asia/Seoul")
SHARED_DIR = Path(__file__).resolve().parents[2] / "shared"


@dataclass
class HourlyCondition:
    time: datetime
    weather: Optional[str] = None          # 맑음 / 구름많음 / 흐림 / 비 / 눈 ...
    temperature_c: Optional[float] = None
    air_quality: Optional[str] = None      # 좋음 / 보통 / 나쁨 / 매우나쁨
    park_crowding: Optional[str] = None    # 서울시 공원 단위: 여유 / 보통 / 약간 붐빔 / 붐빔


@dataclass
class ConditionBundle:
    hours: list[HourlyCondition]
    data_status: str                       # sample / live / partial / unavailable
    sources: list[dict] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def now_kst() -> datetime:
    return datetime.now(KST)


# ---------------------------------------------------------------- 정적 데이터
def load_courses() -> list[dict]:
    data = json.loads((SHARED_DIR / "courses.json").read_text(encoding="utf-8"))
    return data["courses"]


def load_events(target: date, demo: bool) -> list[dict]:
    """실제 행사 데이터 소스는 아직 없다. 데모 모드에서만 샘플을 돌려준다."""
    if not demo:
        return []  # TODO(B/C): 실제 행사·공지 소스 확정 후 연결
    data = json.loads((SHARED_DIR / "events.sample.json").read_text(encoding="utf-8"))
    events = []
    for ev in data["events"]:
        if ev["date"] in ("DEMO", target.isoformat()):
            events.append({**ev, "date": target.isoformat(), "is_sample": True})
    return events


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


class SeoulCityDataAdapter:
    """서울시 실시간 도시데이터 (data.seoul.go.kr).

    ⚠ 미검증: 아래 필드명은 공개 문서 기준 추정이다. 실제 응답으로 확인하기 전까지
    파싱 실패 시 partial/unavailable 로 내려가며, 값을 만들어 채우지 않는다.
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
            resp = httpx.get(self.BASE.format(key=self.key, area=self.area), timeout=10)
            resp.raise_for_status()
            return self._parse(resp.json())
        except Exception as exc:  # noqa: BLE001 — 외부 API 실패는 상태로만 전달
            log.warning("Seoul citydata fetch failed: %s", exc)
            return ConditionBundle(hours=[], data_status="unavailable", notes=["서울시 도시데이터 호출에 실패했습니다."])

    def _parse(self, payload: dict) -> ConditionBundle:
        city = payload.get("CITYDATA") or {}
        weather = _first(city.get("WEATHER_STTS"))
        people = _first(city.get("LIVE_PPLTN_STTS"))
        notes: list[str] = []
        by_hour: dict[datetime, HourlyCondition] = {}

        for row in (weather or {}).get("FCST24HOURS") or []:
            t = _parse_time(row.get("FCST_DT"))
            if t:
                by_hour.setdefault(t, HourlyCondition(time=t)).weather = row.get("SKY_STTS") or None
                by_hour[t].temperature_c = _to_float(row.get("TEMP"))
        for row in (people or {}).get("FCST_PPLTN") or []:
            t = _parse_time(row.get("FCST_TIME"))
            if t:
                by_hour.setdefault(t, HourlyCondition(time=t)).park_crowding = row.get("FCST_CONGEST_LVL") or None

        # 대기질은 현재 값만 있으므로 가장 이른 시각에만 붙이고, 이후 시각은 None 으로 둔다.
        air_now = (weather or {}).get("AIR_IDX") or None
        hours = sorted(by_hour.values(), key=lambda h: h.time)
        if hours and air_now:
            hours[0].air_quality = air_now
        if air_now:
            notes.append("대기질은 현재 값만 제공되어 이후 시간대는 '정보 없음'으로 표시합니다.")

        status = "live" if hours and weather and people else ("partial" if hours else "unavailable")
        sources = []
        if weather:
            sources.append({"name": "서울시 실시간 도시데이터 — 날씨", "updated_at": weather.get("WEATHER_TIME")})
        if people:
            sources.append({"name": "서울시 실시간 도시데이터 — 인구(공원 단위)", "updated_at": people.get("PPLTN_TIME")})
        return ConditionBundle(hours=hours, data_status=status, sources=sources, notes=notes)


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


def _to_float(value) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _parse_time(value) -> Optional[datetime]:
    if not value:
        return None
    for fmt in ("%Y%m%d%H%M", "%Y-%m-%d %H:%M"):
        try:
            return datetime.strptime(str(value), fmt).replace(tzinfo=KST)
        except ValueError:
            continue
    return None
