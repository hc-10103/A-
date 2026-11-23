import logging
import time
from datetime import date, datetime, timedelta

from fastapi import APIRouter, Query

from . import data_sources as ds
from . import kopis, kspo
from .recommender import build_recommendations, pick_course, preference_unavailable_note
from .schemas import Course, Event, RecommendationRequest, RecommendationResponse

router = APIRouter(prefix="/api")
log = logging.getLogger(__name__)

# 추천 API 전체가 프론트 타임아웃(10초) 안에 끝나도록 외부 호출에 쓰는 시간 상한
FETCH_BUDGET_SEC = 8.0

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
    deadline = time.monotonic() + FETCH_BUDGET_SEC
    # KOPIS(오늘·내일)는 날씨·혼잡 데이터와 동시에 부른다. 실데이터 모드에서만.
    kopis_futures = {}
    if not req.demo_mode:
        client = kopis.KopisClient()
        kopis_futures = {d: ds.fetch_pool.submit(client.shows_on, d) for d in (now.date(), now.date() + timedelta(days=1))}
    bundle = ds.get_conditions(demo=req.demo_mode)
    recs = build_recommendations(bundle.hours, req.activity, req.time_preference, now)
    sources = list(bundle.sources)
    kopis_events: list[dict] = []

    # 공연 정보는 주의 문구로만 붙인다 (점수 미반영). 여기서 오류가 나도 추천 자체는 내보낸다.
    try:
        for r in recs:
            caution = kspo.concert_caution(datetime.fromisoformat(r["time_iso"]))
            if caution:
                r["cautions"].append(caution)
        kspo_src = kspo.source_entry()
        if kspo_src and bundle.hours:
            sources.append(kspo_src)
    except Exception:  # noqa: BLE001
        log.exception("KSPO concert pattern enrichment failed")

    try:
        shows_by_day = {d: ds.wait_or_none(f, deadline - time.monotonic()) for d, f in kopis_futures.items()}
        if any(v is not None for v in shows_by_day.values()):
            sources.append(kopis.source_entry(now))
        for r in recs:
            t = datetime.fromisoformat(r["time_iso"])
            r["cautions"].extend(kopis.caution_for(t, shows_by_day.get(t.date()) or []))
        kopis_events = [kopis.to_event(s, now.date()) for s in (shows_by_day.get(now.date()) or [])]
    except Exception:  # noqa: BLE001
        log.exception("KOPIS enrichment failed")
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
            else bundle.alerts + kopis_events + ds.filter_events_by_date(bundle.events or [], now.date())
        ),
        "sources": sources,
        "disclaimer": disclaimer,
    }
