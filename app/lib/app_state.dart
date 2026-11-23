import 'package:flutter/foundation.dart';

import 'api.dart';
import 'location.dart';
import 'models.dart';

/// 앱 전체 상태: 오늘 목표 + 추천 결과. 화면들은 이 객체를 듣기만 한다.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, LocationSource? location})
      : api = api ?? ApiClient(),
        location = location ?? const GeolocatorSource();

  final ApiClient api;

  /// 러닝 중 위치 (테스트에서는 가짜로 바꾼다)
  final LocationSource location;

  Goal goal = const Goal();

  /// 시연 모드: 백엔드 샘플 데이터 사용 (실데이터는 서버에 API 키가 있어야 함)
  bool demoMode = true;

  RecommendationResponse? data;
  bool loading = false;
  ApiException? error;

  List<Course> courses = const [];

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      data = await api.recommendations(goal, demo: demoMode);
    } on ApiException catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
    if (courses.isEmpty) {
      try {
        courses = await api.courses();
        notifyListeners();
      } on ApiException {
        // 코스 목록이 없어도 추천 코스 하나로 계속 쓴다
      }
    }
  }

  Future<void> setGoal(Goal next) async {
    goal = next;
    await load();
  }

  Future<void> setDemoMode(bool on) async {
    demoMode = on;
    await load();
  }
}
