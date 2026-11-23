// 화면 전환: 추천(home) → 코스 경로(route) → 러닝(run).
// 추천 화면은 숨기기만 하고 유지해서, 돌아왔을 때 결과가 그대로 남는다.
import { useEffect, useState } from "react";
import HomePage from "./pages/HomePage";
import RoutePage from "./pages/RoutePage";
import RunPage from "./pages/RunPage";
import type { Course } from "./types";

type Screen = { name: "home" } | { name: "route"; course: Course; target: number } | { name: "run"; course: Course };

export default function App() {
  const [screen, setScreen] = useState<Screen>({ name: "home" });

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [screen.name]);

  return (
    <>
      <div hidden={screen.name !== "home"}>
        <HomePage
          onOpenRoute={(course, target) => setScreen({ name: "route", course, target })}
          onStartRun={(course) => setScreen({ name: "run", course })}
        />
      </div>
      {screen.name === "route" && (
        <RoutePage
          recommended={screen.course}
          target={screen.target}
          onBack={() => setScreen({ name: "home" })}
          onStart={(course) => setScreen({ name: "run", course })}
        />
      )}
      {screen.name === "run" && <RunPage course={screen.course} onExit={() => setScreen({ name: "home" })} />}
    </>
  );
}
