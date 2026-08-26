import 'package:canto_mobile/models/curriculum.dart';
import 'package:canto_mobile/services/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ExerciseStep parses from JSON', () {
    final step = ExerciseStep.fromJson({
      'id': 's1',
      'type': 'select_tone',
      'skill': 'listening',
      'prompt': 'Which tone?',
      'options': [],
      'correct_option_id': 't2',
    });
    expect(step.id, 's1');
    expect(step.type, 'select_tone');
    expect(step.correctOptionId, 't2');
  });

  test('LessonDocument parses steps', () {
    final doc = LessonDocument.fromJson({
      'id': 'sound-01-water',
      'unit_id': 'unit-sound',
      'title': 'Water',
      'lesson_type': 'sound',
      'objectives': [],
      'steps': [
        {
          'id': 's1',
          'type': 'select_meaning',
          'skill': 'listening',
          'prompt': 'Listen',
          'options': [],
        },
      ],
    });
    expect(doc.steps.length, 1);
  });

  test('LessonDocument parses rich intro and exercise media', () {
    final doc = LessonDocument.fromJson({
      'id': 'numbers',
      'unit_id': 'unit-0',
      'title': 'Numbers',
      'lesson_type': 'sound',
      'objectives': ['Recognize hand gestures'],
      'lesson_intro': {
        'title': 'Meet Cantonese numbers',
        'sections': [
          {'heading': 'Notice', 'body': 'Gestures are commonly used.'},
        ],
      },
      'steps': [
        {
          'id': 'same-1',
          'type': 'same_different',
          'skill': 'listening',
          'prompt': 'Same or different?',
          'audio': {'url': '/media/a.wav'},
          'comparison': {
            'samples': [
              {
                'audio': {'url': '/media/a.wav'},
              },
              {
                'audio': {'url': '/media/b.wav'},
              },
            ],
          },
          'image_asset': 'assets/number_gestures/one.png',
          'options': [
            {
              'id': 'same',
              'label': 'Same',
              'image': {'asset': 'assets/number_gestures/two.png'},
            },
          ],
        },
      ],
    });

    expect(doc.lessonIntro?['title'], 'Meet Cantonese numbers');
    expect(doc.steps.single.audioRefs, hasLength(2));
    expect(doc.steps.single.collectAudioUrls(), [
      '/media/a.wav',
      '/media/b.wav',
    ]);
    expect(doc.steps.single.imageSource, 'assets/number_gestures/one.png');
    expect(
      ExerciseStep.imageSourceForOption(doc.steps.single.options.single),
      'assets/number_gestures/two.png',
    );
  });

  test('LessonSummary parses road state', () {
    final lesson = LessonSummary.fromJson({
      'id': 'v2-sound-01',
      'unit_id': 'v2-unit-sound',
      'title': 'Water',
      'lesson_type': 'sound',
      'sort_order': 1,
      'global_order': 0,
      'question_count': 8,
      'phase': 'sound',
      'locked': false,
    });
    expect(lesson.questionCount, 8);
    expect(lesson.locked, isFalse);
  });

  test('SkillProgress parses exact completion totals', () {
    final skill = SkillProgress.fromJson({
      'skill': 'listening',
      'completed': 23,
      'total': 92,
      'percentage': 25.0,
    });
    expect(skill.completed, 23);
    expect(skill.total, 92);
  });

  test('AuthSession parses backend authentication response', () {
    final session = AuthSession.fromJson({
      'access_token': 'jwt-token',
      'token_type': 'bearer',
      'user': {'id': 42, 'username': 'learner'},
    });

    expect(session.accessToken, 'jwt-token');
    expect(session.tokenType, 'bearer');
    expect(session.user.id, 42);
    expect(session.user.username, 'learner');
  });
}
