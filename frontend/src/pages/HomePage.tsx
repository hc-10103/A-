import { useEffect, useRef, useState } from "react";
import { ApiError, getRecommendations } from "../api";
import CourseCard from "../components/CourseCard";
import EventList from "../components/EventList";
import HourlyChart from "../components/HourlyChart";
import RecommendationList from "../components/RecommendationList";
import SafetyNotice from "../components/SafetyNotice";
import SearchForm from "../components/SearchForm";
import SourceInfo from "../components/SourceInfo";
import StatusBanner from "../components/StatusBanner";
import type { RecommendationRequest, RecommendationResponse } from "../types";

function errorHint(e: unknown): string {
  if (e instanceof ApiError) {
    if (e.kind === "network") return "서버에 연결할 수 없습니다. 백엔드가 실행 중인지 확인하세요.";
    if (e.kind === "timeout") return "서버 응답이 너무 늦습니다. 잠시 후 다시 시도하세요.";
    if (e.kind === "invalid") return "서버 응답 형식이 올바르지 않습니다. API 계약과 맞는지 확인이 필요합니다.";
    if (e.status === 422) return "요청 값이 올바르지 않습니다. 선택 항목을 다시 확인하세요.";
    // 개발 서버 프록시는 백엔드가 꺼져 있어도 5xx를 돌려준다.
    if (e.status && e.status >= 500) return `서버 오류입니다 (${e.status}). 백엔드가 실행 중인지 확인하세요.`;
    return e.message;
  }
  return "알 수 없는 오류가 발생했습니다.";
}

const same = (a: RecommendationRequest, b: RecommendationRequest) => JSON.stringify(a) === JSON.stringify(b);

export default function HomePage() {
  const [form, setForm] = useState<RecommendationRequest>({
    activity: "run",
    target_distance_km: 3,
    time_preference: "evening",
    demo_mode: true,
  });
  const [data, setData] = useState<RecommendationResponse | null>(null);
  const [lastReq, setLastReq] = useState<RecommendationRequest | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const resultsRef = useRef<HTMLDivElement>(null);
  const [focusResults, setFocusResults] = useState(false);

  const submit = async () => {
    const req = form;
    setLoading(true);
    setError(null);
    try {
      setData(await getRecommendations(req));
      setLastReq(req);
      setFocusResults(true);
    } catch (e) {
      setData(null);
      setLastReq(null);
      setError(errorHint(e));
    } finally {
      setLoading(false);
    }
  };

  // 결과가 나오면 스크린리더·모바일 사용자를 결과 영역으로 옮긴다.
  useEffect(() => {
    if (focusResults && resultsRef.current) {
      resultsRef.current.focus({ preventScroll: true });
      resultsRef.current.scrollIntoView({ behavior: "smooth", block: "start" });
      setFocusResults(false);
    }
  }, [focusResults]);

  const stale = data && lastReq && !same(form, lastReq);
  const recs = data?.recommendations ?? [];

  return (
    <main className="container">
      <header className="hero">
        <h1>
          OLPARK RUN
          {form.demo_mode && <span className="badge hero-badge">DEMO</span>}
        </h1>
        <p>올림픽공원에서 오늘 언제, 어느 코스로 운동할지 골라 드립니다.</p>
      </header>

      <SearchForm value={form} onChange={setForm} onSubmit={submit} loading={loading} />

      {error && (
        <div className="banner warn" role="alert">
          <p>추천을 불러오지 못했습니다. {error}</p>
          <button type="button" className="secondary" onClick={submit} disabled={loading}>
            다시 시도
          </button>
        </div>
      )}

      {loading && !data && <ResultsSkeleton />}

      {data && (
        <div className="results" ref={resultsRef} tabIndex={-1} aria-busy={loading} aria-label="추천 결과">
          {stale && (
            <div className="banner notice" role="status">
              선택 조건이 바뀌었습니다. 아래 결과는 이전 조건 기준입니다.{" "}
              <button type="button" className="text-btn" onClick={submit} disabled={loading}>
                새 조건으로 다시 추천
              </button>
            </div>
          )}
          <StatusBanner data={data} />
          {data.data_status !== "unavailable" && (
            <>
              <SafetyNotice items={recs} />
              <RecommendationList items={recs} />
              <HourlyChart items={recs} bestIso={recs[0]?.time_iso} />
            </>
          )}
          <CourseCard course={data.course} target={lastReq?.target_distance_km ?? form.target_distance_km} />
          <EventList events={data.events} />
          <SourceInfo data={data} />
        </div>
      )}
    </main>
  );
}

function ResultsSkeleton() {
  return (
    <div className="results" aria-hidden>
      <div className="card skeleton" style={{ height: 180 }} />
      <div className="card skeleton" style={{ height: 110 }} />
      <div className="card skeleton" style={{ height: 80 }} />
    </div>
  );
}
