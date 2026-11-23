import pytest
from fastapi.testclient import TestClient

from app import data_sources as ds
from app.main import app
from app.schemas import RecommendationResponse

client = TestClient(app)
BODY = {"activity": "run", "target_distance_km": 3, "time_preference": "evening", "demo_mode": True}


def test_health():
    assert client.get("/api/health").json() == {"status": "ok"}


def test_courses_are_the_five_official():
    names = {c["name"] for c in client.get("/api/courses").json()}
    assert names == {"호반의 길", "토성의 길", "추억의 길", "연인의 길", "젊음의 길"}


def test_demo_response_matches_contract():
    r = client.post("/api/recommendations", json=BODY)
    assert r.status_code == 200
    data = RecommendationResponse.model_validate(r.json())
    assert data.mode == "demo" and data.data_status == "sample"
    assert data.recommendations and data.course is not None
    assert all(e.is_sample for e in data.events)
    assert "공원 단위" in data.disclaimer


def test_demo_includes_safety_rating():
    recs = client.post("/api/recommendations", json={**BODY, "time_preference": "any"}).json()["recommendations"]
    assert any(r["rating"] == "야외운동 비권장" for r in recs)


@pytest.mark.parametrize("bad", [{"activity": "swim"}, {"time_preference": "night"}, {"target_distance_km": 0}])
def test_invalid_request_422(bad):
    assert client.post("/api/recommendations", json={**BODY, **bad}).status_code == 422


def test_live_without_key_is_unavailable(monkeypatch):
    monkeypatch.delenv("SEOUL_OPEN_API_KEY", raising=False)
    j = client.post("/api/recommendations", json={**BODY, "demo_mode": False}).json()
    assert j["mode"] == "live" and j["data_status"] == "unavailable"
    assert j["recommendations"] == [] and j["events"] == []


def test_live_with_mocked_api(monkeypatch, citydata, fixture_now):
    monkeypatch.setenv("SEOUL_OPEN_API_KEY", "test")
    monkeypatch.setenv("SEOUL_CITYDATA_AREA", "test-area")
    monkeypatch.setattr(ds.SeoulCityDataAdapter, "_get_json", lambda self: citydata)
    monkeypatch.setattr(ds, "now_kst", lambda: fixture_now)
    j = client.post("/api/recommendations", json={**BODY, "demo_mode": False}).json()
    RecommendationResponse.model_validate(j)
    assert j["data_status"] == "live"
    assert len(j["recommendations"]) == 13
    assert len(j["sources"]) == 3 and all(s["updated_at"] for s in j["sources"])
    assert any("한국체육산업개발" in s["name"] for s in j["sources"])
    assert j["events"] and not any(e["is_sample"] for e in j["events"])


def test_preference_outside_window_is_explained(monkeypatch, fixture_now):
    # 19:35 기준 향후 12시간(19시~다음날 07시)에는 오후가 없다
    monkeypatch.setattr(ds, "now_kst", lambda: fixture_now)
    j = client.post("/api/recommendations", json={**BODY, "time_preference": "afternoon"}).json()
    assert "선택한 시간대(오후)가 향후 12시간 안에 없어" in j["disclaimer"]
    assert j["recommendations"][0]["cautions"][0].startswith("선택한 시간대(오후)")
