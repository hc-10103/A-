// 코스 '개략도'를 그리기 위한 화면 배치 정보.
//
// ⚠ 실제 좌표가 아니다. 공식 좌표가 확보되기 전까지(담당 C) 경유지 '순서'만 공식 안내를 따르고,
//   위치·축척은 화면에 보기 좋게 배치한 값이다. 화면에서는 항상 '개략도'로 표시한다.
//   좌표가 생기면 이 파일 대신 실제 지도 타일 + 좌표 경로로 바꾼다.
import type { Course } from "./types";

export interface Point {
  x: number;
  y: number;
}

/** SVG 좌표계(0 0 390 480) 안의 개략 위치 */
const PLACES: Record<string, Point> = {
  곰말다리: { x: 130, y: 120 },
  "몽촌토성 중심": { x: 195, y: 250 },
  서울역사편찬원: { x: 280, y: 335 },
  "88마당": { x: 330, y: 235 },
  삼거리매점: { x: 305, y: 150 },
  피크닉장: { x: 115, y: 310 },
  소마미술관: { x: 70, y: 210 },
  평화의광장: { x: 65, y: 120 },
  움집터전시관: { x: 240, y: 290 },
  야생화학습장: { x: 165, y: 190 },
  "몽촌토성 순환": { x: 285, y: 215 },
};

/** 경유지가 따로 없는 순환 코스: 경계선을 따라 도는 모양으로만 그린다 */
const RINGS: Record<string, "fortress" | "outer"> = {
  "earthen-wall-road": "fortress",
  "youth-road": "outer",
};

export interface CourseRoute {
  /** 공식 안내 순서의 경유지 이름 (없으면 빈 배열) */
  waypoints: string[];
  /** 그릴 수 있는 경유지 위치 (이름을 모르는 경유지는 빠짐) */
  points: (Point & { name: string; order: number })[];
  ring: "fortress" | "outer" | null;
}

/**
 * course.description 의 첫 문장 "A → B → C." 에서 경유지 순서를 읽는다.
 * TODO(C): API에 waypoints 필드가 생기면 그것을 우선 사용한다.
 */
export function parseWaypoints(description: string): string[] {
  const first = description.split(/\.\s/)[0]?.replace(/\.$/, "") ?? "";
  if (!first.includes("→")) return [];
  return first
    .split("→")
    .map((s) => s.trim())
    .filter(Boolean);
}

export function routeOf(course: Course): CourseRoute {
  const waypoints = parseWaypoints(course.description);
  const points = waypoints
    .map((name, i) => (PLACES[name] ? { ...PLACES[name], name, order: i + 1 } : null))
    .filter((p): p is Point & { name: string; order: number } => p !== null);
  return { waypoints, points, ring: RINGS[course.id] ?? null };
}

export const MAP_VIEWBOX = { w: 390, h: 480 };
