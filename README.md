# OLPARK RUN

올림픽공원 방문자가 **운동 종류·목표 거리·가능 시간대**를 고르면, 날씨·대기질·**공원 단위** 혼잡도 같은 공공데이터를 바탕으로 오늘 운동하기 좋은 시간과 공식 코스를 추천하는 MVP입니다.

- 팀 작업 지시서: [OLPARK_RUN_VIBE_CODING.md](OLPARK_RUN_VIBE_CODING.md) (역할 분담·API 계약·완료 기준)
- API 계약: [docs/API_CONTRACT.md](docs/API_CONTRACT.md)
- 시연 대본: [docs/DEMO_SCRIPT.md](docs/DEMO_SCRIPT.md)

## 구조

```text
frontend/   React + Vite + TypeScript (담당 A)   — src/api.ts, src/types.ts, src/components/
backend/    FastAPI (담당 B)                      — app/routes.py, recommender.py, data_sources.py, sample_data.py
shared/     코스·샘플 행사 정적 데이터 (담당 C)
docs/       API 계약, 시연 대본 (담당 C)
```

## 로컬 실행

필요: Python 3.11+, Node.js 20+

### 1. 백엔드 (http://127.0.0.1:8000)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

확인: http://127.0.0.1:8000/api/health → `{"status":"ok"}` · API 문서: http://127.0.0.1:8000/docs

테스트:

```bash
pip install -r requirements-dev.txt
python -m pytest
```

### 2. 프론트엔드 (http://localhost:5173)

```bash
cd frontend
npm install
npm run dev
```

개발 서버가 `/api` 요청을 8000번 포트로 프록시합니다. 다른 주소의 백엔드를 쓰려면 루트 `.env`에 `VITE_API_BASE_URL`을 넣습니다.

### 3. 환경변수 (실데이터 모드에만 필요)

```bash
cp .env.example .env
```

`.env.example`에는 변수 이름만 있습니다. 실제 키 값은 `.env`에만 넣으세요 (`.env`는 git에 올라가지 않습니다).

| 변수 | 용도 | 상태 |
|---|---|---|
| `SEOUL_OPEN_API_KEY` | 서울 열린데이터광장 인증키 | 어댑터 동작 확인 (sample 키 응답 기준) |
| `SEOUL_CITYDATA_AREA` | 도시데이터 장소 코드 | 올림픽공원 = `POI127` (실호출 확인) |
| `KSPO_API_KEY` | 국민체육진흥공단 데이터 | 어댑터 **미구현** (데이터셋 미정) |
| `VITE_API_BASE_URL` | 프론트가 호출할 백엔드 주소 | 선택 |

키 값은 팀 내부 채널로만 공유합니다.

## 데이터 모드

| 모드 | 동작 |
|---|---|
| 시연 모드 (`demo_mode: true`, 기본) | `backend/app/sample_data.py`의 샘플 값 사용. 응답 `data_status: "sample"`, 화면에 **DEMO** 배지 표시 |
| 실데이터 모드 (`demo_mode: false`) | 서울시 도시데이터 어댑터 호출. 키가 없거나 실패하면 `data_status: "unavailable"`과 빈 추천을 돌려주고, 값을 지어내지 않음 |

## 추천 로직 요약 (초기 설계값)

`backend/app/recommender.py` — 100점에서 날씨·대기질·공원 혼잡도별로 감점하는 규칙 기반 점수입니다.

- 강수/눈, 대기질 '매우나쁨', 극한 기온(≥33°C, ≤-10°C)이면 점수와 무관하게 **야외운동 비권장**
- 러닝은 혼잡 감점을 1.4배로 봅니다. 데이터가 빠진 항목은 소폭 감점하고 "정보 없음"으로 표시합니다
- 행사 일정은 점수에 반영하지 않고 주의 정보로만 보여줍니다
- 코스는 목표 거리와 가장 가까운 공식 코스를 고릅니다

가중치는 검증된 예측값이 아닙니다. 발표 때도 "초기 설계값"으로 설명합니다.

## 현재 상태와 남은 일

- [x] API 계약대로 동작하는 백엔드 + 샘플 모드
- [x] 입력 → 추천 → 코스·행사·출처 표시 화면, 로딩/오류/데이터 없음 상태, 모바일 레이아웃
- [x] (B) 서울시 도시데이터 응답 구조 검증 (sample 키), 강수·예보·행사 파싱, 5분 캐시, 오래된 데이터 감지, pytest 27개
- [x] (B) 올림픽공원 장소 코드(POI127) 확정, 실데이터 모드 실호출 확인
- [ ] (B) 시간별 대기질 예보 소스 확정 (현재는 현재값만 첫 시간에 반영)
- [ ] (B/C) 공원 공지 소스 확정 — 행사는 실 모드에서 서울시 도시데이터 `EVENT_STTS` 사용
- [ ] (C) 코스 설명·공식 안내 링크(`map_url`)·좌표를 공식 자료로 채우기
- [ ] (A) 디자인 다듬기, 접근성 점검
