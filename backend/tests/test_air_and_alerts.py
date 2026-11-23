import json
from datetime import date, datetime, timedelta
from pathlib import Path

from fastapi.testclient import TestClient

from app import data_sources as ds
from app.data_sources import (
    KST,
    AirForecast,
    apply_air_forecast,
    parse_citydata,
    parse_disaster_messages,
    parse_dust_forecast,
)
from app.main import app
from app.recommender import score_hour

ITEMS = json.loads((Path(__file__).parent / "fixtures" / "airkorea_forecast.json").read_text(encoding="utf-8"))["items"]


# ---------------------------------------------------------------- 에어코리아 예보 파싱
def test_forecast_uses_latest_issue_and_worse_of_pm10_pm25():
    fc = parse_dust_forecast(ITEMS, "서울")
    assert fc.grades[date(2026, 11, 23)] == "보통"      # 05시 '나쁨'보다 17시 '보통'이 최신, PM2.5 좋음
    assert fc.grades[date(2026, 11, 24)] == "매우나쁨"  # PM10 좋음 vs PM2.5 매우나쁨 → 나쁜 쪽
    assert date(2026, 11, 25) not in fc.grades           # 서울 등급이 없는 날은 비워 둔다
    assert fc.issued_at == datetime(2026, 11, 23, 17, tzinfo=KST)


def test_forecast_empty_or_garbage_returns_none():
    assert parse_dust_forecast([], "서울") is None
    assert parse_dust_forecast([{"informData": "x", "informGrade": "서울 : 보통"}], "서울") is None


def test_apply_forecast_fills_only_missing_hours(citydata, fixture_now):
    bundle = parse_citydata(citydata, fixture_now)
    apply_air_forecast(bundle, parse_dust_forecast(ITEMS, "서울"))
    cur, later = bundle.hours[0], bundle.hours[1:]
    assert cur.air_quality == "보통" and not cur.air_quality_is_forecast   # 관측값 유지
    assert all(h.air_quality_is_forecast for h in later)
    assert {h.air_quality for h in later if h.time.date() == date(2026, 11, 24)} == {"매우나쁨"}
    assert not any(n.startswith("대기질은 현재 값만") for n in bundle.notes)
    assert any("에어코리아" in s["name"] for s in bundle.sources)


def test_apply_none_keeps_bundle(citydata, fixture_now):
    bundle = parse_citydata(citydata, fixture_now)
    apply_air_forecast(bundle, None)
    assert all(h.air_quality is None for h in bundle.hours[1:])
    assert any(n.startswith("대기질은 현재 값만") for n in bundle.notes)


def test_forecast_very_bad_air_is_not_recommended_and_labelled():
    h = ds.HourlyCondition(datetime(2026, 11, 24, 7, tzinfo=KST), "맑음", 5.0, "매우나쁨", "여유", air_quality_is_forecast=True)
    r = score_hour(h, "run")
    assert r["rating"] == "야외운동 비권장"
    assert any("일 단위 예보" in x for x in r["reasons"])


def test_adapter_without_key_returns_none(monkeypatch):
    monkeypatch.delenv("DATA_GO_KR_API_KEY", raising=False)
    assert ds.AirKoreaForecastAdapter().fetch(datetime.now(KST)) is None


# ---------------------------------------------------------------- 재난문자
NOW = datetime(2026, 11, 23, 19, 35, tzinfo=KST)


def test_disaster_message_becomes_notice():
    raw = [{"DST_SE_NM": "한파", "EMRG_STEP_NM": "안전안내", "MSG_CN": "한파특보 발효 중. 외출 자제", "CRT_DT": "2026-11-23 18:10:00"}]
    [n] = parse_disaster_messages(raw, NOW)
    assert n["type"] == "notice" and n["title"] == "[재난문자] 한파 · 안전안내"
    assert n["note"] == "한파특보 발효 중. 외출 자제" and n["start_time"] == "18:10" and n["is_sample"] is False


def test_disaster_message_old_or_empty_is_dropped():
    old = {"MSG_CN": "어제 문자", "CRT_DT": (NOW - timedelta(hours=30)).strftime("%Y-%m-%d %H:%M:%S")}
    assert parse_disaster_messages([old, {"DST_SE_NM": "호우"}, "x"], NOW) == []
    assert parse_disaster_messages(None, NOW) == []
    assert parse_disaster_messages({}, NOW) == []


def test_live_response_puts_alert_first_in_events(monkeypatch, citydata, fixture_now):
    citydata["CITYDATA"]["LIVE_DST_MESSAGE"] = [{"MSG_CN": "강풍 주의", "CRT_DT": "2026-11-23 19:00:00"}]
    monkeypatch.setenv("SEOUL_OPEN_API_KEY", "test")
    monkeypatch.setenv("SEOUL_CITYDATA_AREA", "POI127")
    monkeypatch.setattr(ds.SeoulCityDataAdapter, "_get_json", lambda self: citydata)
    monkeypatch.setattr(ds, "now_kst", lambda: fixture_now)
    monkeypatch.setattr(
        ds.AirKoreaForecastAdapter, "fetch", lambda self, now: AirForecast({date(2026, 11, 23): "나쁨", date(2026, 11, 24): "좋음"}, None)
    )
    j = TestClient(app).post(
        "/api/recommendations", json={"activity": "run", "target_distance_km": 3, "time_preference": "any", "demo_mode": False}
    ).json()
    assert j["events"][0]["title"] == "[재난문자]" and j["events"][0]["note"] == "강풍 주의"
    assert j["recommendations"] and all(r["conditions"]["air_quality"] for r in j["recommendations"])
    assert "에어코리아" in j["disclaimer"]
