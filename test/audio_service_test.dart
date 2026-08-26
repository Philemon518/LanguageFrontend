import 'dart:math';

import 'package:canto_mobile/models/curriculum.dart';
import 'package:canto_mobile/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ExerciseStep _step({
  String? stepAudioUrl,
  List<String> optionAudioUrls = const [],
}) {
  return ExerciseStep(
    id: 'step-1',
    type: 'select_meaning',
    skill: 'listening',
    prompt: 'Listen',
    audio: stepAudioUrl == null ? null : {'url': stepAudioUrl},
    options: [
      for (final url in optionAudioUrls)
        {
          'id': 'option-$url',
          'label': 'option',
          'audio': {'url': url},
        },
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('manual playback alternates normal and half speed', () {
    expect(AudioService.manualSpeedForTap(0), 1.0);
    expect(AudioService.manualSpeedForTap(1), 0.5);
    expect(AudioService.manualSpeedForTap(2), 1.0);
  });

  test('ExerciseStep collects step and option audio urls', () {
    final step = _step(
      stepAudioUrl: 'https://example.com/word.wav',
      optionAudioUrls: [
        'https://example.com/a.wav',
        'https://example.com/b.wav',
      ],
    );

    expect(step.collectAudioUrls(), [
      'https://example.com/word.wav',
      'https://example.com/a.wav',
      'https://example.com/b.wav',
    ]);
  });

  test('LessonDocument deduplicates audio urls across steps', () {
    final lesson = LessonDocument(
      id: 'lesson-1',
      unitId: 'unit-1',
      title: 'Water',
      lessonType: 'sound',
      objectives: const [],
      steps: [
        _step(stepAudioUrl: 'https://example.com/word.wav'),
        _step(
          stepAudioUrl: 'https://example.com/word.wav',
          optionAudioUrls: ['https://example.com/other.wav'],
        ),
      ],
    );

    expect(lesson.collectAudioUrls(), [
      'https://example.com/word.wav',
      'https://example.com/other.wav',
    ]);
    expect(lesson.collectAudioUrlsForStep(1), [
      'https://example.com/word.wav',
      'https://example.com/other.wav',
    ]);
  });

  test('pickFeedbackAsset chooses from the expected sound pool', () {
    final service = AudioService(feedbackRandom: Random(7));

    final correct = service.pickFeedbackAsset(true);
    final fail = service.pickFeedbackAsset(false);

    expect(AudioService.correctFeedbackAssets, contains(correct));
    expect(AudioService.failFeedbackAssets, contains(fail));
    expect(AudioService.correctFeedbackAssets, hasLength(4));
    expect(AudioService.failFeedbackAssets, hasLength(4));
  });

  test('AudioService caches lesson audio in memory', () async {
    var requestCount = 0;
    final client = MockClient((request) async {
      requestCount += 1;
      return http.Response.bytes(
        [0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00],
        200,
        headers: {'content-type': 'audio/wav'},
      );
    });
    final service = AudioService(client: client);
    const url = 'https://example.com/word.wav';

    await service.prefetchUrls([url]);
    await service.prefetchUrls([url]);

    expect(requestCount, 1);
  });
}
