// 위치 접근은 이 파일에서만 한다. 화면·추적기는 LocationSource 인터페이스만 알아서 테스트에서 가짜로 바꿀 수 있다.
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// GPS 한 번의 측정값
class GeoFix {
  const GeoFix({required this.lat, required this.lng, required this.accuracyM, required this.time});
  final double lat;
  final double lng;
  final double accuracyM; // 수평 정확도 (미터, 작을수록 정확)
  final DateTime time;
}

enum LocationAccess { granted, denied, deniedForever, serviceOff }

abstract class LocationSource {
  /// 권한을 확인하고 필요하면 요청한다.
  Future<LocationAccess> requestAccess();

  /// 러닝 중 계속 들어오는 위치. 권한이 있을 때만 구독한다.
  Stream<GeoFix> fixes();

  /// 권한 거부·위치 서비스 꺼짐일 때 설정 화면으로 보낸다.
  Future<void> openSettings(LocationAccess access);
}

class GeolocatorSource implements LocationSource {
  const GeolocatorSource();

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return switch (p) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Stream<GeoFix> fixes() => Geolocator.getPositionStream(locationSettings: _settings()).map(
        (p) => GeoFix(lat: p.latitude, lng: p.longitude, accuracyM: p.accuracy, time: p.timestamp),
      );

  /// 화면이 꺼져도 러닝 기록이 이어지도록:
  /// Android는 포그라운드 서비스 알림, iOS는 앱 사용 중 권한 + 백그라운드 위치(파란 표시).
  LocationSettings _settings() {
    const distanceFilter = 3; // 3m 이상 움직였을 때만 받기
    if (kIsWeb) return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: distanceFilter);
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationTitle: 'OLPARK RUN 러닝 중',
            notificationText: '달린 거리를 기록하고 있어요',
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
        return AppleSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: distanceFilter,
          activityType: ActivityType.fitness,
          pauseLocationUpdatesAutomatically: false,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
        );
      default:
        return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: distanceFilter);
    }
  }

  @override
  Future<void> openSettings(LocationAccess access) async {
    if (access == LocationAccess.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
