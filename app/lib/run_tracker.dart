// 러닝 기록: 시간(스톱워치) + GPS 거리·페이스.
//
// 거리 규칙 (초기 설계값, 실제 러닝으로 조정 필요):
// - 정확도가 30m보다 나쁜 측정은 버린다 (신호 약함 표시)
// - 직전 지점에서 초속 12m(시속 43km)보다 빠르게 '튄' 측정은 GPS 오류로 보고 버린다
// - 2m 미만 이동은 제자리 흔들림으로 보고 더하지 않는다
// - 일시정지 중 이동은 더하지 않는다 (다시 시작하면 그 지점부터 이어 잰다)
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'location.dart';

const maxAccuracyM = 30.0;
const maxSpeedMps = 12.0;
const minStepM = 2.0;

/// 두 위도·경도 사이 거리 (미터, haversine)
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

class RunTracker extends ChangeNotifier {
  RunTracker(this.source, {Stopwatch? stopwatch}) : _watch = stopwatch ?? Stopwatch();

  final LocationSource source;
  final Stopwatch _watch;
  StreamSubscription<GeoFix>? _sub;
  GeoFix? _last;
  bool _disposed = false;

  /// null = 아직 확인 중
  LocationAccess? access;
  bool weakSignal = false;
  bool gpsError = false;
  double meters = 0;

  bool get running => _watch.isRunning;
  bool get paused => !_watch.isRunning;
  bool get gpsOn => access == LocationAccess.granted && !gpsError;
  Duration get elapsed => _watch.elapsed;
  double get km => meters / 1000;

  /// km당 평균 페이스. 50m 이상 달려야 계산한다 (그 전엔 값이 크게 튐).
  Duration? get pacePerKm {
    if (meters < 50) return null;
    return Duration(milliseconds: (elapsed.inMilliseconds / km).round());
  }

  Future<void> start() async {
    _watch.start();
    notifyListeners();
    await _check();
  }

  /// 권한을 다시 확인한다 (설정에서 허용하고 돌아왔을 때)
  Future<void> retryAccess() async {
    gpsError = false;
    await _check();
  }

  Future<void> _check() async {
    try {
      access = await source.requestAccess();
    } catch (_) {
      // 위치 기능을 쓸 수 없는 기기·플랫폼: 시간만 기록
      access = LocationAccess.denied;
      gpsError = true;
    }
    if (_disposed) return;
    if (access == LocationAccess.granted && _sub == null) _listen();
    notifyListeners();
  }

  void _listen() {
    _sub = source.fixes().listen(_onFix, onError: (_) {
      // 스트림을 못 열었거나 끊김: 시간만 기록하고, '위치 켜기'로 다시 시도할 수 있게 구독을 비운다
      gpsError = true;
      _stopStream();
      if (!_disposed) notifyListeners();
    });
  }

  /// 플랫폼 쪽 스트림이 이미 닫혀 있으면 cancel이 예외를 던진다 (No active stream to cancel) — 무시한다.
  void _stopStream() {
    final sub = _sub;
    _sub = null;
    _last = null;
    sub?.cancel().catchError((Object _) {});
  }

  void _onFix(GeoFix f) {
    if (paused) return;
    if (f.accuracyM > maxAccuracyM) {
      if (!weakSignal) {
        weakSignal = true;
        notifyListeners();
      }
      return;
    }
    weakSignal = false;
    final last = _last;
    _last = f;
    if (last != null) {
      final d = distanceMeters(last.lat, last.lng, f.lat, f.lng);
      final dt = f.time.difference(last.time).inMilliseconds / 1000;
      if (dt > 0 && d / dt > maxSpeedMps) {
        _last = last; // 튄 점은 버리고 이전 지점 유지
        return;
      }
      if (d >= minStepM) meters += d;
    }
    notifyListeners();
  }

  void pause() {
    _watch.stop();
    _last = null; // 멈춘 동안 움직인 거리는 세지 않음
    notifyListeners();
  }

  void resume() {
    _watch.start();
    notifyListeners();
  }

  void finish() {
    _watch.stop();
    _stopStream();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopStream();
    super.dispose();
  }
}

String formatDuration(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final s = d.inSeconds;
  final h = s ~/ 3600;
  return h > 0 ? '$h:${two(s % 3600 ~/ 60)}:${two(s % 60)}' : '${two(s ~/ 60)}:${two(s % 60)}';
}

/// 8'44"
String formatPace(Duration? pace) {
  if (pace == null) return '—';
  final s = pace.inSeconds;
  if (s >= 60 * 60) return '—'; // 1km에 1시간 넘으면 의미 없는 값
  return "${s ~/ 60}'${(s % 60).toString().padLeft(2, '0')}\"";
}
