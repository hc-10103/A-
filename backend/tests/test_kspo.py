from datetime import datetime

from fastapi.testclient import TestClient

from app import data_sources as ds
from app import kspo
from app.data_sources import KST
from app.main import app

PATTERN = {
    "_meta": {"period": "2025-01-01 ~ 2025-12-31", "collected_at": "2026-11-18 00:30:06"},
    "slots": {
        "5": {"19": {"days": 46, "concert_days": 45, "avg_audience": 12596},   # 토 19시: 대부분
              "15": {"days": 50, "concert_days": 20, "avg_audience": 3000},    # 토 15시: 자주 (40%)
              "11": {"days": 50, "concert_days": 3, "avg_audience": 800},      # 토 11시: 드묾
              "3": {"days": 5, "concert_days": 5, "avg_audience": 100}},       # 표본 부족
        "1": {"19": {"days": 48, "concert_days": 0, "avg_audience": None}},
    },
}
SAT = datetime(2026, 11, 28, tzinfo=KST)  # 토요일


def test_frequent_slot_caution():
    c = kspo.concert_caution(SAT.replace(hour=19), PATTERN)
    assert c.startswith("2025년 기록상 토요일 19시는 공원 내 공연이 대부분 열린 시간대입니다")
    assert "46일 중 45일" in c and "12,596명" in c


def test_often_and_rare_and_small_sample():
    assert "자주" in kspo.concert_caution(SAT.replace(hour=15), PATTERN)
    assert kspo.concert_caution(SAT.replace(hour=11), PATTERN) is None
    assert kspo.concert_caution(SAT.replace(hour=3), PATTERN) is None
    assert kspo.concert_caution(datetime(2026, 11, 24, 19, tzinfo=KST), PATTERN) is None  # 화요일
    assert kspo.concert_caution(SAT.replace(hour=19), {}) is None


def test_source_entry_iso_time():
    s = kspo.source_entry(PATTERN)
    assert "한국체육산업개발" in s["name"] and s["updated_at"] == "2026-11-18T00:30:06+09:00"


def test_real_pattern_file_is_valid():
    p = kspo.load_pattern()
    assert p and p["_meta"]["period"].startswith("2025-01-01")
    assert set(p["slots"]) == {str(i) for i in range(7)} and all(len(v) == 24 for v in p["slots"].values())
    # 2025년 토요일 저녁은 공연이 대부분 있었다 (집계 결과 확인)
    assert "대부분" in kspo.concert_caution(SAT.replace(hour=19))


def test_caution_added_without_changing_score(monkeypatch):
    fixed = datetime(2026, 11, 28, 17, 10, tzinfo=KST)  # 토요일 17시 → 데모 시간대가 토요일 저녁에 걸침
    monkeypatch.setattr(ds, "now_kst", lambda: fixed)
    client = TestClient(app)
    body = {"activity": "run", "target_distance_km": 3, "time_preference": "any", "demo_mode": True}
    with_k = client.post("/api/recommendations", json=body).json()
    monkeypatch.setattr(kspo, "concert_caution", lambda t, pattern=None: None)
    without = client.post("/api/recommendations", json=body).json()
    flagged = [r for r in with_k["recommendations"] if any(c.startswith("2025년 기록상") for c in r["cautions"])]
    assert flagged, "토요일 저녁 시간대에 공연 주의 문구가 붙어야 한다"
    score = lambda j: {r["time_iso"]: r["score"] for r in j["recommendations"]}
    assert score(with_k) == score(without)  # 점수는 그대로
