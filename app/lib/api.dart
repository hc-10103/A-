// 백엔드 호출은 이 파일에서만 한다.
//
// 주소: 빌드할 때 --dart-define=API_BASE_URL=http://... 로 바꾼다.
//   기본값은 Android 에뮬레이터에서 내 컴퓨터를 가리키는 10.0.2.2.
//   iOS 시뮬레이터는 http://127.0.0.1:8000, 실제 폰은 같은 Wi-Fi의 컴퓨터 IP를 쓴다.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000');

enum ApiErrorKind { network, timeout, http, invalid }

class ApiException implements Exception {
  const ApiException(this.kind, this.message, [this.status]);
  final ApiErrorKind kind;
  final String message;
  final int? status;

  /// 사용자에게 보여줄 안내
  String get hint => switch (kind) {
        ApiErrorKind.network => '서버에 연결할 수 없어요. 백엔드가 켜져 있는지 확인해 주세요.',
        ApiErrorKind.timeout => '서버 응답이 너무 늦어요. 잠시 후 다시 시도해 주세요.',
        ApiErrorKind.invalid => '서버 응답 형식이 올바르지 않아요.',
        ApiErrorKind.http => status == 422 ? '요청 값이 올바르지 않아요. 목표를 다시 골라 주세요.' : '서버 오류예요 ($status). 잠시 후 다시 시도해 주세요.',
      };

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _base = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/$'), '');

  final http.Client _client;
  final String _base;
  static const _timeout = Duration(seconds: 10);

  Future<dynamic> _send(Future<http.Response> Function(Uri) call, String path) async {
    final http.Response res;
    try {
      res = await call(Uri.parse('$_base$path')).timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorKind.timeout, 'timeout');
    } on http.ClientException {
      throw const ApiException(ApiErrorKind.network, 'network');
    } catch (_) {
      // 플랫폼별 소켓 오류 등은 모두 '연결 불가'로 본다
      throw const ApiException(ApiErrorKind.network, 'network');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(ApiErrorKind.http, 'http ${res.statusCode}', res.statusCode);
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalid, 'invalid json');
    }
  }

  Future<RecommendationResponse> recommendations(Goal goal, {required bool demo}) async {
    final raw = await _send(
      (u) => _client.post(u, headers: {'Content-Type': 'application/json'}, body: jsonEncode(goal.toRequest(demo: demo))),
      '/api/recommendations',
    );
    try {
      return RecommendationResponse.fromJson(raw);
    } on FormatException {
      throw const ApiException(ApiErrorKind.invalid, 'invalid shape');
    }
  }

  Future<List<Course>> courses() async {
    final raw = await _send((u) => _client.get(u), '/api/courses');
    return raw is List ? raw.map(Course.tryParse).whereType<Course>().toList() : <Course>[];
  }
}
