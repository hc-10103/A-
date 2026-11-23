import type { RecommendationResponse } from "../types";

const fmt = (iso: string | null) => {
  if (!iso) return "갱신 시각 정보 없음";
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString("ko-KR", { dateStyle: "short", timeStyle: "short" });
};

export default function SourceInfo({ data }: { data: RecommendationResponse }) {
  return (
    <footer className="card sources">
      <h2>데이터 출처</h2>
      {data.sources.length === 0 ? (
        <p className="muted">사용 가능한 데이터 출처가 없습니다.</p>
      ) : (
        <ul>
          {data.sources.map((s) => (
            <li key={s.name}>
              {s.name} · {fmt(s.updated_at)}
            </li>
          ))}
        </ul>
      )}
      <p className="muted small">추천 생성: {fmt(data.generated_at)}</p>
      <p className="muted small">{data.disclaimer}</p>
    </footer>
  );
}
