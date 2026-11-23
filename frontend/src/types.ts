// OLPARK_RUN_VIBE_CODING.md 3절 API 계약과 1:1로 맞춘다. (백엔드: backend/app/schemas.py)
export type Activity = "run" | "walk";
export type TimePreference = "morning" | "afternoon" | "evening" | "any";
export type Rating = "좋음" | "보통" | "주의" | "야외운동 비권장";
export type DataStatus = "sample" | "live" | "partial" | "unavailable";

export interface RecommendationRequest {
  activity: Activity;
  target_distance_km: number;
  time_preference: TimePreference;
  demo_mode: boolean;
}

export interface Conditions {
  weather: string | null;
  air_quality: string | null;
  park_crowding: string | null;
}

export interface TimeRecommendation {
  time_label: string;
  time_iso: string;
  score: number;
  rating: Rating;
  reasons: string[];
  conditions: Conditions;
  cautions: string[];
}

export interface Course {
  id: string;
  name: string;
  distance_km: number;
  description: string;
  map_url: string | null;
}

export interface ParkEvent {
  id: string;
  type: "event" | "notice";
  title: string;
  date: string;
  start_time: string | null;
  end_time: string | null;
  location: string | null;
  note: string | null;
  is_sample: boolean;
}

export interface Source {
  name: string;
  updated_at: string | null;
}

export interface RecommendationResponse {
  generated_at: string;
  mode: "demo" | "live";
  data_status: DataStatus;
  recommendations: TimeRecommendation[];
  course: Course | null;
  events: ParkEvent[];
  sources: Source[];
  disclaimer: string;
}
