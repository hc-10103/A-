// 모든 백엔드 호출은 이 파일에서만 한다.
import type { Course, ParkEvent, RecommendationRequest, RecommendationResponse } from "./types";

const BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, "") ?? "";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!res.ok) throw new Error(`요청 실패 (${res.status})`);
  return res.json() as Promise<T>;
}

export const getRecommendations = (body: RecommendationRequest) =>
  request<RecommendationResponse>("/api/recommendations", { method: "POST", body: JSON.stringify(body) });

export const getCourses = () => request<Course[]>("/api/courses");

export const getEvents = (date: string, demoMode: boolean) =>
  request<ParkEvent[]>(`/api/events?date=${encodeURIComponent(date)}&demo_mode=${demoMode}`);

export const getHealth = () => request<{ status: string }>("/api/health");
