import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:olpark_run/api.dart';
import 'package:olpark_run/app_state.dart';
import 'package:olpark_run/main.dart';
import 'package:olpark_run/theme.dart';

Map<String, dynamic> _response({bool unsafeTop = false}) => {
      'generated_at': '2026-11-23T18:00:00+09:00',
      'mode': 'demo',
      'data_status': 'sample',
      'recommendations': [
        {
          'time_label': '오늘 19:00',
          'time_iso': '2026-11-23T19:00:00+09:00',
          'score': 82,
          'rating': unsafeTop ? '야외운동 비권장' : '좋음',
          'reasons': [unsafeTop ? '강수 예보(비)가 있어 야외운동을 권장하지 않습니다' : '대기질이 양호합니다'],
          'conditions': {'weather': unsafeTop ? '비' : '맑음', 'air_quality': '좋음', 'park_crowding': '여유'},
          'cautions': [],
        },
        {
          'time_label': '내일 07:00',
          'time_iso': '2026-11-24T07:00:00+09:00',
          'score': 64,
          'rating': '보통',
          'reasons': ['날씨가 흐림입니다'],
          'conditions': {'weather': '흐림', 'air_quality': '보통', 'park_crowding': '여유'},
          'cautions': [],
        },
      ],
      'course': {'id': 'lovers-road', 'name': '연인의 길', 'distance_km': 4.29, 'description': '곰말다리 → 몽촌토성 중심 → 곰말다리. 설명.', 'map_url': null},
      'events': [],
      'sources': [
        {'name': '샘플 데이터', 'updated_at': '2026-11-23T17:50:00+09:00'},
      ],
      'disclaimer': '혼잡도는 공원 단위입니다.',
    };

AppState _state(http.Client client) => AppState(api: ApiClient(client: client, baseUrl: 'http://test'));

MockClient _backend({bool unsafeTop = false, int status = 200}) => MockClient((req) async {
      if (status != 200) return http.Response('boom', status);
      if (req.url.path == '/api/courses') return http.Response('[]', 200);
      return http.Response.bytes(utf8.encode(jsonEncode(_response(unsafeTop: unsafeTop))), 200, headers: {'content-type': 'application/json'});
    });

Future<void> _pump(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OlparkRunApp(state: state));
  await state.load();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => useGoogleFonts = false);

  testWidgets('home shows the recommendation sentence, start button and DEMO badge', (tester) async {
    await _pump(tester, _state(_backend()));
    expect(find.text('오늘 19:00에 달리기 좋아요'), findsOneWidget);
    expect(find.text('시작'), findsOneWidget);
    expect(find.text('DEMO'), findsOneWidget);
    expect(find.textContaining('5km 목표 · 연인의 길'), findsOneWidget);
    expect(find.textContaining('샘플 데이터'), findsWidgets); // 출처가 홈에 보임
  });

  testWidgets('unsafe top hour shows the rest-day view instead of start', (tester) async {
    await _pump(tester, _state(_backend(unsafeTop: true)));
    expect(find.text('오늘 19:00에는 쉬어가요'), findsOneWidget);
    expect(find.text('내일 07:00'), findsOneWidget);
    expect(find.text('시작'), findsNothing);
  });

  testWidgets('server error shows a retry card instead of crashing', (tester) async {
    await _pump(tester, _state(_backend(status: 500)));
    expect(find.text('추천을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('goal screen returns the picked goal and reloads', (tester) async {
    final state = _state(_backend());
    await _pump(tester, state);
    await tester.tap(find.text('5km').first);
    await tester.pumpAndSettle();
    expect(find.text('오늘 목표'), findsOneWidget);
    await tester.tap(find.text('산책'));
    await tester.tap(find.text('2km', findRichText: true));
    await tester.pump();
    expect(find.textContaining('2km 산책 → 토성의 길'), findsOneWidget);
    await tester.tap(find.text('이 목표로 추천 받기'));
    await tester.pumpAndSettle();
    expect(state.goal.km, 2);
    expect(find.text('오늘 목표'), findsNothing);
  });

  testWidgets('run screen counts time and pauses', (tester) async {
    await _pump(tester, _state(_backend()));
    await tester.tap(find.text('시작'));
    // 스톱워치가 0.5초마다 다시 그려서 pumpAndSettle 대신 시간을 정해 진행
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('달린 시간'), findsOneWidget);
    expect(find.text('—'), findsWidgets); // 거리·페이스는 지어내지 않음
    await tester.tap(find.bySemanticsLabel('일시정지'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('일시정지됨'), findsOneWidget);
    expect(find.text('끝내기'), findsOneWidget);
    await tester.tap(find.text('끝내기'));
    await tester.pumpAndSettle();
    expect(find.text('시작'), findsOneWidget);
  });
}
