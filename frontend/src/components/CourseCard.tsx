// 추천 코스 카드: 개략도 미리보기 + 경로 화면으로 이동.
import type { Course } from "../types";
import CourseMap from "./CourseMap";

function diffText(distance: number, target: number) {
  const d = Math.round((distance - target) * 100) / 100;
  if (Math.abs(d) < 0.05) return `목표 ${target}km와 거의 같은 거리입니다.`;
  return `목표 ${target}km보다 ${Math.abs(d).toFixed(2)}km ${d > 0 ? "깁니다" : "짧습니다"}.`;
}

interface Props {
  course: Course | null;
  target: number;
  onOpenRoute?: (course: Course, target: number) => void;
}

export default function CourseCard({ course, target, onOpenRoute }: Props) {
  return (
    <section aria-labelledby="course-title">
      <h2 id="course-title">추천 공식 코스</h2>
      {!course ? (
        <div className="card empty">추천할 코스 정보가 없습니다.</div>
      ) : (
        <article className="card course">
          <CourseMap course={course} labels={false} fit="contain" className="preview-map" />
          <div className="course-body">
            <header>
              <span className="course-name">{course.name}</span>
              <span className="distance">{course.distance_km.toFixed(2)}km</span>
            </header>
            <p className="muted small">공식 코스 중 목표 거리에 가장 가까운 코스입니다. {diffText(course.distance_km, target)}</p>
            {onOpenRoute && (
              <button type="button" className="link-btn" onClick={() => onOpenRoute(course, target)}>
                경로 보기
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
                  <path d="M9 6l6 6-6 6" />
                </svg>
              </button>
            )}
          </div>
        </article>
      )}
    </section>
  );
}
