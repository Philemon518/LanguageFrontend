import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config.dart';
import '../models/curriculum.dart';

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  set accessToken(String? value) => _accessToken = value;

  Uri authenticatedWebSocketUri(String path) {
    final wsBase = AppConfig.apiBaseUrl.replaceFirst('http', 'ws');
    final uri = Uri.parse('$wsBase$path');
    if (_accessToken == null) return uri;
    return uri.replace(queryParameters: {'token': _accessToken!});
  }

  Map<String, String> get _authorizationHeaders => {
    if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
  };

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    ..._authorizationHeaders,
  };

  Future<AuthSession> register({
    required String username,
    required String password,
  }) => _authenticate('/auth/register', username, password);

  Future<AuthSession> login({
    required String username,
    required String password,
  }) => _authenticate('/auth/login', username, password);

  Future<AuthSession> _authenticate(
    String path,
    String username,
    String password,
  ) async {
    final response = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response, 'Authentication failed'));
    }
    return AuthSession.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<AuthUser> fetchCurrentUser() async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/me'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw ApiException(_errorMessage(response, 'Session expired'));
    }
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteAccount() async {
    final response = await _client.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/account'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response, 'Could not delete account'));
    }
  }

  Future<List<UnitSummary>> fetchManifest() async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/curriculum/manifest'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load manifest');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['units'] as List)
        .map((u) => UnitSummary.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  Future<List<LessonSummary>> fetchLessons(String unitId) async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/curriculum/units/$unitId/lessons'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load lessons');
    return (jsonDecode(resp.body) as List)
        .map((l) => LessonSummary.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<List<LessonSummary>> fetchRoad() async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/curriculum/road'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load lesson road');
    return (jsonDecode(resp.body) as List)
        .map((l) => LessonSummary.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  Future<LessonDocument> fetchLesson(String lessonId) async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/curriculum/lessons/$lessonId'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load lesson');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    for (final rawStep in data['steps'] as List? ?? const []) {
      final step = rawStep as Map<String, dynamic>;
      _absolutizeAudio(step['audio'] as Map<String, dynamic>?);
      for (final rawOption in step['options'] as List? ?? const []) {
        final option = rawOption as Map<String, dynamic>;
        _absolutizeAudio(option['audio'] as Map<String, dynamic>?);
      }
    }
    return LessonDocument.fromJson(data);
  }

  Future<AttemptResult> submitAttempt({
    required String lessonId,
    required String exerciseId,
    required String skill,
    required Map<String, dynamic> response,
    String? idempotencyKey,
  }) async {
    final resp = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/attempts'),
      headers: _headers,
      body: jsonEncode({
        'lesson_id': lessonId,
        'exercise_id': exerciseId,
        'skill': skill,
        'response': response,
        if (idempotencyKey != null) ...{'idempotency_key': idempotencyKey},
      }),
    );
    if (resp.statusCode != 200) throw Exception('Failed to submit attempt');
    return AttemptResult.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<ProgressData> fetchProgress() async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/progress'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load progress');
    return ProgressData.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<SkillProgress>> fetchSkills() async {
    final resp = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/skills'),
      headers: _headers,
    );
    if (resp.statusCode != 200) throw Exception('Failed to load skills');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['skills'] as List)
        .map((s) => SkillProgress.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  Future<ConversationSession> createConversation({
    required String scenarioId,
    List<String> targetVocab = const [],
  }) async {
    final resp = await _client.post(
      Uri.parse('${AppConfig.apiBaseUrl}/speech/conversations'),
      headers: _headers,
      body: jsonEncode({
        'scenario_id': scenarioId,
        'target_vocab': targetVocab,
      }),
    );
    if (resp.statusCode != 200) {
      throw Exception('Failed to create conversation');
    }
    return ConversationSession.fromJson(
      jsonDecode(resp.body) as Map<String, dynamic>,
    );
  }

  Future<String?> assessSpeech({
    required List<int> pcmBytes,
    required String expectedText,
    required String expectedJyutping,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('${AppConfig.apiBaseUrl}/speech/drills/assess'),
          )
          ..headers.addAll(_authorizationHeaders)
          ..fields['expected_text'] = expectedText
          ..fields['expected_jyutping'] = expectedJyutping
          ..files.add(
            http.MultipartFile.fromBytes(
              'audio',
              pcmBytes,
              filename: 'practice.pcm',
            ),
          );
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode != 200) {
      throw Exception('Speech assessment failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final transcript = data['transcript'] as String? ?? '';
    return transcript.isEmpty ? null : transcript;
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final detail = data['detail'] ?? data['message'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map && first['msg'] is String) {
            return first['msg'] as String;
          }
        }
      }
    } catch (_) {
      // The fallback is clearer than a JSON parsing error.
    }
    return fallback;
  }

  void _absolutizeAudio(Map<String, dynamic>? audio) {
    final url = audio?['url'] as String?;
    if (url != null && url.startsWith('/')) {
      audio!['url'] = '${AppConfig.apiBaseUrl}$url';
    }
  }
}

class AuthUser {
  const AuthUser({required this.id, required this.username});

  final dynamic id;
  final String username;

  factory AuthUser.fromJson(Map<String, dynamic> json) =>
      AuthUser(id: json['id'], username: json['username'] as String);
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final AuthUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['access_token'] as String,
    tokenType: json['token_type'] as String,
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
