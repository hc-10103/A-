import type { TimeRecommendation } from "../types";
import { RATING_CLASS } from "./rating";

const show = (v: string | null) => v ?? "정보 없음";

export default function RecommendationList({ items }: { items: TimeRecommendation[] }) {
  if (items.length === 0) {
    return <div className="card empty">표시할 추천 시간대가 없습니다.</div>;
  }
  const [best, ...rest] = items;
  return (
    <section aria-labelledby="rec-title">
      <h2 id="rec-title">추천 시간</h2>
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
  const tone = RATING_CLASS[item.rating];
  const cautions = [...new Set(item.cautions)];
  return (
    <article className={`card rec ${tone} ${highlight ? "highlight" : ""}`}>
      <header>
        <span className="time">{item.time_label}</span>
        <span className={`rating ${tone}`}>{item.rating}</span>
      </header>
      <div className="score-row">
        <span className="score-label">참고 점수</span>
        <div
          className="meter"
          role="meter"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={item.score}
          aria-label="참고 점수"
        >
          <span className={`meter-fill ${tone}`} style={{ width: `${item.score}%` }} />
        </div>
        <span className="score">{item.score}점</span>
      </div>
      <dl className="conditions">
        <div><dt>날씨</dt><dd className={item.conditions.weather ? "" : "missing"}>{show(item.conditions.weather)}</dd></div>
        <div><dt>대기질</dt><dd className={item.conditions.air_quality ? "" : "missing"}>{show(item.conditions.air_quality)}</dd></div>
        <div>
          <dt>공원 전체 혼잡 <span className="scope">(공원 단위)</span></dt>
          <dd className={item.conditions.park_crowding ? "" : "missing"}>{show(item.conditions.park_crowding)}</dd>
        </div>
      </dl>
      {item.reasons.length > 0 && (
        <>
          <h3 className="sub">추천 이유</h3>
          <ul className="reasons">
            {item.reasons.map((r) => <li key={r}>{r}</li>)}
          </ul>
        </>
      )}
      {cautions.length > 0 && (
        <ul className="cautions" aria-label="주의">
          {cautions.map((c) => <li key={c}>{c}</li>)}
        </ul>
      )}
    </article>
  );
}
