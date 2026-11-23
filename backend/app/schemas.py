"""API 요청/응답 스키마 — OLPARK_RUN_VIBE_CODING.md 3절 계약과 1:1로 맞춘다.
계약을 바꾸려면 docs/API_CONTRACT.md 를 먼저 고치고 팀 합의 후 반영한다."""
from typing import Literal, Optional

from pydantic import BaseModel, Field

Activity = Literal["run", "walk"]
TimePreference = Literal["morning", "afternoon", "evening", "any"]
Rating = Literal["좋음", "보통", "주의", "야외운동 비권장"]
DataStatus = Literal["sample", "live", "partial", "unavailable"]


class RecommendationRequest(BaseModel):
    activity: Activity
    target_distance_km: float = Field(gt=0, le=50)
    time_preference: TimePreference = "any"
    demo_mode: bool = True


class Conditions(BaseModel):
    weather: Optional[str] = None
    air_quality: Optional[str] = None
    park_crowding: Optional[str] = None


class TimeRecommendation(BaseModel):
    time_label: str
    time_iso: str
    score: int = Field(ge=0, le=100)
    rating: Rating
    reasons: list[str]
    conditions: Conditions
    cautions: list[str]


class Course(BaseModel):
    id: str
    name: str
    distance_km: float
    description: str
    map_url: Optional[str] = None


class Event(BaseModel):
    id: str
    type: Literal["event", "notice"]
    title: str
    date: str
    start_time: Optional[str] = None
    end_time: Optional[str] = None
    location: Optional[str] = None
    note: Optional[str] = None
    is_sample: bool = False


class Source(BaseModel):
    name: str
    updated_at: Optional[str] = None


class RecommendationResponse(BaseModel):
    generated_at: str
    mode: Literal["demo", "live"]
    data_status: DataStatus
    recommendations: list[TimeRecommendation]
    course: Optional[Course]
    events: list[Event]
    sources: list[Source]
    disclaimer: str
