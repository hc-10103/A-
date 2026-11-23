import type { Activity, RecommendationRequest, TimePreference } from "../types";

const ACTIVITIES: { value: Activity; label: string }[] = [
  { value: "run", label: "러닝" },
  { value: "walk", label: "산책" },
];
const DISTANCES = [2, 3, 5];
const TIMES: { value: TimePreference; label: string }[] = [
  { value: "morning", label: "아침" },
  { value: "afternoon", label: "오후" },
  { value: "evening", label: "저녁" },
  { value: "any", label: "상관없음" },
];

interface Props {
  value: RecommendationRequest;
  onChange: (next: RecommendationRequest) => void;
  onSubmit: () => void;
  loading: boolean;
}

function Chips<T extends string | number>(props: {
  name: string;
  options: { value: T; label: string }[];
  selected: T;
  onSelect: (v: T) => void;
}) {
  return (
    <fieldset className="chips">
      <legend>{props.name}</legend>
      {props.options.map((o) => (
        <button
          type="button"
          key={String(o.value)}
          className={o.value === props.selected ? "chip active" : "chip"}
          aria-pressed={o.value === props.selected}
          onClick={() => props.onSelect(o.value)}
        >
          {o.label}
        </button>
      ))}
    </fieldset>
  );
}

export default function SearchForm({ value, onChange, onSubmit, loading }: Props) {
  return (
    <form
      className="card form"
      onSubmit={(e) => {
        e.preventDefault();
        onSubmit();
      }}
    >
      <Chips name="운동 종류" options={ACTIVITIES} selected={value.activity} onSelect={(activity) => onChange({ ...value, activity })} />
      <Chips
        name="목표 거리"
        options={DISTANCES.map((d) => ({ value: d, label: `${d}km` }))}
        selected={value.target_distance_km}
        onSelect={(target_distance_km) => onChange({ ...value, target_distance_km })}
      />
      <Chips name="가능한 시간대" options={TIMES} selected={value.time_preference} onSelect={(time_preference) => onChange({ ...value, time_preference })} />
      <label className="toggle">
        <input type="checkbox" checked={value.demo_mode} onChange={(e) => onChange({ ...value, demo_mode: e.target.checked })} />
        시연 모드 (샘플 데이터 사용)
      </label>
      <button className="primary" type="submit" disabled={loading}>
        {loading ? "불러오는 중…" : "오늘 운동 추천 받기"}
      </button>
    </form>
  );
}
