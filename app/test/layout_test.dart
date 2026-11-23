// 여러 안드로이드 화면 크기·글자 크기에서 화면이 넘치지 않는지 (RenderFlex overflow 등) 확인한다.
// 데이터는 백엔드 시연 모드 응답을 그대로 저장한 것 (test/fixtures).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:olpark_run/api.dart';
import 'package:olpark_run/app_state.dart';
import 'package:olpark_run/location.dart';
import 'package:olpark_run/main.dart';
import 'package:olpark_run/theme.dart';

import 'fakes.dart';

/// (이름, 논리 너비, 논리 높이) — 대부분의 안드로이드 폰이 이 범위 안에 있다
const _phones = [('small 360x640', 360.0, 640.0), ('S22 384x832', 384.0, 832.0), ('tall 412x915', 412.0, 915.0)];

final _rec = File('test/fixtures/recommendations_demo.json').readAsBytesSync();
final _courses = File('test/fixtures/courses.json').readAsBytesSync();

/// GPS 스트림이 열리자마자 실패하는 기기 (권한 문제 등) → '위치 켜기' 카드가 가장 길다
class _BrokenGps extends FakeLocation {
  @override
  Stream<GeoFix> fixes() => Stream.error(StateError('no gps'));
}

void main() {
  setUp(() => useGoogleFonts = false);

  final cases = [
    for (final p in _phones) (p, 1.0, false),
    for (final p in _phones) (p, 1.0, true),
    (_phones.first, 1.3, true), // 작은 폰 + 큰 글씨 + GPS 카드: 가장 빡빡한 경우
    (_phones[1], 1.3, false),
  ];

  for (final ((name, w, h), scale, brokenGps) in cases) {
    testWidgets('$name text×$scale${brokenGps ? ' gps-error' : ''}: no overflow', (tester) async {
      final problems = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (d) => problems.add(d.exceptionAsString().split('\n').first);
      String? where;
      void check(String screen) {
        if (problems.isNotEmpty) where ??= '$screen: ${problems.join('; ')}';
        problems.clear();
      }

      try {
        tester.view.physicalSize = Size(w * 3, h * 3);
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });

        final client = MockClient(
          (req) async => http.Response.bytes(req.url.path == '/api/courses' ? _courses : _rec, 200, headers: {'content-type': 'application/json'}),
        );
        final state = AppState(
          api: ApiClient(client: client, baseUrl: 'http://test'),
          location: brokenGps ? _BrokenGps() : FakeLocation(),
        );
        await tester.pumpWidget(OlparkRunApp(state: state));
        await state.load();
        await tester.pump(const Duration(milliseconds: 500));
        check('home');

        // 시작 버튼이 첫 화면 안에 보여야 한다 (스크롤 없이)
        final startBottom = tester.getBottomLeft(find.text('시작')).dy;
        if (startBottom > h) where ??= 'home: 시작 button off-screen (${startBottom.round()} > ${h.round()})';

        await tester.tap(find.text('코스'));
        await tester.pump(const Duration(milliseconds: 500));
        check('courses tab');
        await tester.tap(find.text('러닝'));
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('5km'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        check('goal');
        tester.state<NavigatorState>(find.byType(Navigator)).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        await tester.tap(find.text('시작'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        check('run');

        await tester.tap(find.byIcon(Icons.pause));
        await tester.pump(const Duration(milliseconds: 300));
        check('run paused');

        await tester.tap(find.text('지도'));
        await tester.pump(const Duration(milliseconds: 500));
        check('run map');

        await tester.tap(find.text('끝내기'));
        await tester.pump(const Duration(milliseconds: 500));
        check('finish summary');
      } finally {
        FlutterError.onError = original;
      }
      expect(where, isNull, reason: where);

      // 러닝 화면의 1초 타이머를 정리
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
