"""데모 모드 전용 샘플 데이터. 실제 관측·예보 값이 아니다.

- 시연에서 '좋음 / 보통 / 주의 / 야외운동 비권장'이 모두 보이도록 현재 시각 기준 오프셋으로 패턴을 만든다.
- 여기 값은 화면과 응답에서 반드시 '샘플'로 표시된다 (data_status = "sample").
"""
from datetime import datetime, timedelta

from .data_sources import HourlyCondition

# 오프셋(현재 시각 이후 n시간)별 샘플 패턴: (날씨, 기온, 대기질, 공원 혼잡)
_PATTERN: list[tuple[str, float, str, str]] = [
    ("맑음", 11.0, "좋음", "보통"),       # +0
    ("맑음", 10.0, "좋음", "여유"),       # +1
    ("구름많음", 9.0, "보통", "여유"),    # +2
    ("비", 8.0, "보통", "여유"),          # +3  → 악천후: 야외운동 비권장
    ("비", 8.0, "좋음", "여유"),          # +4
    ("흐림", 7.0, "보통", "여유"),        # +5
    ("흐림", 7.0, "나쁨", "여유"),        # +6  → 대기질 나쁨: 주의
    ("구름많음", 6.0, "보통", "여유"),    # +7
    ("맑음", 6.0, "좋음", "여유"),        # +8
    ("맑음", 5.0, "좋음", "여유"),        # +9
    ("맑음", 5.0, "좋음", "보통"),        # +10
    ("맑음", 6.0, "보통", "약간 붐빔"),   # +11
    ("맑음", 8.0, "보통", "붐빔"),        # +12
]


def build_sample_conditions(now: datetime) -> list[HourlyCondition]:
    start = now.replace(minute=0, second=0, microsecond=0)
    hours = []
    for offset, (weather, temp, air, crowd) in enumerate(_PATTERN):
        hours.append(
            HourlyCondition(
                time=start + timedelta(hours=offset),
                weather=weather,
                temperature_c=temp,
                air_quality=air,
                park_crowding=crowd,
            )
        )
    return hours
