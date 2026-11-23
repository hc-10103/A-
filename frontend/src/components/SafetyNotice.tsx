// 위험 조건(악천후·위험 대기질·극한 기온)일 때 점수보다 먼저 보여주는 안전 우선 안내.
import type { TimeRecommendation } from "../types";

const UNSAFE = "야외운동 비권장";

export default function SafetyNotice({ items }: { items: TimeRecommendation[] }) {
  if (items.length === 0) return null;
  const unsafe = items.filter((r) => r.rating === UNSAFE);
  const allUnsafe = unsafe.length === items.length;
  const topUnsafe = items[0].rating === UNSAFE;
  if (!allUnsafe && !topUnsafe) return null;

  return (
    <div className="safety" role="alert">
      <strong>안전 우선 안내</strong>
      <p>
        {allUnsafe
          ? "확인한 모든 시간대가 야외운동 비권장 조건입니다. 오늘은 실내 운동을 고려하세요."
          : "선택한 시간대는 야외운동 비권장 조건입니다. 아래 다른 시간대나 실내 운동을 고려하세요."}
      </p>
    </div>
  );
}
