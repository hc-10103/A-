# OLPARK RUN 앱 (Flutter · iOS/Android)

올림픽공원 러닝 추천 앱. 웹이 아니라 모바일 앱만 대상으로 한다. 화면 구성은 디자인 캔버스 "OLPARK RUN Flutter 앱"을 따른다.

- 홈: 오늘 추천을 문장으로 보여주고 큰 **시작** 버튼 하나로 출발. 비·위험 대기질이면 '쉬어가요' 화면으로 바뀜
- 목표: 큰 버튼 3번(운동·거리·시간대)으로 끝나는 입력
- 코스: 개략도 지도 + 공식 경유지 순서 + 코스 전환
- 러닝 중: 큰 숫자 하나, 옆으로 밀면 지도. 일시정지 → 끝내기/다시

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
  widgets/course_map.dart, widgets/info_sheet.dart
  screens/home_screen.dart, goal_screen.dart, route_screen.dart, run_screen.dart
```

Flutter 3.50부터 Material 위젯은 `package:material_ui/material_ui.dart`에서 가져온다 (`flutter/material.dart`는 deprecated).

## 정확성 원칙 (팀 문서 0절)

- 혼잡도는 항상 '공원 전체'로 표시. 코스별 혼잡도처럼 쓰지 않음
- 지도는 **개략도** 배지 고정. 공식 좌표가 생기면 `CourseMap`을 flutter_map 등으로 교체
- 위치 추적(GPS) 미연동: 거리·페이스는 '—'로 두고 시간만 실제로 측정. 기록 탭은 준비 중 안내
- 데모 모드면 DEMO 배지와 '샘플 데이터' 출처를 홈에 표시
- 위험 조건이면 점수와 관계없이 '쉬어가요' 화면

## 남은 일

- [ ] GPS 연동(geolocator) → 거리·페이스·진행 위치, 기록 저장
- [ ] 알림(내일 아침 추천 시간 알림)
- [ ] (C) 코스 공식 좌표 → 실제 지도
- [ ] 배포용 https 백엔드 주소 (지금은 개발용 http 허용: Android `usesCleartextTraffic`, iOS `NSAllowsLocalNetworking`)
