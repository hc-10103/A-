import { useState } from "react";
import { getRecommendations } from "../api";
import CourseCard from "../components/CourseCard";
import EventList from "../components/EventList";
import RecommendationList from "../components/RecommendationList";
import SearchForm from "../components/SearchForm";
import SourceInfo from "../components/SourceInfo";
import StatusBanner from "../components/StatusBanner";
import type { RecommendationRequest, RecommendationResponse } from "../types";

export default function HomePage() {
  const [form, setForm] = useState<RecommendationRequest>({
    activity: "run",
    target_distance_km: 3,
    time_preference: "evening",
    demo_mode: true,
  });
  const [data, setData] = useState<RecommendationResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setLoading(true);
    setError(null);
    try {
      setData(await getRecommendations(form));
    } catch (e) {
      setData(null);
      setError(e instanceof Error ? e.message : "알 수 없는 오류");
    } finally {
      setLoading(false);
    }
  };

  return (
    <main className="container">
      <header className="hero">
        <h1>OLPARK RUN</h1>
        <p>올림픽공원에서 오늘 언제, 어느 코스로 운동할지 골라 드립니다.</p>
      </header>

      <SearchForm value={form} onChange={setForm} onSubmit={submit} loading={loading} />

      {error && (
        <div className="banner warn" role="alert">
          추천을 불러오지 못했습니다: {error}. 백엔드가 실행 중인지 확인하세요.
        </div>
      )}

      {data && (
        <div className="results">
          <StatusBanner data={data} />
          {data.data_status !== "unavailable" && <RecommendationList items={data.recommendations} />}
          <CourseCard course={data.course} target={form.target_distance_km} />
          <EventList events={data.events} />
          <SourceInfo data={data} />
        </div>
      )}
    </main>
  );
}
