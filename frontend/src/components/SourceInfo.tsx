import type { RecommendationResponse } from "../types";

// 이 시간보다 오래된 출처는 '갱신 지연'으로 표시한다.
// 백엔드 data_sources.STALE_AFTER(90분)와 같은 값으로 맞춘다 — 바꿀 때 둘 다 바꿀 것.
const STALE_MINUTES = 90;

const parse = (iso: string | null) => {
  if (!iso) return null;
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? null : d;
};

const fmt = (iso: string | null) => {
  if (!iso) return "갱신 시각 정보 없음";
  const d = parse(iso);
  return d ? d.toLocaleString("ko-KR", { dateStyle: "short", timeStyle: "short" }) : iso;
};

export default function SourceInfo({ data }: { data: RecommendationResponse }) {
  const ref = parse(data.generated_at) ?? new Date();
  return (
    <footer className="card sources" aria-labelledby="sources-title">
      <h2 id="sources-title">데이터 출처</h2>
      {data.sources.length === 0 ? (
        <p className="muted">사용 가능한 데이터 출처가 없습니다.</p>
      ) : (
        <ul>
          {data.sources.map((s) => {
            const updated = parse(s.updated_at);
            const ageMin = updated ? (ref.getTime() - updated.getTime()) / 60_000 : null;
            return (
              <li key={s.name}>
                {s.name} · {fmt(s.updated_at)}
                {ageMin !== null && ageMin > STALE_MINUTES && (
                  <span className="stale">
                    갱신 지연 ({ageMin >= 120 ? `${Math.floor(ageMin / 60)}시간` : `${Math.floor(ageMin)}분`} 전)
                  </span>
                )}
              </li>
            );
          })}
        </ul>
      )}
      <p className="muted small">추천 생성: {fmt(data.generated_at || null)}</p>
      {data.disclaimer && <p className="muted small">{data.disclaimer}</p>}
    </footer>
  );
}
