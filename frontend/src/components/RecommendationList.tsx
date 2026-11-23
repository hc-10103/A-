import type { Rating, TimeRecommendation } from "../types";

const RATING_CLASS: Record<Rating, string> = {
  좋음: "good",
  보통: "ok",
  주의: "caution",
  "야외운동 비권장": "danger",
};

const show = (v: string | null) => v ?? "정보 없음";

export default function RecommendationList({ items }: { items: TimeRecommendation[] }) {
  if (items.length === 0) {
    return <div className="card empty">표시할 추천 시간대가 없습니다.</div>;
  }
  const [best, ...rest] = items;
  return (
    <section>
      <h2>추천 시간</h2>
      <RecCard item={best} highlight />
      {rest.length > 0 && (
        <details className="more">
          <summary>다른 시간대 {rest.length}개 보기</summary>
          {rest.map((r) => (
            <RecCard key={r.time_iso} item={r} />
          ))}
        </details>
      )}
    </section>
  );
}

function RecCard({ item, highlight = false }: { item: TimeRecommendation; highlight?: boolean }) {
  return (
    <article className={`card rec ${highlight ? "highlight" : ""}`}>
      <header>
        <span className="time">{item.time_label}</span>
        <span className={`rating ${RATING_CLASS[item.rating]}`}>{item.rating}</span>
        <span className="score" title="초기 설계값 기반 참고 점수">{item.score}점</span>
      </header>
      <dl className="conditions">
        <div><dt>날씨</dt><dd>{show(item.conditions.weather)}</dd></div>
        <div><dt>대기질</dt><dd>{show(item.conditions.air_quality)}</dd></div>
        <div><dt>공원 전체 혼잡</dt><dd>{show(item.conditions.park_crowding)}</dd></div>
      </dl>
      <ul className="reasons">
        {item.reasons.map((r) => <li key={r}>{r}</li>)}
      </ul>
      {item.cautions.length > 0 && (
        <ul className="cautions">
          {item.cautions.map((c) => <li key={c}>{c}</li>)}
        </ul>
      )}
    </article>
  );
}
