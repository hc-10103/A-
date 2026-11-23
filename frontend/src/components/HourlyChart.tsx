// 향후 시간대별 참고 점수를 시간 순서로 비교하는 막대 그래프. 색만으로 구분하지 않도록 비권장은 글자로도 표시한다.
import type { TimeRecommendation } from "../types";
import { RATING_CLASS } from "./rating";

const hourOf = (iso: string) => {
  const m = /T(\d{2}):/.exec(iso);
  return m ? `${Number(m[1])}시` : iso;
};

export default function HourlyChart({ items, bestIso }: { items: TimeRecommendation[]; bestIso?: string }) {
  if (items.length < 2) return null;
  const sorted = [...items].sort((a, b) => a.time_iso.localeCompare(b.time_iso));
  return (
    <section aria-labelledby="hourly-title">
      <h2 id="hourly-title">시간대별 비교</h2>
      <div className="card">
        <ol className="hourly">
          {sorted.map((r) => {
            const unsafe = r.rating === "야외운동 비권장";
            return (
              <li
                key={r.time_iso}
                className={r.time_iso === bestIso ? "best" : undefined}
                aria-label={`${r.time_label} ${r.score}점 ${r.rating}${r.time_iso === bestIso ? ", 추천" : ""}`}
              >
                <span className="hourly-score" aria-hidden>{unsafe ? "✕" : r.score}</span>
                <span className="hourly-track" aria-hidden>
                  <span className={`hourly-bar ${RATING_CLASS[r.rating]}`} style={{ height: `${Math.max(r.score, 4)}%` }} />
                </span>
                <span className="hourly-hour" aria-hidden>{hourOf(r.time_iso)}</span>
              </li>
            );
          })}
        </ol>
        <p className="legend small muted" aria-hidden>
          <span><i className="dot good" />좋음</span>
          <span><i className="dot ok" />보통</span>
          <span><i className="dot caution" />주의</span>
          <span><i className="dot danger" />✕ 비권장</span>
        </p>
      </div>
    </section>
  );
}
