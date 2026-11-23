from datetime import datetime, timedelta

from app.data_sources import KST, HourlyCondition
from app.recommender import build_recommendations, pick_course, score_hour

NOW = datetime(2026, 11, 23, 17, 0, tzinfo=KST)


def h(offset=0, weather="맑음", temp=15.0, air="좋음", crowd="여유"):
    return HourlyCondition(NOW + timedelta(hours=offset), weather, temp, air, crowd)


def test_perfect_conditions_are_good():
    r = score_hour(h(), "run")
    assert r["score"] == 100 and r["rating"] == "좋음"
    assert any("공원 전체" in c for c in r["cautions"])


def test_rain_is_not_recommended_even_with_high_score():
    r = score_hour(h(weather="비"), "run")
    assert r["score"] >= 75
    assert r["rating"] == "야외운동 비권장"


def test_very_bad_air_and_extreme_temp_are_not_recommended():
    assert score_hour(h(air="매우나쁨"), "walk")["rating"] == "야외운동 비권장"
    assert score_hour(h(temp=34), "walk")["rating"] == "야외운동 비권장"
    assert score_hour(h(temp=-12), "walk")["rating"] == "야외운동 비권장"


def test_missing_data_is_flagged_not_invented():
    r = score_hour(h(weather=None, air=None, crowd=None), "walk")
    assert r["score"] == 85
    assert {"날씨 정보가 없습니다", "대기질 정보가 없습니다", "공원 혼잡 전망 정보가 없습니다"} <= set(r["cautions"])


def test_running_penalizes_crowding_more():
    assert score_hour(h(crowd="붐빔"), "run")["score"] < score_hour(h(crowd="붐빔"), "walk")["score"]


def test_score_is_clamped():
    r = score_hour(h(weather="흐림", temp=-5, air="나쁨", crowd="붐빔"), "run")
    assert 0 <= r["score"] <= 100 and r["rating"] == "주의"


def test_preference_sorted_first_and_unsafe_after_safe():
    # 17시(오후), 18시(저녁·비), 19시(저녁), 12시(오후) — 17시는 오후 구간(12~17시)
    hours = [h(0), h(1, weather="비"), h(2), h(-5)]
    recs = build_recommendations(hours, "run", "evening", NOW)
    assert [r["time_label"] for r in recs] == ["오늘 19:00", "오늘 18:00", "오늘 12:00", "오늘 17:00"]
    assert recs[1]["rating"] == "야외운동 비권장"  # 선호 시간대 안에서 비권장은 안전한 시간 뒤
    assert all(not k.startswith("_") for r in recs for k in r)


def test_night_hours_ranked_last_with_caution():
    night = h(9)  # 다음날 02시
    recs = build_recommendations([night, h(0, crowd="붐빔")], "walk", "any", NOW)
    assert recs[-1]["time_label"] == "내일 02:00"
    assert any("심야" in c for c in recs[-1]["cautions"])


def test_pick_course_closest_distance():
    courses = [{"id": "a", "distance_km": 1.3}, {"id": "b", "distance_km": 2.21}, {"id": "c", "distance_km": 3.15}, {"id": "d", "distance_km": 4.29}]
    assert pick_course(courses, 2)["id"] == "b"
    assert pick_course(courses, 3)["id"] == "c"
    assert pick_course(courses, 5)["id"] == "d"
    assert pick_course([], 3) is None


def test_missing_preferred_slot_adds_notice():
    hours = [h(i) for i in range(1, 7)]  # 18~23시: 저녁만
    recs = build_recommendations(hours, "run", "morning", NOW)
    assert all(r["cautions"][0] == "선택한 시간대(아침)가 향후 12시간 안에 없어 다른 시간대를 보여줍니다" for r in recs)


def test_present_preferred_slot_has_no_notice():
    recs = build_recommendations([h(1), h(2)], "run", "evening", NOW)
    recs += build_recommendations([h(1)], "run", "any", NOW)
    assert not any("선택한 시간대" in c for r in recs for c in r["cautions"])
