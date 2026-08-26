import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import '../models/curriculum.dart';

class AudioService {
  AudioService({http.Client? client, Random? feedbackRandom})
    : _client = client ?? http.Client(),
      _feedbackRandom = feedbackRandom ?? Random();

  static final AudioService instance = AudioService();

  static const correctFeedbackAssets = [
    'assets/sounds/correct_anime_wow.mp3',
    'assets/sounds/correct_apple_pay.mp3',
    'assets/sounds/correct_coin.mp3',
    'assets/sounds/correct_hehe.mp3',
  ];

  static const failFeedbackAssets = [
    'assets/sounds/fail_fortnite.mp3',
    'assets/sounds/fail_lego.mp3',
    'assets/sounds/fail_fah.mp3',
    'assets/sounds/fail_bone_crack.mp3',
  ];

  final http.Client _client;
  final Random _feedbackRandom;
  AudioPlayer? _player;
  AudioPlayer? _feedbackPlayer;
  final Map<String, Uint8List> _cache = {};
  final Map<String, Future<void>> _inFlight = {};
  String? _activeLessonId;

  AudioPlayer get _playerInstance => _player ??= AudioPlayer();
  AudioPlayer get _feedbackPlayerInstance => _feedbackPlayer ??= AudioPlayer();

  @visibleForTesting
  String pickFeedbackAsset(bool correct) {
    final pool = correct ? correctFeedbackAssets : failFeedbackAssets;
    return pool[_feedbackRandom.nextInt(pool.length)];
  }

  Future<void> playFeedback({required bool correct}) async {
    final asset = pickFeedbackAsset(correct);
    try {
      await _feedbackPlayerInstance.stop();
      await _feedbackPlayerInstance.setAudioSource(AudioSource.asset(asset));
      await _feedbackPlayerInstance.setSpeed(1.0);
      unawaited(_feedbackPlayerInstance.play());
    } catch (error, stackTrace) {
      debugPrint('Feedback audio failed for $asset: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> prepareLesson(
    LessonDocument lesson, {
    int priorityStepIndex = 0,
  }) async {
    if (_activeLessonId != lesson.id) {
      _cache.clear();
      _inFlight.clear();
      _activeLessonId = lesson.id;
    }

    final priority = lesson.collectAudioUrlsForStep(priorityStepIndex).toSet();
    final remaining = lesson
        .collectAudioUrls()
        .where((url) => !priority.contains(url))
        .toList();

    await prefetchUrls(priority.toList());
    unawaited(prefetchUrls(remaining));
  }

  Future<void> prefetchUrls(List<String> urls) async {
    await Future.wait(urls.map(_ensureCached));
  }

  Future<void> play(String? url, {double speed = 1.0}) async {
    if (url == null || url.isEmpty) return;
    try {
      await _ensureCached(url);
      final bytes = _cache[url];
      if (bytes == null || bytes.isEmpty) return;

      await _playerInstance.stop();
      await _playerInstance.setAudioSource(
        AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: _mimeTypeFor(url))),
      );
      await _playerInstance.setSpeed(speed);
      await _playerInstance.play();
    } catch (error, stackTrace) {
      debugPrint('Audio playback failed for $url: $error');
      debugPrint('$stackTrace');
    }
  }

  /// Manual controls alternate normal and learner-friendly slow playback.
  static double manualSpeedForTap(int tapIndex) => tapIndex.isEven ? 1.0 : 0.5;

  Future<void> _ensureCached(String url) async {
    if (_cache.containsKey(url)) return;
    final existing = _inFlight[url];
    if (existing != null) {
      await existing;
      return;
    }

    final load = _fetch(url);
    _inFlight[url] = load;
    try {
      await load;
    } finally {
      _inFlight.remove(url);
    }
  }

  Future<void> _fetch(String url) async {
    final response = await _client.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to cache audio ($url): HTTP ${response.statusCode}',
      );
    }
    _cache[url] = Uint8List.fromList(response.bodyBytes);
  }

  String _mimeTypeFor(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.mp3')) return 'audio/mpeg';
    if (lower.contains('.m4a')) return 'audio/mp4';
    return 'audio/wav';
  }

  Future<void> dispose() async {
    _client.close();
    await _player?.dispose();
    await _feedbackPlayer?.dispose();
    _player = null;
    _feedbackPlayer = null;
    _cache.clear();
    _inFlight.clear();
    _activeLessonId = null;
  }
}
