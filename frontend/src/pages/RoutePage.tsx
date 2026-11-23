import { useEffect, useState } from "react";
import { getCourses } from "../api";
import CourseMap from "../components/CourseMap";
import { parseWaypoints } from "../courseRoute";
import type { Course } from "../types";

interface Props {
  recommended: Course;
  target: number;
  onBack: () => void;
  onStart: (course: Course) => void;
}

function diffText(distance: number, target: number) {
  const d = Math.round((distance - target) * 100) / 100;
  if (Math.abs(d) < 0.05) return `목표 ${target}km와 거의 같은 거리`;
  return `목표 ${target}km보다 ${Math.abs(d).toFixed(2)}km ${d > 0 ? "긴" : "짧은"} 코스`;
}

export default function RoutePage({ recommended, target, onBack, onStart }: Props) {
  const [courses, setCourses] = useState<Course[]>([recommended]);
  const [selectedId, setSelectedId] = useState(recommended.id);

  useEffect(() => {
    let alive = true;
    getCourses()
      .then((list) => {
        if (alive && Array.isArray(list) && list.length > 0) setCourses(list);
      })
      .catch(() => {
        /* 목록을 못 받아도 추천 코스 하나로 계속 보여준다 */
      });
    return () => {
      alive = false;
    };
  }, []);

  // 추천 코스를 맨 앞에
  const ordered = [recommended, ...courses.filter((c) => c.id !== recommended.id)];
  const course = ordered.find((c) => c.id === selectedId) ?? recommended;
  const waypoints = parseWaypoints(course.description);
  const summary = waypoints.length ? course.description.split(/\.\s/).slice(1).join(". ") : course.description;

  return (
    <div className="screen route-screen">
      <CourseMap course={course} className="route-map" />
      <button type="button" className="icon-btn floating back" aria-label="추천 화면으로 돌아가기" onClick={onBack}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M15 6l-6 6 6 6" />
        </svg>
      </button>

      <section className="sheet" aria-labelledby="route-title">
        <div className="sheet-handle" aria-hidden />
        <div className="course-chips" role="radiogroup" aria-label="코스 선택">
          {ordered.map((c) => (
            <button
              key={c.id}
              type="button"
              role="radio"
              aria-checked={c.id === course.id}
              className={c.id === course.id ? "chip active" : "chip"}
              onClick={() => setSelectedId(c.id)}
            >
              {c.name}
              {c.id === recommended.id && <span className="chip-tag">추천</span>}
            </button>
          ))}
        </div>

        <div className="route-head">
          <div>
            <h1 id="route-title">{course.name}</h1>
            <p className="muted small">{diffText(course.distance_km, target)}</p>
          </div>
          <span className="big-num">
            {course.distance_km.toFixed(2)}
            <small>km</small>
          </span>
        </div>

        {waypoints.length > 0 ? (
          <ol className="waypoints" aria-label="경유지 순서">
            {waypoints.map((w, i) => (
              <li key={`${w}-${i}`} className={i === 0 ? "start" : undefined}>
                {i === 0 ? "S" : i === waypoints.length - 1 && w === waypoints[0] ? "도착" : i + 1} {w}
              </li>
            ))}
          </ol>
        ) : null}
        {summary && <p className="small">{summary}</p>}

        <p className="muted small">
          경유지 순서: KSPO 공식 산책·조깅 코스 안내
          {course.map_url && (
            <>
              {" · "}
              <a href={course.map_url} target="_blank" rel="noreferrer">
                공식 지도 보기 ↗
              </a>
            </>
          )}
        </p>

        <button type="button" className="cta" onClick={() => onStart(course)}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
            <path d="M7 4l13 8-13 8z" />
          </svg>
          이 코스로 달리기
        </button>
      </section>
    </div>
  );
}
