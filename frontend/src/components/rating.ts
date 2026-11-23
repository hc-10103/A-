import type { Rating } from "../types";

export const RATING_CLASS: Record<Rating, string> = {
  좋음: "good",
  보통: "ok",
  주의: "caution",
  "야외운동 비권장": "danger",
};
