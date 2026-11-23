import 'dart:async';

import 'package:olpark_run/location.dart';

class FakeLocation implements LocationSource {
  FakeLocation([this.access = LocationAccess.granted]);
  LocationAccess access;
  final controller = StreamController<GeoFix>.broadcast();
  int settingsOpened = 0;

  @override
  Future<LocationAccess> requestAccess() async => access;
  @override
  Stream<GeoFix> fixes() => controller.stream;
  @override
  Future<void> openSettings(LocationAccess a) async => settingsOpened++;
}

/// 올림픽공원 근처에서 북쪽으로 north도 이동한 지점. 위도 0.0009도 ≈ 100m
GeoFix fix(double north, int sec, {double acc = 5}) =>
    GeoFix(lat: 37.52 + north, lng: 127.12, accuracyM: acc, time: DateTime(2026, 11, 23, 19).add(Duration(seconds: sec)));
