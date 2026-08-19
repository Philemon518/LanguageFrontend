import 'package:canto_mobile/models/curriculum.dart';
import 'package:canto_mobile/services/api_client.dart';
import 'package:canto_mobile/services/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('wrong answers are requeued until answered correctly', () async {
    final state = AppState(api: _RetryApiClient());

    await state.loadLesson('lesson-1');
    expect(state.currentStep?.id, 'step-1');
    expect(state.sessionStepTotal, 2);

    await state.submitCurrentStep({'selected_option_id': 'wrong'});
    expect(state.lastResult?.correct, isFalse);
    expect(state.sessionStepTotal, 3);
    expect(state.lessonComplete, isFalse);

    state.nextStep();
    expect(state.currentStep?.id, 'step-2');
    await state.submitCurrentStep({'selected_option_id': 'correct'});
    state.nextStep();

    expect(state.currentStep?.id, 'step-1');
    await state.submitCurrentStep({'selected_option_id': 'correct'});
    expect(state.lessonComplete, isTrue);
  });
}

class _RetryApiClient extends ApiClient {
  int firstStepAttempts = 0;

  @override
  Future<LessonDocument> fetchLesson(String lessonId) async => LessonDocument(
    id: lessonId,
    unitId: 'unit-1',
    title: 'Test',
    lessonType: 'vocabulary',
    objectives: const [],
    steps: [
      ExerciseStep(
        id: 'step-1',
        type: 'select_meaning',
        skill: 'listening',
        prompt: 'One',
      ),
      ExerciseStep(
        id: 'step-2',
        type: 'select_meaning',
        skill: 'listening',
        prompt: 'Two',
      ),
    ],
  );

  @override
  Future<AttemptResult> submitAttempt({
    required String lessonId,
    required String exerciseId,
    required String skill,
    required Map<String, dynamic> response,
    String? idempotencyKey,
  }) async {
    final correct = exerciseId != 'step-1' || firstStepAttempts++ > 0;
    return AttemptResult(correct: correct, score: correct ? 1 : 0);
  }

  @override
  Future<List<SkillProgress>> fetchSkills() async => [];

  @override
  Future<List<LibraryWord>> fetchLibrary() async => [];
}
