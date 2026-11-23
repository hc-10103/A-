// 러닝 중 화면. 위치 추적(GPS)은 아직 지원하지 않으므로 거리·페이스는 지어내지 않고 '미지원'으로 보여준다.
// 시간은 실제로 흐르는 스톱워치다.
import { useEffect, useRef, useState } from "react";
import CourseMap from "../components/CourseMap";
import type { Course } from "../types";

const pad = (n: number) => String(n).padStart(2, "0");
const fmt = (ms: number) => {
  const s = Math.floor(ms / 1000);
  return `${pad(Math.floor(s / 3600))}:${pad(Math.floor((s % 3600) / 60))}:${pad(s % 60)}`;
};

export default function RunPage({ course, onExit }: { course: Course; onExit: () => void }) {
  const [paused, setPaused] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const startedAt = useRef(Date.now());
  const banked = useRef(0); // 일시정지 전까지 쌓인 시간

  useEffect(() => {
    if (paused) return;
    startedAt.current = Date.now();
    const id = setInterval(() => setElapsed(banked.current + Date.now() - startedAt.current), 500);
    return () => {
      clearInterval(id);
      banked.current += Date.now() - startedAt.current;
      setElapsed(banked.current);
    };
  }, [paused]);

  return (
    <div className="screen run-screen">
      <CourseMap course={course} theme="dark" labels={false} className="run-map" />

      <div className="run-top">
        <span className="run-title">{course.name} · 러닝 중</span>
      </div>

      <section className="run-panel" aria-label="러닝 기록">
        <div className="run-row">
          <div>
            <span className="run-label" aria-live="polite">
              {paused ? "일시정지됨" : "달린 시간"}
            </span>
            <span className={`run-time ${paused ? "paused" : ""}`} role="timer">
              {fmt(elapsed)}
            </span>
          </div>
          <button
            type="button"
            className="run-toggle"
            aria-label={paused ? "다시 시작" : "일시정지"}
            onClick={() => setPaused((p) => !p)}
          >
            {paused ? (
              <svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <path d="M7 4l13 8-13 8z" />
              </svg>
            ) : (
              <svg width="26" height="26" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
                <rect x="6" y="4" width="4" height="16" rx="1" />
                <rect x="14" y="4" width="4" height="16" rx="1" />
              </svg>
            )}
          </button>
        </div>

        <div className="run-stats">
          <div>
            <span className="run-stat">{course.distance_km.toFixed(2)}</span>
            <span className="run-label">코스 km</span>
          </div>
          <div>
            <span className="run-stat muted-stat">—</span>
            <span className="run-label">달린 거리</span>
          </div>
          <div>
            <span className="run-stat muted-stat">—</span>
            <span className="run-label">페이스</span>
          </div>
        </div>
        <p className="run-note">위치 추적은 아직 지원하지 않아 거리·페이스는 표시하지 않아요.</p>

        {paused && (
          <div className="run-actions">
            <button type="button" className="ghost-btn" onClick={onExit}>
              러닝 종료
            </button>
            <button type="button" className="light-btn" onClick={() => setPaused(false)}>
              이어 달리기
            </button>
          </div>
        )}
      </section>
    </div>
  );
}
