// OLPARK_RUN_VIBE_CODING.md 3절 API 계약과 1:1로 맞춘다. (백엔드: backend/app/schemas.py)
// 필드가 빠지거나 형식이 어긋나도 앱이 죽지 않도록 기본값만 채우고, 값을 지어내지 않는다.

enum Activity { run, walk }

enum TimePreference { morning, afternoon, evening, any }

extension ActivityX on Activity {
  String get api => name;
  String get label => this == Activity.run ? '러닝' : '산책';
}

extension TimePreferenceX on TimePreference {
  String get api => name;
  String get label => const {
        TimePreference.morning: '아침',
        TimePreference.afternoon: '오후',
        TimePreference.evening: '저녁',
        TimePreference.any: '아무 때나',
      }[this]!;
}

/// 사용자가 고른 오늘 목표
class Goal {
  const Goal({this.activity = Activity.run, this.km = 5, this.time = TimePreference.evening});

  final Activity activity;
  final int km;
  final TimePreference time;

  Goal copyWith({Activity? activity, int? km, TimePreference? time}) =>
      Goal(activity: activity ?? this.activity, km: km ?? this.km, time: time ?? this.time);

  Map<String, dynamic> toRequest({required bool demo}) => {
        'activity': activity.api,
        'target_distance_km': km,
        'time_preference': time.api,
        'demo_mode': demo,
      };
}

const unsafeRating = '야외운동 비권장';

String? _str(dynamic v) => v is String && v.isNotEmpty ? v : null;
List<String> _strings(dynamic v) => v is List ? v.whereType<String>().toList() : const [];

class Conditions {
  const Conditions({this.weather, this.airQuality, this.parkCrowding});
  final String? weather;
  final String? airQuality;
  final String? parkCrowding;

  factory Conditions.fromJson(dynamic j) {
    final m = j is Map ? j : const {};
    return Conditions(
      weather: _str(m['weather']),
      airQuality: _str(m['air_quality']),
      parkCrowding: _str(m['park_crowding']),
    );
  }
}

class TimeRecommendation {
  const TimeRecommendation({
    required this.timeLabel,
    required this.timeIso,
    required this.score,
    required this.rating,
    required this.reasons,
    required this.conditions,
    required this.cautions,
  });

  final String timeLabel;
  final String timeIso;
  final int score;
  final String rating;
  final List<String> reasons;
  final Conditions conditions;
  final List<String> cautions;

  bool get unsafe => rating == unsafeRating;

  static TimeRecommendation? tryParse(dynamic j) {
    if (j is! Map || j['time_iso'] is! String) return null;
    final score = j['score'];
    return TimeRecommendation(
      timeLabel: _str(j['time_label']) ?? j['time_iso'] as String,
      timeIso: j['time_iso'] as String,
      score: score is num ? score.round().clamp(0, 100) : 0,
      rating: _str(j['rating']) ?? '보통',
      reasons: _strings(j['reasons']),
      conditions: Conditions.fromJson(j['conditions']),
      cautions: _strings(j['cautions']).toSet().toList(),
    );
  }
}

class Course {
  const Course({required this.id, required this.name, required this.distanceKm, required this.description, this.mapUrl});

  final String id;
  final String name;
  final double distanceKm;
  final String description;
  final String? mapUrl;

  static Course? tryParse(dynamic j) {
    if (j is! Map || j['id'] is! String || j['distance_km'] is! num) return null;
    return Course(
      id: j['id'] as String,
      name: _str(j['name']) ?? j['id'] as String,
      distanceKm: (j['distance_km'] as num).toDouble(),
      description: _str(j['description']) ?? '',
      mapUrl: _str(j['map_url']),
    );
  }
}

class ParkEvent {
  const ParkEvent({required this.id, required this.type, required this.title, this.startTime, this.endTime, this.location, this.note, this.isSample = false});

  final String id;
  final String type; // event | notice
  final String title;
  final String? startTime;
  final String? endTime;
  final String? location;
  final String? note;
  final bool isSample;

  static ParkEvent? tryParse(dynamic j) {
    if (j is! Map || j['title'] is! String) return null;
    return ParkEvent(
      id: _str(j['id']) ?? j['title'] as String,
      type: j['type'] == 'notice' ? 'notice' : 'event',
      title: j['title'] as String,
      startTime: _str(j['start_time']),
      endTime: _str(j['end_time']),
      location: _str(j['location']),
      note: _str(j['note']),
      isSample: j['is_sample'] == true,
    );
  }
}

class Source {
  const Source({required this.name, this.updatedAt});
  final String name;
  final String? updatedAt;
}

class RecommendationResponse {
  const RecommendationResponse({
    required this.generatedAt,
    required this.isDemo,
    required this.dataStatus,
    required this.recommendations,
    required this.course,
    required this.events,
    required this.sources,
    required this.disclaimer,
  });

  final String generatedAt;
  final bool isDemo;
  final String dataStatus; // sample | live | partial | unavailable
  final List<TimeRecommendation> recommendations;
  final Course? course;
  final List<ParkEvent> events;
  final List<Source> sources;
  final String disclaimer;

  bool get unavailable => dataStatus == 'unavailable';

  /// 맨 앞 추천(선호 시간대 우선 정렬됨)
  TimeRecommendation? get top => recommendations.isEmpty ? null : recommendations.first;

  /// 첫 추천이 비권장일 때 대신 보여줄 가장 이른 안전한 시간대
  TimeRecommendation? get safeAlternative {
    for (final r in recommendations) {
      if (!r.unsafe) return r;
    }
    return null;
  }

  factory RecommendationResponse.fromJson(dynamic raw) {
    if (raw is! Map) throw const FormatException('서버 응답 형식이 올바르지 않습니다');
    List<T> list<T>(dynamic v, T? Function(dynamic) parse) =>
        v is List ? v.map(parse).whereType<T>().toList() : <T>[];
    return RecommendationResponse(
      generatedAt: _str(raw['generated_at']) ?? '',
      isDemo: raw['mode'] != 'live',
      dataStatus: _str(raw['data_status']) ?? 'unavailable',
      recommendations: list(raw['recommendations'], TimeRecommendation.tryParse),
      course: Course.tryParse(raw['course']),
      events: list(raw['events'], ParkEvent.tryParse),
      sources: list(raw['sources'], (s) => s is Map && s['name'] is String ? Source(name: s['name'] as String, updatedAt: _str(s['updated_at'])) : null),
      disclaimer: _str(raw['disclaimer']) ?? '',
    );
  }
}
