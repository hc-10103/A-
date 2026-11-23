import 'package:flutter_test/flutter_test.dart';
import 'package:olpark_run/course_route.dart';
import 'package:olpark_run/models.dart';

const lovers = Course(
  id: 'lovers-road',
  name: '연인의 길',
  distanceKm: 4.29,
  description: '곰말다리 → 몽촌토성 중심 → 서울역사편찬원 → 88마당 → 삼거리매점 → 몽촌토성 중심 → 피크닉장 → 소마미술관 → 평화의광장 → 곰말다리. 88호수와 몽촌토성 주변을 잇는 코스입니다.',
);

void main() {
  group('parseWaypoints', () {
    test('reads the arrow sequence from the first sentence', () {
      final w = parseWaypoints(lovers.description);
      expect(w.first, '곰말다리');
      expect(w.length, 10);
      expect(w[3], '88마당'); // 숫자로 시작하는 이름도 문장 구분자로 오인하지 않음
    });

    test('returns empty for descriptions without arrows', () {
      expect(parseWaypoints('몽촌토성 순환로 코스입니다.'), isEmpty);
    });

    test('loop courses get a ring instead of stops', () {
      final r = routeOf(const Course(id: 'youth-road', name: '젊음의 길', distanceKm: 3.15, description: '외곽 순환 코스입니다.'));
      expect(r.stops, isEmpty);
      expect(r.ring, RingShape.outer);
      expect(r.drawable, isTrue);
    });
  });

  test('distanceDiffText', () {
    expect(distanceDiffText(4.29, 5), '목표 5km보다 0.71km 짧아요');
    expect(distanceDiffText(3.15, 3), '목표 3km보다 0.15km 길어요');
    expect(distanceDiffText(2.02, 2), '목표 2km와 거의 같아요');
  });

  group('RecommendationResponse.fromJson', () {
    test('fills safe defaults for missing fields and drops bad items', () {
      final r = RecommendationResponse.fromJson({
        'recommendations': [null, {'time_iso': '2026-11-23T19:00:00+09:00', 'score': 140, 'rating': '좋음'}],
      });
      expect(r.dataStatus, 'unavailable');
      expect(r.recommendations, hasLength(1));
      expect(r.recommendations.first.score, 100); // 0~100으로 제한
      expect(r.recommendations.first.conditions.weather, isNull); // 지어내지 않음
      expect(r.course, isNull);
      expect(r.events, isEmpty);
    });

    test('safeAlternative skips unsafe hours', () {
      final r = RecommendationResponse.fromJson({
        'data_status': 'sample',
        'recommendations': [
          {'time_iso': 'a', 'time_label': '오늘 19:00', 'score': 95, 'rating': '야외운동 비권장'},
          {'time_iso': 'b', 'time_label': '내일 07:00', 'score': 64, 'rating': '보통'},
        ],
      });
      expect(r.top!.unsafe, isTrue);
      expect(r.safeAlternative!.timeLabel, '내일 07:00');
    });

    test('rejects non-object payloads', () {
      expect(() => RecommendationResponse.fromJson([]), throwsFormatException);
    });
  });
}
