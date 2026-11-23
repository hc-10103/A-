// 모든 백엔드 호출은 이 파일에서만 한다.
import type { Course, ParkEvent, RecommendationRequest, RecommendationResponse } from "./types";

const BASE = (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/$/, "") ?? "";
const TIMEOUT_MS = 10_000;

export type ApiErrorKind = "network" | "timeout" | "http" | "invalid";

/** 화면에서 원인별로 안내 문구를 다르게 보여주기 위한 오류 타입 */
export class ApiError extends Error {
  constructor(
    public kind: ApiErrorKind,
    message: string,
    public status?: number,
  ) {
    super(message);
    this.name = "ApiError";
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  let res: Response;
  try {
    res = await fetch(`${BASE}${path}`, {
      headers: { "Content-Type": "application/json" },
      ...init,
      signal: controller.signal,
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === "AbortError") {
      throw new ApiError("timeout", "서버 응답이 너무 늦습니다");
    }
    throw new ApiError("network", "서버에 연결할 수 없습니다");
  } finally {
    clearTimeout(timer);
  }
  if (!res.ok) throw new ApiError("http", `서버가 요청을 처리하지 못했습니다 (${res.status})`, res.status);
  try {
    return (await res.json()) as T;
  } catch {
    throw new ApiError("invalid", "서버 응답 형식이 올바르지 않습니다");
  }
}

const arr = <T>(v: unknown): T[] => (Array.isArray(v) ? (v as T[]) : []);

/**
 * 계약에서 필드가 빠지거나 형식이 어긋나도 화면이 깨지지 않도록 기본값만 채운다.
 * 값을 지어내지 않는다: 누락된 배열은 빈 배열, 누락된 상태는 "unavailable"로 본다.
 */
function normalize(raw: unknown): RecommendationResponse {
  if (!raw || typeof raw !== "object") throw new ApiError("invalid", "서버 응답 형식이 올바르지 않습니다");
  const r = raw as Partial<RecommendationResponse>;
  return {
    generated_at: r.generated_at ?? "",
    mode: r.mode === "live" ? "live" : "demo",
    data_status: r.data_status ?? "unavailable",
    recommendations: arr<RecommendationResponse["recommendations"][number]>(r.recommendations).map((x) => ({
      ...x,
      reasons: arr<string>(x.reasons),
      cautions: arr<string>(x.cautions),
      conditions: {
        weather: x.conditions?.weather ?? null,
        air_quality: x.conditions?.air_quality ?? null,
        park_crowding: x.conditions?.park_crowding ?? null,
      },
    })),
    course: r.course ?? null,
    events: arr(r.events),
    sources: arr(r.sources),
    disclaimer: r.disclaimer ?? "",
  };
}

export const getRecommendations = async (body: RecommendationRequest) =>
  normalize(await request<unknown>("/api/recommendations", { method: "POST", body: JSON.stringify(body) }));

export const getCourses = () => request<Course[]>("/api/courses");

export const getEvents = (date: string, demoMode: boolean) =>
  request<ParkEvent[]>(`/api/events?date=${encodeURIComponent(date)}&demo_mode=${demoMode}`);

export const getHealth = () => request<{ status: string }>("/api/health");
