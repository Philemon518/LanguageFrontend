import 'package:canto_mobile/features/auth/auth_screen.dart';
import 'package:canto_mobile/features/progress/progress_screen.dart';
import 'package:canto_mobile/models/curriculum.dart';
import 'package:canto_mobile/services/api_client.dart';
import 'package:canto_mobile/services/app_state.dart';
import 'package:canto_mobile/widgets/lesson_node_3d.dart';
import 'package:canto_mobile/widgets/question_stage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('authentication form validates and switches account mode', (
    tester,
  ) async {
    final state = AppState(api: _FakeApiClient());
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: AuthScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();
    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.tap(find.text('CREATE NEW ACCOUNT'));
    await tester.pump();
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('usernameField')), 'learner');
    await tester.enterText(find.byKey(const Key('passwordField')), 'secret123');
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();
    expect(state.isAuthenticated, isTrue);
    expect(state.user?.username, 'learner');
  });

  testWidgets('delete account requires explicit confirmation', (tester) async {
    final api = _FakeApiClient();
    final state = AppState(api: api);
    await state.authenticate(
      username: 'learner',
      password: 'secret123',
      createAccount: false,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(home: ProgressScreen(embedded: true)),
      ),
    );
    await tester.pump();

    final deleteButton = find.byKey(const Key('deleteAccountButton'));
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Delete account?'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.accountDeleted, isFalse);

    await tester.tap(deleteButton);
    await tester.pump(const Duration(milliseconds: 300));
    final dialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('DELETE ACCOUNT')),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.accountDeleted, isTrue);
    expect(state.isAuthenticated, isFalse);
  });

  testWidgets('QuestionStage selects an answer before checking', (
    tester,
  ) async {
    final step = ExerciseStep(
      id: 's1',
      type: 'select_meaning',
      skill: 'listening',
      prompt: 'Listen. What does this mean?',
      options: [
        {'id': 'a', 'label': 'water'},
        {'id': 'b', 'label': 'fire'},
      ],
    );
    Map<String, dynamic>? response;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: QuestionStage(
              step: step,
              onResponseChanged: (value) => response = value,
              onAssessSpeech: (_, _, _) async => null,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Listen. What does this mean?'), findsOneWidget);
    expect(find.text('water'), findsOneWidget);
    await tester.tap(find.text('water'));
    expect(response, {'selected_option_id': 'a'});
  });

  testWidgets('beginner cloze shows English choices and optional typing', (
    tester,
  ) async {
    final step = ExerciseStep(
      id: 'cloze-1',
      type: 'cloze',
      skill: 'writing',
      prompt: 'Complete the sentence: 我飲＿＿。',
      revealEnglish: 'I drink water.',
      options: const [
        {'id': 'water', 'label': '水'},
        {'id': 'tea', 'label': '茶'},
      ],
      metadata: const {'allow_manual_input': true},
    );
    Map<String, dynamic>? response;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: QuestionStage(
              step: step,
              onResponseChanged: (value) => response = value,
              onAssessSpeech: (_, _, _) async => null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('I drink water.'), findsOneWidget);
    await tester.tap(find.text('水'));
    expect(response, {'selected_option_id': 'water'});

    await tester.tap(find.text('TYPE INSTEAD'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('3D lesson node exposes completed state', (tester) async {
    final lesson = LessonSummary(
      id: 'lesson-1',
      unitId: 'unit-1',
      title: 'Water',
      lessonType: 'sound',
      sortOrder: 1,
      completed: true,
      locked: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LessonNode3D(lesson: lesson, onTap: () {}),
        ),
      ),
    );
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('word introduction explains the word and animates audio', (
    tester,
  ) async {
    final step = ExerciseStep(
      id: 'intro',
      type: 'word_intro',
      skill: 'reading',
      prompt: 'Meet your first Cantonese word',
      audio: const {'text': '水'},
      revealCharacter: '水',
      revealJyutping: 'seoi2',
      metadata: const {
        'character': '水',
        'pronunciation': 'seoi',
        'jyutping': 'seoi2',
        'tone_label': 'Tone 2 · rising',
        'meaning': 'water',
        'word_type': 'noun',
        'components_label': '水 radical · pictograph',
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: QuestionStage(
              step: step,
              onResponseChanged: (_) {},
              onAssessSpeech: (_, _, _) async => null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tone 2 · rising'), findsOneWidget);
    expect(find.text('noun'), findsOneWidget);
    expect(find.text('水 radical · pictograph'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  bool accountDeleted = false;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => _session(username);

  @override
  Future<AuthSession> register({
    required String username,
    required String password,
  }) async => _session(username);

  @override
  Future<void> deleteAccount() async {
    accountDeleted = true;
  }

  AuthSession _session(String username) => AuthSession(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: AuthUser(id: 1, username: username),
  );
}
