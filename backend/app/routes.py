from datetime import date

from fastapi import APIRouter, Query

from . import data_sources as ds
from .recommender import build_recommendations, pick_course, preference_unavailable_note
from .schemas import Course, Event, RecommendationRequest, RecommendationResponse

router = APIRouter(prefix="/api")

DISCLAIMER = (
    "추천 점수는 제공 데이터에 기반한 참고 정보이며 가중치는 초기 설계값입니다. "
    "혼잡도는 공원 단위이며 코스별 혼잡도가 아닙니다."
)


@router.get("/health")
def health() -> dict:
    return {"status": "ok"}


@router.get("/courses", response_model=list[Course])
def courses() -> list[dict]:
    return ds.load_courses()


@router.get("/events", response_model=list[Event])
def events(date_: date | None = Query(default=None, alias="date"), demo_mode: bool = True) -> list[dict]:
    return ds.load_events(date_ or ds.now_kst().date(), demo=demo_mode)


@router.post("/recommendations", response_model=RecommendationResponse)
def recommendations(req: RecommendationRequest) -> dict:
    now = ds.now_kst()
    bundle = ds.get_conditions(demo=req.demo_mode)
    recs = build_recommendations(bundle.hours, req.activity, req.time_preference, now)
    notes = list(bundle.notes)
    pref_note = preference_unavailable_note(bundle.hours, req.time_preference)
    if pref_note:
        notes.insert(0, pref_note + ".")
    disclaimer = DISCLAIMER
    if notes:
        disclaimer += " " + " ".join(notes)
    return {
        "generated_at": now.isoformat(timespec="seconds"),
        "mode": "demo" if req.demo_mode else "live",
        "data_status": bundle.data_status,
        "recommendations": recs,
        "course": pick_course(ds.load_courses(), req.target_distance_km),
        "events": (
            ds.load_sample_events(now.date())
            if req.demo_mode
            else ds.filter_events_by_date(bundle.events or [], now.date())
        ),
        "sources": bundle.sources,
        "disclaimer": disclaimer,
    }
