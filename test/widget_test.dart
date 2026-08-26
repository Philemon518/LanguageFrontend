import 'package:canto_mobile/features/auth/auth_screen.dart';
import 'package:canto_mobile/features/lesson/lesson_screen.dart';
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
      audio: const {'url': 'https://example.com/sentence.wav'},
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
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    await tester.tap(find.text('水'));
    expect(response, {'selected_option_id': 'water'});

    await tester.tap(find.text('TYPE INSTEAD'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('same/different exercise renders two audio controls', (
    tester,
  ) async {
    final step = ExerciseStep.fromJson({
      'id': 'same-1',
      'type': 'same_different',
      'skill': 'listening',
      'prompt': 'Do these sound the same?',
      'audio_a': {'url': 'https://example.com/a.wav'},
      'audio_b': {'url': 'https://example.com/b.wav'},
      'options': [
        {'id': 'same', 'label': 'Same'},
        {'id': 'different', 'label': 'Different'},
      ],
    });

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

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2));
  });

  testWidgets('exercise lesson intro renders goals and vocabulary', (
    tester,
  ) async {
    final step = ExerciseStep(
      id: 'intro',
      type: 'lesson_intro',
      skill: 'listening',
      prompt: 'Level tones',
      metadata: const {
        'lesson_intro': {
          'summary': 'Train your ear before reading.',
          'learning_goals': ['Hear pitch movement'],
          'new_items': [
            {'traditional': '詩', 'jyutping': 'si1', 'english': 'poem'},
          ],
          'review_items': [],
        },
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

    expect(
      find.byKey(const Key('exerciseLessonIntroScrollView')),
      findsOneWidget,
    );
    expect(find.text('Train your ear before reading.'), findsOneWidget);
    expect(find.text('Hear pitch movement'), findsOneWidget);
    expect(find.text('詩'), findsOneWidget);
    expect(find.text('si1'), findsOneWidget);
  });

  testWidgets('character typing preserves Chinese input', (tester) async {
    final step = ExerciseStep(
      id: 'character-1',
      type: 'type_character',
      skill: 'writing',
      prompt: 'Type the character for water',
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

    await tester.enterText(find.byType(TextField), '水');
    expect(response, {'text': '水', 'answer': '水'});
    expect(find.text('水'), findsOneWidget);
  });

  testWidgets('lesson intro scrolls before the first exercise', (tester) async {
    final api = _FakeApiClient()
      ..lessonDocument = LessonDocument(
        id: 'lesson-with-intro',
        unitId: 'unit-0',
        title: 'Cantonese numbers',
        lessonType: 'sound',
        objectives: const ['Recognize number gestures'],
        lessonIntro: const {
          'title': 'Welcome to numbers',
          'description': 'A visual and listening introduction.',
          'sections': [
            {
              'heading': 'Use your hands',
              'body': 'Number gestures help people communicate clearly.',
            },
          ],
        },
        steps: [
          ExerciseStep(
            id: 'first',
            type: 'select_meaning',
            skill: 'listening',
            prompt: 'Choose one',
            options: [
              {'id': 'one', 'label': 'One'},
            ],
          ),
        ],
      );
    final state = AppState(api: api);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const MaterialApp(
          home: LessonScreen(lessonId: 'lesson-with-intro'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lessonIntroScrollView')), findsOneWidget);
    expect(find.text('Welcome to numbers'), findsOneWidget);
    expect(find.text('USE YOUR HANDS'), findsOneWidget);
    expect(find.text('Choose one'), findsNothing);

    await tester.tap(find.text('START LESSON'));
    await tester.pump();
    expect(find.text('Choose one'), findsOneWidget);
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
        'word_type': 'word',
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
    expect(find.text('word'), findsOneWidget);
    expect(find.text('水 radical · pictograph'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
  });

  testWidgets('component introduction shows character parts metadata', (
    tester,
  ) async {
    final step = ExerciseStep(
      id: 'intro-component',
      type: 'word_intro',
      skill: 'reading',
      prompt: 'Meet this character and its parts',
      audio: const {'text': '休'},
      revealCharacter: '休',
      revealJyutping: 'jau1',
      metadata: const {
        'character': '休',
        'pronunciation': 'jau',
        'jyutping': 'jau1',
        'tone_label': 'Tone 1 · high level',
        'meaning': 'rest',
        'word_type': 'character',
        'components_label': '亻 (semantic) · 木 (semantic)',
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

    expect(find.text('character'), findsOneWidget);
    expect(find.text('亻 (semantic) · 木 (semantic)'), findsOneWidget);
  });

  testWidgets('vocabulary introduction shows phrase metadata', (tester) async {
    final step = ExerciseStep(
      id: 'intro-vocab',
      type: 'word_intro',
      skill: 'reading',
      prompt: 'Meet this phrase',
      audio: const {'text': '你好'},
      revealCharacter: '你好',
      revealJyutping: 'nei5 hou2',
      metadata: const {
        'character': '你好',
        'pronunciation': 'nei hou',
        'jyutping': 'nei5 hou2',
        'tone_label': 'Tone 2 · rising',
        'meaning': 'hello',
        'word_type': 'phrase',
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

    expect(find.text('phrase'), findsOneWidget);
    expect(find.text('hello'), findsWidgets);
  });

  testWidgets('grammar introduction shows pattern focus token', (tester) async {
    final step = ExerciseStep(
      id: 'intro-grammar',
      type: 'word_intro',
      skill: 'reading',
      prompt: 'Meet this sentence pattern',
      audio: const {'text': '我係學生'},
      revealCharacter: '我係學生',
      revealJyutping: 'ngo5 hai6 hok6 saang1',
      metadata: const {
        'character': '我係學生',
        'pronunciation': 'ngo hai hok saang',
        'jyutping': 'ngo5 hai6 hok6 saang1',
        'meaning': 'I am a student',
        'word_type': 'pattern',
        'focus_token': '係',
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

    expect(find.text('pattern'), findsOneWidget);
    expect(find.text('係'), findsOneWidget);
  });
}

class _FakeApiClient extends ApiClient {
  bool accountDeleted = false;
  LessonDocument? lessonDocument;

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

  @override
  Future<LessonDocument> fetchLesson(String lessonId) async =>
      lessonDocument ?? (throw StateError('No fake lesson configured'));

  AuthSession _session(String username) => AuthSession(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: AuthUser(id: 1, username: username),
  );
}
