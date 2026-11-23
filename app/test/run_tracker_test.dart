import 'package:flutter_test/flutter_test.dart';
import 'package:olpark_run/location.dart';
import 'package:olpark_run/run_tracker.dart';

import 'fakes.dart';

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  test('distanceMeters ~ 100m for 0.0009° latitude', () {
    expect(distanceMeters(37.52, 127.12, 37.5209, 127.12), closeTo(100, 1));
  });

  test('adds distance from good fixes', () async {
    final src = FakeLocation();
    final t = RunTracker(src);
    await t.start();
    src.controller.add(fix(0, 0));
    src.controller.add(fix(0.0009, 30));
    src.controller.add(fix(0.0018, 60));
    await flush();
    expect(t.meters, closeTo(200, 2));
    expect(t.gpsOn, isTrue);
    t.dispose();
  });

  test('drops inaccurate fixes and flags weak signal', () async {
    final src = FakeLocation();
    final t = RunTracker(src);
    await t.start();
    src.controller.add(fix(0, 0));
    src.controller.add(fix(0.0009, 30, acc: 80));
    await flush();
    expect(t.meters, 0);
    expect(t.weakSignal, isTrue);
    t.dispose();
  });

  test('drops GPS jumps faster than 12 m/s', () async {
    final src = FakeLocation();
    final t = RunTracker(src);
    await t.start();
    src.controller.add(fix(0, 0));
    src.controller.add(fix(0.009, 5)); // 1km in 5s
    src.controller.add(fix(0.0009, 30)); // back to a real 100m
    await flush();
    expect(t.meters, closeTo(100, 2));
    t.dispose();
  });

  test('ignores movement while paused', () async {
    final src = FakeLocation();
    final t = RunTracker(src);
    await t.start();
    src.controller.add(fix(0, 0));
    src.controller.add(fix(0.0009, 30));
    await flush();
    t.pause();
    src.controller.add(fix(0.0018, 60));
    await flush();
    t.resume();
    src.controller.add(fix(0.0027, 90)); // first fix after resume is a new start point
    src.controller.add(fix(0.0036, 120));
    await flush();
    expect(t.meters, closeTo(200, 2));
    t.dispose();
  });

  test('denied permission keeps time-only mode', () async {
    final t = RunTracker(FakeLocation(LocationAccess.denied));
    await t.start();
    expect(t.gpsOn, isFalse);
    expect(t.running, isTrue);
    expect(t.pacePerKm, isNull);
    t.dispose();
  });

  test('plugin failure falls back to time-only', () async {
    final t = RunTracker(_Throwing());
    await t.start();
    expect(t.gpsOn, isFalse);
    expect(t.gpsError, isTrue);
    t.dispose();
  });

  test('formatPace', () {
    expect(formatPace(null), '—');
    expect(formatPace(const Duration(minutes: 8, seconds: 44)), "8'44\"");
    expect(formatPace(const Duration(hours: 2)), '—');
  });
}

class _Throwing extends FakeLocation {
  @override
  Future<LocationAccess> requestAccess() => Future.error(UnsupportedError('no gps'));
}
