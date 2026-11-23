from datetime import date, timedelta

from app.data_sources import filter_events_by_date, parse_citydata


def test_parses_real_sample_as_live(citydata, fixture_now):
    b = parse_citydata(citydata, fixture_now)
    assert b.data_status == "live"
    # 현재 시각 + 향후 12시간
    assert len(b.hours) == 13
    assert b.hours[0].time.hour == 19
    assert b.hours[-1].time - b.hours[0].time == timedelta(hours=12)


def test_current_hour_uses_observation(citydata, fixture_now):
    cur = parse_citydata(citydata, fixture_now).hours[0]
    assert cur.temperature_c == 9.4
    assert cur.air_quality == "보통"
    assert cur.park_crowding == "여유"
    assert cur.weather == "강수 없음"  # 현재 관측에는 하늘 상태가 없다


def test_air_quality_only_for_current_hour(citydata, fixture_now):
    b = parse_citydata(citydata, fixture_now)
    assert all(h.air_quality is None for h in b.hours[1:])
    assert any("대기질은 현재 값만" in n for n in b.notes)


def test_forecast_uses_sky_when_no_precip(citydata, fixture_now):
    nxt = parse_citydata(citydata, fixture_now).hours[1]
    assert nxt.weather == "흐림"
    assert nxt.park_crowding == "여유"


def test_precipitation_overrides_sky(citydata, fixture_now):
    citydata["CITYDATA"]["WEATHER_STTS"][0]["FCST24HOURS"][0]["PRECPT_TYPE"] = "비"
    nxt = parse_citydata(citydata, fixture_now).hours[1]
    assert nxt.weather == "비"


def test_stale_data_becomes_partial(citydata, fixture_now):
    b = parse_citydata(citydata, fixture_now + timedelta(hours=3))
    assert b.data_status == "partial"
    assert any("갱신되지 않았습니다" in n for n in b.notes)


def test_missing_population_is_partial(citydata, fixture_now):
    del citydata["CITYDATA"]["LIVE_PPLTN_STTS"]
    b = parse_citydata(citydata, fixture_now)
    assert b.data_status == "partial"
    assert all(h.park_crowding is None for h in b.hours)


def test_api_error_code_is_unavailable(fixture_now):
    payload = {"RESULT": {"RESULT.CODE": "ERROR-500", "RESULT.MESSAGE": "서버 오류"}}
    b = parse_citydata(payload, fixture_now)
    assert b.data_status == "unavailable"
    assert b.hours == []


def test_events_filtered_by_period(citydata, fixture_now):
    events = parse_citydata(citydata, fixture_now).events
    assert len(events) == 3
    assert len(filter_events_by_date(events, date(2026, 11, 23))) == 3
    # 2026-12-06: 12-05에 끝나는 행사는 빠진다
    later = filter_events_by_date(events, date(2026, 12, 6))
    assert len(later) == 2
    assert all("_period" not in e and e["is_sample"] is False for e in later)
