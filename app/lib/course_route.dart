// 코스 '개략도'를 그리기 위한 화면 배치 정보.
//
// ⚠ 실제 좌표가 아니다. 공식 좌표가 확보되기 전까지(담당 C) 경유지 '순서'만 공식 안내를 따르고,
//   위치·축척은 화면에 보기 좋게 배치한 값이다. 화면에서는 항상 '개략도'로 표시한다.
import 'dart:ui';

import 'models.dart';

/// 0 0 390 480 좌표계 안의 개략 위치
const Map<String, Offset> schematicPlaces = {
  '곰말다리': Offset(130, 120),
  '몽촌토성 중심': Offset(195, 250),
  '서울역사편찬원': Offset(280, 335),
  '88마당': Offset(330, 235),
  '삼거리매점': Offset(305, 150),
  '피크닉장': Offset(115, 310),
  '소마미술관': Offset(70, 210),
  '평화의광장': Offset(65, 120),
  '움집터전시관': Offset(240, 290),
  '야생화학습장': Offset(165, 190),
  '몽촌토성 순환': Offset(285, 215),
};

const Size schematicSize = Size(390, 480);

enum RingShape { fortress, outer }

/// 경유지가 따로 없는 순환 코스
const Map<String, RingShape> _rings = {
  'earthen-wall-road': RingShape.fortress,
  'youth-road': RingShape.outer,
};

const Map<String, String> _ringNotes = {
  'earthen-wall-road': '몽촌토성 둘레를 한 바퀴',
  'youth-road': '공원 바깥 자전거 순환도로를 한 바퀴',
};

class RouteStop {
  const RouteStop(this.name, this.order, this.position);
  final String name;
  final int order; // 1부터
  final Offset position;
}

class CourseRoute {
  const CourseRoute({required this.waypoints, required this.stops, this.ring, this.note});

  /// 공식 안내 순서의 경유지 이름
  final List<String> waypoints;

  /// 그릴 수 있는 경유지 (이름을 모르는 곳은 빠짐)
  final List<RouteStop> stops;
  final RingShape? ring;
  final String? note;

  bool get drawable => stops.length >= 2 || ring != null;
}

/// description 첫 문장 "A → B → C." 에서 경유지 순서를 읽는다.
/// TODO(C): API에 waypoints 필드가 생기면 그것을 우선 사용한다.
List<String> parseWaypoints(String description) {
  final first = description.split(RegExp(r'\.\s')).first.replaceAll(RegExp(r'\.$'), '');
  if (!first.contains('→')) return const [];
  return first.split('→').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
}

CourseRoute routeOf(Course course) {
  final waypoints = parseWaypoints(course.description);
  final stops = <RouteStop>[];
  for (var i = 0; i < waypoints.length; i++) {
    final p = schematicPlaces[waypoints[i]];
    if (p != null) stops.add(RouteStop(waypoints[i], i + 1, p));
  }
  return CourseRoute(waypoints: waypoints, stops: stops, ring: _rings[course.id], note: _ringNotes[course.id]);
}

/// "목표 5km보다 0.71km 짧아요"
String distanceDiffText(double distance, num target) {
  final d = ((distance - target) * 100).round() / 100;
  if (d.abs() < 0.05) return '목표 ${target}km와 거의 같아요';
  return '목표 ${target}km보다 ${d.abs().toStringAsFixed(2)}km ${d > 0 ? '길어요' : '짧아요'}';
}
