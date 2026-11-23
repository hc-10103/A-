# OLPARK RUN 앱 (Flutter · iOS/Android)

올림픽공원 러닝 추천 앱. 웹이 아니라 모바일 앱만 대상으로 한다. 화면 구성은 디자인 캔버스 "OLPARK RUN Flutter 앱"을 따른다.

- 홈: 오늘 추천을 문장으로 보여주고 큰 **시작** 버튼 하나로 출발. 비·위험 대기질이면 '쉬어가요' 화면으로 바뀜
- 목표: 큰 버튼 3번(운동·거리·시간대)으로 끝나는 입력
- 코스: 개략도 지도 + 공식 경유지 순서 + 코스 전환
- 러닝 중: GPS로 잰 거리(km)를 큰 숫자로, 시간·페이스·남은 거리, 옆으로 밀면 지도. 일시정지 → 끝내기 → 요약

## 실행

필요: Flutter 3.50+ (`brew install --cask flutter`), iOS는 Xcode, Android는 Android Studio(에뮬레이터)

```bash
cd backend && source .venv/bin/activate && uvicorn app.main:app --port 8000   # 백엔드 먼저
cd app
flutter pub get
flutter run                                                  # Android 에뮬레이터 (기본 주소 10.0.2.2:8000)
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 # iOS 시뮬레이터
```

실제 폰은 같은 Wi-Fi에서 컴퓨터 IP로 `API_BASE_URL`을 넘긴다. 백엔드를 `--host 0.0.0.0`으로 띄워야 한다.

## 테스트

```bash
flutter analyze
flutter test
```

## 구조

```text
lib/
  main.dart            앱 · 하단 탭(러닝/코스/기록)
  theme.dart           색·글꼴 (디자인 캔버스와 동일)
  models.dart          API 계약 타입 (값이 없으면 null, 지어내지 않음)
  api.dart             백엔드 호출은 여기서만
  app_state.dart       목표 + 추천 결과 상태
  course_route.dart    개략도 배치 (⚠ 실제 좌표 아님)
  location.dart        위치 접근 (geolocator) — 화면은 LocationSource 인터페이스만 사용
  run_tracker.dart     시간 + GPS 거리·페이스 계산
  widgets/course_map.dart, widgets/info_sheet.dart
  screens/home_screen.dart, goal_screen.dart, route_screen.dart, run_screen.dart
```

Flutter 3.50부터 Material 위젯은 `package:material_ui/material_ui.dart`에서 가져온다 (`flutter/material.dart`는 deprecated).

## 정확성 원칙 (팀 문서 0절)

- 혼잡도는 항상 '공원 전체'로 표시. 코스별 혼잡도처럼 쓰지 않음
- 지도는 **개략도** 배지 고정. 공식 좌표가 생기면 `CourseMap`을 flutter_map 등으로 교체
- 위치 권한이 없거나 GPS를 못 받으면 거리·페이스는 '—', 시간만 기록하고 '위치 켜기' 안내
- 데모 모드면 DEMO 배지와 '샘플 데이터' 출처를 홈에 표시
- 위험 조건이면 점수와 관계없이 '쉬어가요' 화면

## GPS 거리 측정

`lib/run_tracker.dart` — 초기 설계값이며 실제 러닝으로 조정 필요:

- 정확도 30m보다 나쁜 측정은 버리고 'GPS 신호가 약해요' 표시
- 직전 지점에서 초속 12m보다 빠르게 튄 점은 GPS 오류로 보고 버림
- 2m 미만 이동은 제자리 흔들림으로 보고 무시, 일시정지 중 이동도 세지 않음
- 페이스는 50m 이상 달린 뒤부터 표시
- 화면이 꺼져도 기록: Android는 포그라운드 서비스 알림, iOS는 백그라운드 위치(`UIBackgroundModes: location`, 파란 표시)
- 개략도에는 현재 위치를 찍지 않음 (코스 좌표가 없어서). 대신 코스 진행률 막대

⚠ 실제 기기에서 아직 돌려보지 않았다. 처음 실행할 때 권한 팝업·화면 끈 상태 기록·거리 정확도를 꼭 확인할 것.

## 남은 일

- [x] GPS 거리·페이스 (geolocator)
- [ ] 실제 기기에서 GPS 정확도·백그라운드 기록 확인
- [ ] 러닝 기록 저장·기록 탭
- [ ] 알림(내일 아침 추천 시간 알림)
- [ ] (C) 코스 공식 좌표 → 실제 지도
- [ ] 배포용 https 백엔드 주소 (지금은 개발용 http 허용: Android `usesCleartextTraffic`, iOS `NSAllowsLocalNetworking`)
