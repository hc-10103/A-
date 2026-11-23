// 지도 영역은 담당 C. 좌표가 확보되기 전까지는 플레이스홀더 / 공식 안내 링크로 처리한다.
import type { Course } from "../types";

function diffText(distance: number, target: number) {
  const d = Math.round((distance - target) * 100) / 100;
  if (Math.abs(d) < 0.05) return `목표 ${target}km와 거의 같은 거리입니다.`;
  return `목표 ${target}km보다 ${Math.abs(d).toFixed(2)}km ${d > 0 ? "깁니다" : "짧습니다"}.`;
}

export default function CourseCard({ course, target }: { course: Course | null; target: number }) {
  return (
    <section aria-labelledby="course-title">
      <h2 id="course-title">추천 공식 코스</h2>
      {!course ? (
        <div className="card empty">추천할 코스 정보가 없습니다.</div>
      ) : (
        <article className="card course">
          <header>
            <span className="course-name">{course.name}</span>
            <span className="distance">{course.distance_km.toFixed(2)}km</span>
          </header>
          {course.description && <p>{course.description}</p>}
          <p className="muted small">공식 코스 중 목표 거리에 가장 가까운 코스입니다. {diffText(course.distance_km, target)}</p>
          {course.map_url ? (
            <a className="link-btn" href={course.map_url} target="_blank" rel="noreferrer">
              공식 코스 안내 보기 ↗
            </a>
          ) : (
            <div className="map-placeholder">지도 준비 중 — 코스 위치는 올림픽공원 공식 안내를 확인하세요.</div>
          )}
        </article>
      )}
    </section>
  );
}
