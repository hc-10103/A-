"""한국체육산업개발 '올림픽공원 2025 차량입출차, 공연, 날씨정보 등 연계 데이터'(문화데이터광장 API_CPM_009)로
요일·시간대별 공연 패턴을 집계해 shared/kspo_concert_pattern_2025.json 을 만든다.

- 원본: 시간대별 1행, TITLE = "공연명:<이름>,공연관람객수:<명>" (공연이 없으면 이름이 비어 있음)
  ※ 데이터셋 이름과 달리 차량 대수·날씨 값은 응답에 없다 (2026-11-23 확인).
- 원본은 backend/data_raw/kspo_linked/linked_all.json 에 캐시한다 (git 제외). 없으면 API 로 받는다.
  호출 한도 5초에 1회 → 6초 간격, 1,000건씩 8회.

실행 (backend 폴더에서):
    .venv/bin/python scripts/build_kspo_concert_pattern.py
환경변수: CULTURE_API_KEY (루트 .env, 원본 캐시가 없을 때만 필요)
"""
from __future__ import annotations

import json
import math
import os
import re
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "backend" / "data_raw" / "kspo_linked" / "linked_all.json"
OUT = ROOT / "shared" / "kspo_concert_pattern_2025.json"
URL = "https://api.kcisa.kr/openapi/API_CPM_009/request"
TITLE_RE = re.compile(r"^공연명:(.*),공연관람객수:\s*(\d+)\s*$", re.S)


def download() -> list[dict]:
    import httpx
    from dotenv import load_dotenv

    load_dotenv(ROOT / ".env")
    key = os.getenv("CULTURE_API_KEY", "").strip()
    if not key:
        sys.exit("원본 캐시가 없고 CULTURE_API_KEY 도 없습니다.")
    items: list[dict] = []
    page, pages = 1, 1
    with httpx.Client(timeout=90, headers={"Accept": "application/json"}) as client:
        while page <= pages:
            r = client.get(URL, params={"serviceKey": key, "numOfRows": 1000, "pageNo": page})
            if r.status_code == 429:
                time.sleep(6)
                continue
            body = r.json()["response"]["body"]
            pages = math.ceil(int(body["totalCount"]) / 1000)
            got = body["items"]["item"]
            items += got if isinstance(got, list) else [got]
            print(f"page {page}/{pages}", flush=True)
            page += 1
            time.sleep(6)
    RAW.parent.mkdir(parents=True, exist_ok=True)
    RAW.write_text(json.dumps(items, ensure_ascii=False))
    return items


def build(items: list[dict]) -> dict:
    by_hour: dict[datetime, tuple[str, int]] = {}
    collected = []
    for it in items:
        m = TITLE_RE.match((it.get("TITLE") or "").strip())
        if not m:
            continue
        t = datetime.strptime(it["ISSUED_DATE"][:13], "%Y-%m-%d %H")
        name = m.group(1).strip().strip(",").strip()
        by_hour[t] = (name, int(m.group(2)))
        if it.get("COLLECTED_DATE"):
            collected.append(it["COLLECTED_DATE"])

    acc: dict[int, dict[int, dict]] = defaultdict(lambda: defaultdict(lambda: {"days": 0, "concert_days": 0, "aud": []}))
    for t, (name, aud) in by_hour.items():
        cell = acc[t.weekday()][t.hour]
        cell["days"] += 1
        if name:
            cell["concert_days"] += 1
            cell["aud"].append(aud)

    slots = {}
    for wd in range(7):
        slots[str(wd)] = {}
        for h in range(24):
            c = acc[wd][h]
            slots[str(wd)][str(h)] = {
                "days": c["days"],
                "concert_days": c["concert_days"],
                "avg_audience": round(sum(c["aud"]) / len(c["aud"])) if c["aud"] else None,
            }

    times = sorted(by_hour)
    shows = {n for n, _ in by_hour.values() if n}
    return {
        "_meta": {
            "source": "한국체육산업개발(주) 올림픽공원 2025 차량입출차, 공연, 날씨정보 등 연계 데이터",
            "provider_api": "문화공공데이터광장 API_CPM_009 (culture.go.kr id=675)",
            "period": f"{times[0]:%Y-%m-%d} ~ {times[-1]:%Y-%m-%d}",
            "hours": len(by_hour),
            "days": len({t.date() for t in times}),
            "concert_hours": sum(1 for n, _ in by_hour.values() if n),
            "distinct_shows": len(shows),
            "collected_at": max(collected) if collected else None,
            "weekday": "0=월 … 6=일",
            "note": "2025년 기록 기반 참고 정보이며 올해 공연 일정이 아니다. 관람객 수는 원본 값 그대로.",
            "generated_by": "backend/scripts/build_kspo_concert_pattern.py",
        },
        "slots": slots,
    }


def main() -> None:
    items = json.loads(RAW.read_text(encoding="utf-8")) if RAW.exists() else download()
    result = build(items)
    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    m = result["_meta"]
    print(f"saved {OUT.relative_to(ROOT)}: {m['period']}, {m['hours']} hours, {m['concert_hours']} concert hours, {m['distinct_shows']} shows")


if __name__ == "__main__":
    main()
