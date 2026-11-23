// 코스 개략도. 실제 지도·좌표가 아니므로 항상 '개략도' 배지를 함께 보여준다.
import { routeOf } from "../courseRoute";
import type { Course } from "../types";

interface Props {
  course: Course;
  theme?: "light" | "dark";
  labels?: boolean;
  className?: string;
  /** cover: 영역을 채우며 잘라냄 / contain: 공원 전체가 보이게 */
  fit?: "cover" | "contain";
}

export default function CourseMap({ course, theme = "light", labels = true, className = "", fit = "cover" }: Props) {
  const { waypoints, points, ring } = routeOf(course);
  const drawable = points.length >= 2 || ring !== null;

  // 같은 장소를 두 번 지나면 번호를 합쳐 한 표시로 (예: "2·6"). 출발지로 돌아오는 마지막 지점은 출발 표시와 합친다.
  const markers = new Map<string, { x: number; y: number; orders: number[] }>();
  points.forEach((p, i) => {
    const isReturn = i === points.length - 1 && p.name === points[0]?.name && points.length > 1;
    if (isReturn) return;
    const m = markers.get(p.name) ?? { x: p.x, y: p.y, orders: [] };
    m.orders.push(p.order);
    markers.set(p.name, m);
  });
  const startName = points[0]?.name;
  const line = points.map((p) => `${p.x},${p.y}`).join(" ");
  const summary = waypoints.length
    ? `${course.name} 개략도: ${waypoints.join(", ")} 순서로 도는 경로`
    : `${course.name} 개략도: ${ring === "outer" ? "공원 외곽 순환" : ring === "fortress" ? "몽촌토성 순환" : "경로 정보 없음"}`;

  return (
    <div className={`course-map ${theme} ${className}`}>
      <svg viewBox="0 0 390 480" role="img" aria-label={summary} preserveAspectRatio={fit === "cover" ? "xMidYMid slice" : "xMidYMid meet"}>
        <rect className="m-park" x="18" y="72" width="354" height="392" rx="72" />
        <ellipse className="m-fort" cx="195" cy="255" rx="102" ry="80" transform="rotate(-14 195 255)" />
        <ellipse className="m-water" cx="342" cy="300" rx="24" ry="34" />
        <path className="m-water-line" d="M30 102 Q100 84 176 108" />
        {labels && (
          <text className="m-area" x="195" y="232" textAnchor="middle">
            몽촌토성
          </text>
        )}

        {ring === "outer" && <rect className="m-route-ring" x="34" y="88" width="322" height="360" rx="62" />}
        {ring === "fortress" && (
          <ellipse className="m-route-ring" cx="195" cy="255" rx="102" ry="80" transform="rotate(-14 195 255)" />
        )}

        {points.length >= 2 && (
          <>
            <polyline className="m-casing" points={line} />
            <polyline className="m-route" points={line} />
          </>
        )}

        {[...markers.entries()].map(([name, m]) => {
          const isStart = name === startName;
          return (
            <g key={name} className={isStart ? "m-node start" : "m-node"}>
              <circle cx={m.x} cy={m.y} r={isStart ? 14 : m.orders.length > 1 ? 13 : 11} />
              <text x={m.x} y={m.y + 4} textAnchor="middle">
                {isStart ? "S" : m.orders.join("·")}
              </text>
              {labels && (
                <text className="m-label" x={m.x} y={m.y + (m.y > 300 ? 28 : -20)} textAnchor="middle">
                  {name}
                </text>
              )}
            </g>
          );
        })}

        {!drawable && (
          <text className="m-empty" x="195" y="260" textAnchor="middle">
            이 코스는 개략 경로 정보가 없어요
          </text>
        )}
      </svg>
      <span className="map-badge">개략도 · 위치·축척은 실제와 달라요</span>
    </div>
  );
}
