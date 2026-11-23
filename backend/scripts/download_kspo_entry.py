"""한국체육산업개발 '올림픽공원 2025 입출차정보'(문화데이터광장 API_CPM_008) 전체 다운로드.

- 호출 한도: 5초에 1회 → 요청 사이 5.5초 대기, 429 응답이면 더 기다렸다 재시도
- 이어받기: 받은 페이지는 data_raw/kspo_entry/pages/NNNNN.csv.gz 로 저장하고 다시 실행하면 건너뛴다
- 원본(약 241만 건)은 저장소에 올리지 않는다 (backend/data_raw/ 는 git 제외). 집계 결과만 shared/ 에 올린다.

표본 추출: 한 페이지(1,000건)에 약 두 달치 날짜가 고르게 섞여 있어, N페이지마다 1페이지씩 받으면
연중 고른 표본이 된다. --every 10 이면 1, 11, 21, ... 페이지(약 10%, 약 22분).
분석은 manifest.json 의 sampled_pages 만 써야 한다 (중간에 더 받은 페이지가 섞이면 특정 기간이 과대표집됨).

실행 (backend 폴더에서):
    .venv/bin/python -u scripts/download_kspo_entry.py --every 10   # 10% 표본
    .venv/bin/python -u scripts/download_kspo_entry.py              # 전체 (약 3.7시간)
환경변수: CULTURE_ENTRY_API_KEY (루트 .env)
"""
from __future__ import annotations

import argparse
import csv
import gzip
import io
import json
import math
import os
import re
import sys
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "backend" / "data_raw" / "kspo_entry" / "pages"
URL = "https://api.kcisa.kr/openapi/API_CPM_008/request"
ROWS = 1000
GAP_SEC = 5.5
FIELDS = ["local_id", "in_gate", "in_time", "out_gate", "out_time", "issued_date"]
DESC_RE = re.compile(r"입구:(?P<in_gate>[^,]*),\s*입차시간:(?P<in_time>[^,]*),\s*출구:(?P<out_gate>[^,]*),\s*출차시간:(?P<out_time>.*)")


def fetch(client: httpx.Client, key: str, page: int) -> dict:
    wait = 10.0
    for attempt in range(12):
        try:
            r = client.get(URL, params={"serviceKey": key, "numOfRows": ROWS, "pageNo": page})
        except httpx.HTTPError as exc:
            print(f"  page {page}: network error {exc!r}, retry in {wait:.0f}s", flush=True)
            time.sleep(wait)
            wait = min(wait * 2, 300)
            continue
        if r.status_code == 429:
            time.sleep(wait)
            continue
        if r.status_code == 401:
            sys.exit("401 Unauthorized — CULTURE_ENTRY_API_KEY 를 확인하세요.")
        try:
            body = r.json()["response"]
        except Exception:  # noqa: BLE001
            print(f"  page {page}: unexpected response (http {r.status_code}), retry in {wait:.0f}s", flush=True)
            time.sleep(wait)
            wait = min(wait * 2, 300)
            continue
        code = (body.get("header") or {}).get("resultCode")
        if code not in ("0000", "00", None):
            print(f"  page {page}: resultCode {code}, retry in {wait:.0f}s", flush=True)
            time.sleep(wait)
            wait = min(wait * 2, 300)
            continue
        return body["body"]
    raise RuntimeError(f"page {page}: gave up after retries")


def to_rows(items) -> list[dict]:
    if isinstance(items, dict):
        items = [items]
    rows = []
    for it in items or []:
        m = DESC_RE.match((it.get("DESCRIPTION") or "").strip())
        row = {"local_id": it.get("LOCAL_ID"), "issued_date": it.get("ISSUED_DATE")}
        row.update({k: (m.group(k).strip() if m else "") for k in ("in_gate", "in_time", "out_gate", "out_time")})
        rows.append(row)
    return rows


def save(page: int, rows: list[dict]) -> None:
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=FIELDS)
    w.writeheader()
    w.writerows(rows)
    tmp = OUT / f"{page:05d}.csv.gz.tmp"
    with gzip.open(tmp, "wt", encoding="utf-8") as f:
        f.write(buf.getvalue())
    tmp.rename(OUT / f"{page:05d}.csv.gz")


def main() -> None:
    load_dotenv(ROOT / ".env")
    key = os.getenv("CULTURE_ENTRY_API_KEY", "").strip()
    if not key:
        sys.exit("CULTURE_ENTRY_API_KEY 가 .env 에 없습니다.")
    ap = argparse.ArgumentParser()
    ap.add_argument("--every", type=int, default=1, help="N페이지마다 1페이지 (표본 추출)")
    ap.add_argument("--limit", type=int, default=None, help="테스트용: 앞 N 페이지까지만")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    limit = args.limit

    with httpx.Client(timeout=90, headers={"Accept": "application/json"}) as client:
        first = OUT / "00001.csv.gz"
        body = fetch(client, key, 1)
        total = int(body.get("totalCount") or 0)
        pages = math.ceil(total / ROWS)
        if not first.exists():
            save(1, to_rows((body.get("items") or {}).get("item")))
        last = min(pages, limit) if limit else pages
        sampled = [p for p in range(1, last + 1) if (p - 1) % args.every == 0]
        (OUT.parent / "manifest.json").write_text(
            json.dumps({"total_count": total, "rows_per_page": ROWS, "pages": pages, "every": args.every, "sampled_pages": sampled}, ensure_ascii=False)
        )
        todo = [p for p in sampled if p != 1 and not (OUT / f"{p:05d}.csv.gz").exists()]
        print(f"totalCount={total:,} pages={pages} | 남은 페이지 {len(todo)} | 예상 {len(todo) * GAP_SEC / 3600:.1f}시간", flush=True)
        started = time.monotonic()
        for n, p in enumerate(todo, 1):
            time.sleep(GAP_SEC)
            rows = to_rows((fetch(client, key, p).get("items") or {}).get("item"))
            save(p, rows)
            if n % 20 == 0 or n == len(todo):
                rate = (time.monotonic() - started) / n
                print(f"page {p}/{last} ({n}/{len(todo)}) rows={len(rows)} | 남은 시간 약 {(len(todo) - n) * rate / 60:.0f}분", flush=True)
    print("DONE", flush=True)


if __name__ == "__main__":
    main()
