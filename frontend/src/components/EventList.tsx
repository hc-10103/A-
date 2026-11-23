import type { ParkEvent } from "../types";

// 시간이 있는 항목을 시작 시각 순으로, 시간 없는 공지는 맨 앞에 둔다.
const byTime = (a: ParkEvent, b: ParkEvent) => (a.start_time ?? "").localeCompare(b.start_time ?? "");

export default function EventList({ events }: { events: ParkEvent[] }) {
  const sorted = [...events].sort(byTime);
  return (
    <section aria-labelledby="events-title">
      <h2 id="events-title">행사·이용 주의 정보</h2>
      {events.length === 0 ? (
        <div className="card empty">오늘 등록된 행사·공지가 없습니다.</div>
      ) : (
        sorted.map((e) => (
          <article key={e.id} className="card event">
            <header>
              <span className={`tag tag-${e.type}`}>{e.type === "event" ? "행사" : "공지"}</span>
              <strong>{e.title}</strong>
              {e.is_sample && <span className="badge">샘플</span>}
            </header>
            {(e.start_time || e.location) && (
              <p className="muted">
                {e.start_time && `${e.start_time}${e.end_time ? `~${e.end_time}` : ""}`} {e.location ?? ""}
              </p>
            )}
            {e.note && <p>{e.note}</p>}
          </article>
        ))
      )}
      <p className="muted small">행사 정보는 참고용이며, 코스가 실제로 혼잡해진다는 뜻은 아닙니다.</p>
    </section>
  );
}
