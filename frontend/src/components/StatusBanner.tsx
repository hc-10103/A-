import type { RecommendationResponse } from "../types";

const STATUS_TEXT: Record<RecommendationResponse["data_status"], string> = {
  sample: "데모 모드 — 화면의 날씨·대기질·혼잡도는 샘플 값이며 실제 관측값이 아닙니다.",
  live: "실시간 공공데이터 기준입니다.",
  partial: "일부 데이터만 받아왔습니다. '정보 없음' 항목은 판단에서 신뢰도가 낮습니다.",
  unavailable: "실시간 데이터를 가져오지 못했습니다. 추천을 만들 수 없습니다.",
};

export default function StatusBanner({ data }: { data: RecommendationResponse }) {
  const tone = data.data_status === "live" ? "info" : data.data_status === "sample" ? "demo" : "warn";
  return (
    <div className={`banner ${tone}`} role="status">
      {data.mode === "demo" && <strong className="badge">DEMO</strong>}
      {STATUS_TEXT[data.data_status]}
    </div>
  );
}
