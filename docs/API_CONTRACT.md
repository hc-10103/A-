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

## 외부 데이터 연결 상태

| 소스 | 파일 | 상태 |
|---|---|---|
| 서울시 실시간 도시데이터 (날씨·인구/혼잡 예측·행사) | `data_sources.py` `SeoulCityDataAdapter` | 응답 구조 검증 완료, 올림픽공원(POI127) 실호출 확인 (2026-11-23) |
| 대기질 예보 | `data_sources.py` `AirKoreaForecastAdapter` (data.go.kr 15073861) | 실호출 확인 (2026-11-23). `InformCode`와 무관하게 전체 항목이 와서 1회 호출 후 PM10·PM25만 사용 |
| 재난문자 | `parse_disaster_messages` | 작성됨, 필드명 미검증 |
| KSPO | `data_sources.py` `KspoAdapter` | 미구현 |
| 행사 | 데모: `shared/events.sample.json` / 실: 도시데이터 `EVENT_STTS` (기간으로 날짜 필터) | 실 모드 연결됨 |
| 공원 공지·공연 일정 | — | 미정 (공연 일정 공개 API 없음 → C가 공식 일정 수동 정리 검토) |
