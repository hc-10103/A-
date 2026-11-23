"""한국체육산업개발(KSPO&CO) 데이터 활용.

2025년 올림픽공원 시간대별 공연 기록을 요일·시간대 패턴으로 집계한 정적 파일(shared/kspo_concert_pattern_2025.json)을
읽어, 추천 시간대에 '과거 공연이 자주 열린 시간대' 주의 문구를 붙인다.

원칙
- 2025년 기록 기반 참고 정보다. 올해 공연 일정이나 혼잡 예측처럼 표현하지 않는다.
- 점수에는 반영하지 않는다 (행사 정보는 주의 정보로만 — 지시서 원칙).
- 파일 생성: backend/scripts/build_kspo_concert_pattern.py
"""
from __future__ import annotations

import json
from datetime import datetime
from functools import lru_cache
from pathlib import Path
from typing import Optional

PATTERN_FILE = Path(__file__).resolve().parents[2] / "shared" / "kspo_concert_pattern_2025.json"
WEEKDAYS = "월화수목금토일"

# 초기 설계값: 2025년 같은 요일·시간대에 공연이 있던 날의 비율
FREQUENT = 0.7   # "대부분"
OFTEN = 0.3      # "자주"
MIN_DAYS = 10    # 표본이 너무 적은 칸은 쓰지 않는다


@lru_cache(maxsize=1)
def load_pattern(path: Path = PATTERN_FILE) -> Optional[dict]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return None


def concert_caution(t: datetime, pattern: Optional[dict] = None) -> Optional[str]:
    """t 의 요일·시간대가 2025년에 공연이 자주 열린 칸이면 주의 문구를 돌려준다."""
    pattern = pattern if pattern is not None else load_pattern()
    if not pattern:
        return None
    cell = (pattern.get("slots") or {}).get(str(t.weekday()), {}).get(str(t.hour))
    if not cell or cell.get("days", 0) < MIN_DAYS:
        return None
    days, hits = cell["days"], cell["concert_days"]
    rate = hits / days
    if rate < OFTEN:
        return None
    how = "대부분" if rate >= FREQUENT else "자주"
    aud = cell.get("avg_audience")
    aud_txt = f", 평균 관람객 약 {aud:,}명" if aud else ""
    return (
        f"2025년 기록상 {WEEKDAYS[t.weekday()]}요일 {t.hour}시는 공원 내 공연이 {how} 열린 시간대입니다"
        f"({days}일 중 {hits}일{aud_txt}). 공연장·출입구 주변이 붐빌 수 있습니다"
    )


def _iso_kst(value: Optional[str]) -> Optional[str]:
    """'2026-11-18 00:30:06' → '2026-11-18T00:30:06+09:00' (프론트 Date 파싱용)."""
    if not value:
        return None
    try:
        return datetime.strptime(value[:19], "%Y-%m-%d %H:%M:%S").isoformat() + "+09:00"
    except ValueError:
        return None


def source_entry(pattern: Optional[dict] = None) -> Optional[dict]:
    pattern = pattern if pattern is not None else load_pattern()
    if not pattern:
        return None
    meta = pattern.get("_meta") or {}
    return {
        "name": f"한국체육산업개발 올림픽공원 공연 기록 ({meta.get('period', '2025')}, 참고)",
        "updated_at": _iso_kst(meta.get("collected_at")),
    }
