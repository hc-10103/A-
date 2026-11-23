# API 계약

원본: [OLPARK_RUN_VIBE_CODING.md 3절](../OLPARK_RUN_VIBE_CODING.md#3-공통-데이터-계약). 계약을 바꾸려면 **이 문서부터** 고치고 프론트·백엔드 합의 후 반영합니다.
코드상 기준: 백엔드 `backend/app/schemas.py`, 프론트 `frontend/src/types.ts`.

## POST /api/recommendations

요청

| 필드 | 타입 | 값 |
|---|---|---|
| `activity` | string | `run` \| `walk` |
| `target_distance_km` | number | 0 초과 (UI는 2/3/5) |
| `time_preference` | string | `morning`(05–11시) \| `afternoon`(12–17시) \| `evening`(18–23시) \| `any` |
| `demo_mode` | boolean | 기본 `true` |

잘못된 값은 `422`를 돌려줍니다.

응답 필드

| 필드 | 설명 |
|---|---|
| `generated_at` | 생성 시각 (KST, ISO 8601) |
| `mode` | `demo` \| `live` |
| `data_status` | `sample`(샘플) \| `live`(정상) \| `partial`(일부 누락) \| `unavailable`(데이터 없음) |
| `recommendations[]` | 현재~12시간 뒤까지 시간별 항목. 정렬: 선호 시간대 → 안전 → 심야 후순위 → 점수 높은 순 |
| `recommendations[].score` | 0~100 정수, 초기 설계값 기반 참고 점수 |
| `recommendations[].rating` | `좋음` \| `보통` \| `주의` \| `야외운동 비권장` |
| `recommendations[].conditions` | `weather`, `air_quality`, `park_crowding` — 없으면 `null` |
| `recommendations[].reasons[]` / `cautions[]` | 추천 이유 / 주의 문구 |
| `course` | 목표 거리에 가장 가까운 공식 코스. `description`에 공식 안내의 구간 요약을 포함하고 `map_url`은 KSPO 공식 코스 안내 페이지를 가리킵니다. 좌표를 지오코딩해 만든 경로는 아직 제공하지 않습니다. |
| `events[]` | 행사·공지. 없으면 `[]`. 샘플이면 `is_sample: true` |
| `sources[]` | `{name, updated_at}` |
| `disclaimer` | 점수·혼잡도 범위 안내 + 데이터 상태 메모 |

규칙

- `park_crowding`은 **공원 전체** 수준입니다. 코스별 혼잡도로 표현하지 않습니다.
- 강수/눈, 대기질 매우나쁨, 극한 기온이면 점수와 관계없이 `야외운동 비권장`.
- 행사 일정은 점수에 넣지 않습니다.
- 데이터가 없으면 `null`/`unavailable`로 알리고 값을 지어내지 않습니다.

## GET /api/health

`{"status":"ok"}`

## GET /api/courses

공식 코스 목록 (`shared/courses.json`).

## GET /api/events?date=YYYY-MM-DD&demo_mode=true

해당 날짜 행사·공지. `date` 생략 시 오늘(KST). 실데이터 모드는 서울시 도시데이터 행사(기간 필터) + 오늘 날짜면 재난문자 공지.

## 실데이터 모드 동작 (서울시 도시데이터)

- 현재 시각 항목은 관측값(`WEATHER_TIME`, `PPLTN_TIME`), 이후 12시간은 예보값(`FCST24HOURS`, `FCST_PPLTN`)을 씁니다.
- 강수 형태(`PRECPT_TYPE`)가 '없음'이 아니면 `weather`에 강수 형태(비/눈 등)를 넣어 안전 규칙이 적용됩니다.
- 대기질: 현재 시각은 서울시 관측값(`AIR_IDX`). 이후 시간은 `DATA_GO_KR_API_KEY`가 있으면 에어코리아 서울 권역 **일 단위 예보**(PM10·PM2.5 중 나쁜 등급)로 채우고, 추천 이유에 '일 단위 예보'라고 표시합니다. 키가 없거나 실패하면 `null`.
- 재난문자(`LIVE_DST_MESSAGE`)는 `events[]` 맨 앞에 `type: "notice"`, 제목 `[재난문자] …`로 넣습니다. 24시간 지난 문자는 뺍니다. ⚠ 필드명은 공식 명세를 찾지 못해 후보 이름으로 읽습니다.
- 현재 시각은 하늘 상태가 없어 '강수 없음'으로 표시하고, 하늘 상태를 모르므로 중간값(-5)으로 감점합니다.
- 관측 시각이 90분 이상 지났거나 날씨·인구 중 하나가 빠지면 `data_status: "partial"`, 이유는 `disclaimer`에 붙습니다.
- 같은 요청은 5분 동안 캐시합니다.

## 외부 API 지연·장애 대응

- 서울시·에어코리아·KOPIS를 **동시에** 호출하고, 추천 API 전체가 약 8초 안에 응답하도록 시간 상한을 둡니다 (프론트 타임아웃 10초).
- 단계별 타임아웃: 서울시 연결 2.5초/읽기 5초, 에어코리아 2/4초, KOPIS 2/3초.
- 호출에 실패한 API는 5분 동안 다시 부르지 않습니다. 그동안 해당 정보는 없음(`null`/빈 목록)으로 처리합니다.
- 공연 정보(KSPO 패턴·KOPIS) 처리 중 오류가 나도 추천 자체는 정상 응답합니다.

## 오늘 공연 일정 (KOPIS, 실데이터 모드)

- KOPIS 공연예술통합전산망에서 올림픽공원(공연시설 `FC001247`)의 그날 공연을 조회합니다 (`KOPIS_API_KEY`, 30분 캐시).
- `events[]`에 공연명, `location`(예: `올림픽공원 KSPO DOME(체조경기장)`), `start_time`, `note`(요일별 공연 시간 원문·공연장 좌석 규모)를 넣습니다. 공연 기간 중이라도 요일 일정상 그날 공연이 없으면(휴연일) 뺍니다.
- 추천 시각이 공연 시작 2시간 전 ~ 3시간 후면 `cautions`에 공연 예정 문구를 붙입니다. **점수에는 반영하지 않습니다.**
- `sources[]`에 "(재)예술경영지원센터 공연예술통합전산망(www.kopis.or.kr)"을 넣습니다 (KOPIS 이용 조건상 출처 표기 필수).
- 한계: 예매처를 통해 등록된 공연 위주라 무료 행사 등은 빠질 수 있습니다. 공휴일(HOL) 일정은 판단하지 않습니다. 시연 모드에서는 호출하지 않습니다.

## 한국체육산업개발 공연 기록 (2025)

- 2025년 올림픽공원 시간대별 공연 기록(7,803시간, 공연 773시간)을 요일·시간대별로 집계해 둔 정적 파일을 씁니다.
- 추천 시간대가 2025년에 공연이 열린 날이 30% 이상인 요일·시간대면 `cautions`에 '2025년 기록상 … 공연이 자주/대부분 열린 시간대' 문구를 붙입니다 (70% 이상 '대부분', 표본 10일 미만 칸 제외 — 초기 설계값).
- **점수에는 반영하지 않습니다.** 올해 공연 일정이나 혼잡 예측이 아니라 과거 기록 기반 참고 정보입니다.
- 데이터 한계: 데이터셋 이름은 '차량입출차, 공연, 날씨정보 등 연계 데이터'지만 실제 응답에는 공연명·관람객 수만 있습니다 (2026-11-23 확인).
- `sources[]`에 '한국체육산업개발 올림픽공원 공연 기록 (2025-01-01 ~ 2025-12-31, 참고)'를 넣습니다.

## 외부 데이터 연결 상태

| 소스 | 파일 | 상태 |
|---|---|---|
| 서울시 실시간 도시데이터 (날씨·인구/혼잡 예측·행사) | `data_sources.py` `SeoulCityDataAdapter` | 응답 구조 검증 완료, 올림픽공원(POI127) 실호출 확인 (2026-11-23) |
| 대기질 예보 | `data_sources.py` `AirKoreaForecastAdapter` (data.go.kr 15073861) | 실호출 확인 (2026-11-23). `InformCode`와 무관하게 전체 항목이 와서 1회 호출 후 PM10·PM25만 사용 |
| 재난문자 | `parse_disaster_messages` | 작성됨, 필드명 미검증 |
| 한국체육산업개발 2025 공연 기록 (culture.go.kr id=675) | `app/kspo.py` + `shared/kspo_concert_pattern_2025.json` (생성: `backend/scripts/build_kspo_concert_pattern.py`) | 연결됨. 실행 중 외부 호출 없음 |
| 한국체육산업개발 2025 입출차 (culture.go.kr id=659) | `backend/scripts/download_kspo_entry.py` | 10% 표본 다운로드, 분석 예정 |
| 행사 | 데모: `shared/events.sample.json` / 실: 도시데이터 `EVENT_STTS` (기간으로 날짜 필터) | 실 모드 연결됨 |
| 오늘 공연 일정 | `app/kopis.py` (KOPIS) | 실호출 확인 (2026-11-23) |
| 공원 공지 | — | 미정 |
