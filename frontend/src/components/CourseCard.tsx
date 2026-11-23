// 지도 영역은 담당 C. 좌표가 확보되기 전까지는 플레이스홀더 / 공식 안내 링크로 처리한다.
import type { Course } from "../types";

export default function CourseCard({ course, target }: { course: Course | null; target: number }) {
  if (!course) return <div className="card empty">추천할 코스 정보가 없습니다.</div>;
  return (
    <section>
      <h2>추천 공식 코스</h2>
      <article className="card course">
        <header>
          <span className="course-name">{course.name}</span>
          <span className="distance">{course.distance_km.toFixed(2)}km</span>
        </header>
        <p>{course.description}</p>
        <p className="muted">목표 {target}km에 가장 가까운 공식 코스입니다.</p>
        {course.map_url ? (
          <a href={course.map_url} target="_blank" rel="noreferrer">공식 코스 안내 보기</a>
        ) : (
          <div className="map-placeholder">지도 준비 중 — 코스 위치는 올림픽공원 공식 안내를 확인하세요.</div>
        )}
      </article>
    </section>
  );
}
