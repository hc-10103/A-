"""설명 가능한 규칙 기반 추천.

⚠ 모든 가중치는 '초기 설계값'이다. 검증된 예측 모델이 아니다.
- 입력: 시간별 날씨·기온·대기질·공원 단위 혼잡도
- 행사 일정은 점수에 반영하지 않는다 (별도 주의 정보로만 제공 — 중복 반영 방지)
- 악천후 / 위험 대기질 / 극한 기온이면 점수와 무관하게 '야외운동 비권장'
"""
from __future__ import annotations

from datetime import datetime

from .data_sources import HourlyCondition

# ---- 초기 설계값 (팀에서 조정) -------------------------------------------
WEATHER_PENALTY = {"맑음": 0, "구름조금": 0, "구름많음": 5, "흐림": 10, "강수 없음": 0}
HAZARD_WEATHER_KEYWORDS = ("비", "눈", "소나기", "뇌우", "우박", "폭우", "폭설")
AIR_PENALTY = {"좋음": 0, "보통": 10, "나쁨": 35}
HAZARD_AIR = {"매우나쁨", "매우 나쁨"}
CROWD_PENALTY = {"여유": 0, "보통": 5, "약간 붐빔": 15, "붐빔": 25}
RUN_CROWD_MULTIPLIER = 1.4   # 러닝은 혼잡의 영향을 더 크게 본다
HOT_C, COLD_C = 33.0, -10.0  # 극한 기온 기준 (초기 설계값)
MISSING_PENALTY = 5          # 항목 하나가 비어 있을 때 신뢰도 감점

SLOTS = {"morning": range(5, 12), "afternoon": range(12, 18), "evening": range(18, 24)}
CROWD_SCOPE_CAUTION = "혼잡도는 공원 전체 기준이며 코스별 혼잡도를 뜻하지 않습니다"


def slot_of(t: datetime) -> str | None:
    for name, hours in SLOTS.items():
        if t.hour in hours:
            return name
    return None  # 심야(0~4시)


def score_hour(h: HourlyCondition, activity: str) -> dict:
    score = 100
    reasons: list[str] = []
    cautions: list[str] = []
    hazard = False

    # 날씨
    if h.weather is None:
        score -= MISSING_PENALTY
        cautions.append("날씨 정보가 없습니다")
    elif any(k in h.weather for k in HAZARD_WEATHER_KEYWORDS):
        hazard = True
        reasons.append(f"강수 예보({h.weather})가 있어 야외운동을 권장하지 않습니다")
    else:
        p = WEATHER_PENALTY.get(h.weather, 10)
        score -= p
        if h.weather == "강수 없음":
            reasons.append("현재 강수가 없습니다 (하늘 상태 정보 없음)")
        else:
            reasons.append(f"날씨가 {h.weather}입니다" if p == 0 else f"날씨가 {h.weather}로 다소 불리합니다")

    # 기온
    if h.temperature_c is not None:
        if h.temperature_c >= HOT_C or h.temperature_c <= COLD_C:
            hazard = True
            reasons.append(f"기온 {h.temperature_c:.0f}°C로 극한 기온 기준을 벗어납니다")
        elif h.temperature_c < 0:
            score -= 10
            cautions.append("영하 기온입니다. 보온과 미끄럼에 유의하세요")

    # 대기질
    if h.air_quality is None:
        score -= MISSING_PENALTY
        cautions.append("대기질 정보가 없습니다")
    elif h.air_quality in HAZARD_AIR:
        hazard = True
        reasons.append("대기질이 매우 나쁨으로 야외운동을 권장하지 않습니다")
    else:
        p = AIR_PENALTY.get(h.air_quality, 10)
        score -= p
        reasons.append("대기질이 양호합니다" if p == 0 else f"대기질이 {h.air_quality}입니다")

    # 공원 단위 혼잡
    if h.park_crowding is None:
        score -= MISSING_PENALTY
        cautions.append("공원 혼잡 전망 정보가 없습니다")
    else:
        p = CROWD_PENALTY.get(h.park_crowding, 10)
        if activity == "run":
            p = round(p * RUN_CROWD_MULTIPLIER)
        score -= p
        reasons.append(
            "공원 전체 혼잡 전망이 낮은 편입니다" if p == 0 else f"공원 전체 혼잡 전망이 '{h.park_crowding}'입니다"
        )
        cautions.append(CROWD_SCOPE_CAUTION)

    score = max(0, min(100, int(score)))
    if hazard:
        rating = "야외운동 비권장"
        cautions.insert(0, "안전을 우선해 실내 운동이나 다른 시간대를 고려하세요")
    elif score >= 75:
        rating = "좋음"
    elif score >= 50:
        rating = "보통"
    else:
        rating = "주의"

    return {"score": score, "rating": rating, "reasons": reasons, "cautions": cautions}


def time_label(t: datetime, now: datetime) -> str:
    day = "오늘" if t.date() == now.date() else "내일"
    return f"{day} {t:%H:%M}"


def build_recommendations(hours: list[HourlyCondition], activity: str, preference: str, now: datetime) -> list[dict]:
    items = []
    for h in hours:
        result = score_hour(h, activity)
        night = slot_of(h.time) is None
        if night:
            result["cautions"].append("심야 시간대입니다. 공원 개방·조명 여부를 공식 안내로 확인하세요")
        items.append(
            {
                "time_label": time_label(h.time, now),
                "time_iso": h.time.isoformat(timespec="seconds"),
                **result,
                "conditions": {"weather": h.weather, "air_quality": h.air_quality, "park_crowding": h.park_crowding},
                "_preferred": preference == "any" or slot_of(h.time) == preference,
                "_safe": result["rating"] != "야외운동 비권장",
                "_night": night,
            }
        )
    # 선호 시간대 우선 → 안전 → 심야 후순위 → 점수 → 이른 시각
    items.sort(key=lambda x: (not x["_preferred"], not x["_safe"], x["_night"], -x["score"], x["time_iso"]))
    for x in items:
        for k in ("_preferred", "_safe", "_night"):
            x.pop(k)
    return items


def pick_course(courses: list[dict], target_km: float) -> dict | None:
    if not courses:
        return None
    return min(courses, key=lambda c: (abs(c["distance_km"] - target_km), c["distance_km"]))
