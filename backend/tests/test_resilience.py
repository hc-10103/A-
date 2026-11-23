"""외부 API 가 느리거나 이상한 값을 줘도 추천 API 가 제때, 정상적으로 응답하는지."""
import time
from datetime import datetime

from fastapi.testclient import TestClient

from app import data_sources as ds
from app import kopis, routes
from app.data_sources import KST
from app.main import app

BODY = {"activity": "run", "target_distance_km": 3, "time_preference": "any", "demo_mode": False}


def _live(monkeypatch, citydata, fixture_now):
    monkeypatch.setenv("SEOUL_OPEN_API_KEY", "test")
    monkeypatch.setenv("SEOUL_CITYDATA_AREA", "POI127")
    monkeypatch.setattr(ds.SeoulCityDataAdapter, "_get_json", lambda self: citydata)
    monkeypatch.setattr(ds, "now_kst", lambda: fixture_now)


def test_slow_kopis_does_not_block_response(monkeypatch, citydata, fixture_now):
    _live(monkeypatch, citydata, fixture_now)
    monkeypatch.setattr(routes, "FETCH_BUDGET_SEC", 0.5)
    monkeypatch.setattr(kopis.KopisClient, "shows_on", lambda self, d: time.sleep(3) or [])
    t = time.monotonic()
    r = TestClient(app).post("/api/recommendations", json=BODY)
    elapsed = time.monotonic() - t
    assert r.status_code == 200 and elapsed < 1.5, elapsed
    j = r.json()
    assert j["data_status"] == "live" and len(j["recommendations"]) == 13
    assert not any("kopis" in s["name"] for s in j["sources"])


def test_enrichment_error_still_returns_recommendations(monkeypatch, citydata, fixture_now):
    _live(monkeypatch, citydata, fixture_now)
    monkeypatch.setattr(kopis.KopisClient, "shows_on", lambda self, d: [kopis.Show("P", "x", None, None, ["19:00"])])

    def boom(*a, **k):
        raise ValueError("bad data")

    monkeypatch.setattr(kopis, "caution_for", boom)
    r = TestClient(app).post("/api/recommendations", json=BODY)
    assert r.status_code == 200 and len(r.json()["recommendations"]) == 13


def test_midnight_24_00_show_time():
    show = kopis.Show("PF1", "카운트다운", "88잔디마당", 10000, ["24:00"])
    assert kopis.caution_for(datetime(2026, 12, 31, 23, tzinfo=KST), [show])      # 1시간 전
    assert kopis.caution_for(datetime(2026, 12, 31, 21, tzinfo=KST), [show]) == []  # 3시간 전


def test_kopis_failure_backs_off(monkeypatch):
    monkeypatch.setenv("KOPIS_API_KEY", "test")
    calls = []

    def failing_get(self, path, **params):
        calls.append(path)
        raise RuntimeError("down")

    monkeypatch.setattr(kopis.KopisClient, "_get", failing_get)
    day = datetime(2026, 11, 28).date()
    assert kopis.KopisClient().shows_on(day) is None
    assert kopis.KopisClient().shows_on(day) is None
    assert len(calls) == 1  # 두 번째는 호출하지 않는다


def test_seoul_and_airkorea_called_concurrently(monkeypatch, citydata, fixture_now):
    _live(monkeypatch, citydata, fixture_now)
    monkeypatch.setattr(ds.SeoulCityDataAdapter, "_get_json", lambda self: time.sleep(0.6) or citydata)
    monkeypatch.setattr(ds.AirKoreaForecastAdapter, "fetch", lambda self, now: time.sleep(0.6) or None)
    t = time.monotonic()
    bundle = ds.get_conditions(demo=False)
    assert bundle.data_status == "live" and time.monotonic() - t < 1.0
