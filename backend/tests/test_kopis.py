from datetime import date, datetime
from pathlib import Path

from fastapi.testclient import TestClient

from app import data_sources as ds
from app import kopis
from app.data_sources import KST
from app.main import app

FX = Path(__file__).parent / "fixtures"
LIST = (FX / "kopis_list.xml").read_text(encoding="utf-8")        # 2026-11-23 실제 응답 (shprfnmfct=올림픽, 30일)
DETAIL = (FX / "kopis_detail.xml").read_text(encoding="utf-8")    # PF302131 다이나믹 듀오 @ 올림픽홀
FACILITY = (FX / "kopis_facility.xml").read_text(encoding="utf-8")  # FC001247 올림픽공원


def test_list_keeps_only_olympic_park_running_that_day():
    ids = kopis.parse_list(LIST, date(2026, 11, 28))
    assert "PF302131" in ids and "PF301499" in ids       # 다이나믹 듀오, 조용필 (11/27~29)
    assert "PF303454" not in ids                          # 안산올림픽기념관은 제외
    assert "PF307107" not in ids                          # DAY6 는 12/18~ → 해당 없음


def test_halls_and_detail():
    halls = kopis.parse_halls(FACILITY)
    assert halls["FC001247-01"] == ("KSPO DOME(체조경기장)", 15000)
    assert halls["FC001247-03"][0] == "올림픽홀"
    d = kopis.parse_detail(DETAIL)
    assert d["mt13id"] == "FC001247-03" and d["dtguidance"].startswith("금요일(20:00)")
    show = kopis.build_show(d, halls, date(2026, 11, 28))      # 토요일
    assert (show.hall, show.seats, show.times) == ("올림픽홀", 2452, ["18:00"])


def test_times_for_day_patterns():
    g = "화요일 ~ 금요일(19:30), 토요일(14:00,18:00), 일요일(15:00), HOL(15:00)"
    assert kopis.times_for_day(g, date(2026, 11, 25)) == ["19:30"]          # 수
    assert kopis.times_for_day(g, date(2026, 11, 28)) == ["14:00", "18:00"]  # 토
    assert kopis.times_for_day(g, date(2026, 11, 23)) == []                 # 월
    assert kopis.times_for_day("금요일 ~ 월요일(20:00)", date(2026, 11, 23)) == ["20:00"]  # 주말을 걸친 범위
    assert kopis.times_for_day("", date(2026, 11, 23)) == []


def test_rest_day_is_dropped_but_unknown_schedule_kept():
    halls = kopis.parse_halls(FACILITY)
    d = kopis.parse_detail(DETAIL)
    assert kopis.build_show(d, halls, date(2026, 11, 23)) is None            # 월요일 휴연
    unknown = kopis.build_show({**d, "dtguidance": ""}, halls, date(2026, 11, 23))
    assert unknown and unknown.times == []
    assert "공연 시간 정보 없음" in kopis.to_event(unknown, date(2026, 11, 23))["note"]


def test_caution_window():
    show = kopis.Show("PF1", "테스트 콘서트", "KSPO DOME(체조경기장)", 15000, ["19:00"])
    at = lambda h: datetime(2026, 11, 27, h, tzinfo=KST)
    assert kopis.caution_for(at(16), [show]) == []            # 3시간 전
    assert kopis.caution_for(at(17), [show])                  # 2시간 전
    assert kopis.caution_for(at(22), [show])                  # 3시간 후
    assert kopis.caution_for(at(23), [show]) == []
    assert "약 15,000석" in kopis.caution_for(at(19), [show])[0]


def test_no_key_means_no_info(monkeypatch):
    monkeypatch.delenv("KOPIS_API_KEY", raising=False)
    assert kopis.KopisClient().shows_on(date(2026, 11, 28)) is None


def test_live_response_includes_kopis(monkeypatch, citydata, fixture_now):
    monkeypatch.setenv("SEOUL_OPEN_API_KEY", "test")
    monkeypatch.setenv("SEOUL_CITYDATA_AREA", "POI127")
    monkeypatch.setattr(ds.SeoulCityDataAdapter, "_get_json", lambda self: citydata)
    monkeypatch.setattr(ds, "now_kst", lambda: fixture_now)  # 2026-11-23 19:35
    show = kopis.Show("PF1", "테스트 콘서트", "KSPO DOME(체조경기장)", 15000, ["20:00"], "월요일(20:00)")
    monkeypatch.setattr(kopis.KopisClient, "shows_on", lambda self, d: [show] if d == fixture_now.date() else [])
    j = TestClient(app).post(
        "/api/recommendations", json={"activity": "run", "target_distance_km": 3, "time_preference": "any", "demo_mode": False}
    ).json()
    ev = [e for e in j["events"] if e["id"] == "kopis-PF1"]
    assert ev and ev[0]["start_time"] == "20:00" and ev[0]["location"] == "올림픽공원 KSPO DOME(체조경기장)"
    assert any(s["name"].startswith("(재)예술경영지원센터") for s in j["sources"])
    flagged = {r["time_label"] for r in j["recommendations"] if any("테스트 콘서트" in c for c in r["cautions"])}
    assert "오늘 20:00" in flagged and "오늘 23:00" in flagged and "내일 00:00" not in flagged


def test_demo_mode_does_not_call_kopis(monkeypatch):
    def boom(self, d):
        raise AssertionError("demo mode must not call KOPIS")

    monkeypatch.setattr(kopis.KopisClient, "shows_on", boom)
    r = TestClient(app).post(
        "/api/recommendations", json={"activity": "run", "target_distance_km": 3, "time_preference": "any", "demo_mode": True}
    )
    assert r.status_code == 200
