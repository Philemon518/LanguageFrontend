import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../services/api_client.dart';
import '../services/audio_service.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? api}) : _api = api ?? ApiClient();

  static const _tokenKey = 'auth_access_token';
  final ApiClient _api;
  bool authResolved = false;
  bool authLoading = false;
  String? authError;
  AuthUser? user;
  List<UnitSummary> units = [];
  List<LessonSummary> lessons = [];
  LessonDocument? currentLesson;
  ProgressData? progress;
  List<SkillProgress> skills = [];
  List<LibraryWord> libraryWords = [];
  int currentStepIndex = 0;
  final List<int> _stepQueue = [];
  int _queuePosition = 0;
  AttemptResult? lastResult;
  int sessionCorrect = 0;
  final List<String> sessionMistakes = [];
  bool loading = false;
  String? error;

  bool get isAuthenticated => user != null;

  Future<void> initializeAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      authResolved = true;
      notifyListeners();
      return;
    }

    _api.accessToken = token;
    try {
      user = await _api.fetchCurrentUser();
    } catch (_) {
      await prefs.remove(_tokenKey);
      _api.accessToken = null;
    } finally {
      authResolved = true;
      notifyListeners();
    }
  }

  Future<bool> authenticate({
    required String username,
    required String password,
    required bool createAccount,
  }) async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      final session = createAccount
          ? await _api.register(username: username, password: password)
          : await _api.login(username: username, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, session.accessToken);
      _api.accessToken = session.accessToken;
      user = session.user;
      return true;
    } catch (e) {
      authError = e.toString();
      return false;
    } finally {
      authLoading = false;
      authResolved = true;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _api.accessToken = null;
    _clearUserData();
    notifyListeners();
  }

  Future<bool> deleteAccount() async {
    authLoading = true;
    authError = null;
    notifyListeners();
    try {
      await _api.deleteAccount();
      await logout();
      return true;
    } catch (e) {
      authError = e.toString();
      return false;
    } finally {
      authLoading = false;
      notifyListeners();
    }
  }

  void clearAuthError() {
    if (authError == null) return;
    authError = null;
    notifyListeners();
  }

  void _clearUserData() {
    user = null;
    units = [];
    lessons = [];
    currentLesson = null;
    progress = null;
    skills = [];
    libraryWords = [];
    currentStepIndex = 0;
    _stepQueue.clear();
    _queuePosition = 0;
    lastResult = null;
    sessionCorrect = 0;
    sessionMistakes.clear();
    error = null;
  }

  Future<void> loadHome() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      units = await _api.fetchManifest();
      lessons = await _api.fetchRoad();
      try {
        progress = await _api.fetchProgress();
        skills = await _api.fetchSkills();
        libraryWords = await _api.fetchLibrary();
      } catch (_) {
        // Keep the road usable if progress is temporarily unavailable.
      }
      await _restoreLessonState();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadLesson(String lessonId) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      currentLesson = await _api.fetchLesson(lessonId);
      final summary = lessons.where((l) => l.id == lessonId).firstOrNull;
      currentStepIndex = summary?.completed == true
          ? 0
          : summary?.currentStep ?? 0;
      if (currentStepIndex >= currentLesson!.steps.length) {
        currentStepIndex = 0;
      }
      _stepQueue
        ..clear()
        ..addAll(
          List.generate(
            currentLesson!.steps.length - currentStepIndex,
            (index) => currentStepIndex + index,
          ),
        );
      _queuePosition = 0;
      sessionCorrect = 0;
      sessionMistakes.clear();
      lastResult = null;
      if (currentStepIndex >= (currentLesson?.steps.length ?? 0)) {
        currentStepIndex = 0;
      }
      await AudioService.instance.prepareLesson(
        currentLesson!,
        priorityStepIndex: currentStepIndex,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<AttemptResult?> submitCurrentStep(
    Map<String, dynamic> response,
  ) async {
    final lesson = currentLesson;
    if (lesson == null || currentStepIndex >= lesson.steps.length) return null;
    final step = lesson.steps[currentStepIndex];
    try {
      lastResult = await _api.submitAttempt(
        lessonId: lesson.id,
        exerciseId: step.id,
        skill: step.skill,
        response: response,
        idempotencyKey:
            '${lesson.id}-${step.id}-${DateTime.now().millisecondsSinceEpoch}',
      );
      await _saveLessonState();
      if (lastResult!.correct) {
        sessionCorrect++;
        if (lastResult!.skillPointAwarded) {
          skills = await _api.fetchSkills();
        }
        refreshLibrary();
      } else {
        _stepQueue.add(currentStepIndex);
        if (!sessionMistakes.contains(step.id)) {
          sessionMistakes.add(step.id);
        }
      }
      notifyListeners();
      return lastResult;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<void> refreshLibrary() async {
    try {
      libraryWords = await _api.fetchLibrary();
      notifyListeners();
    } catch (_) {}
  }

  void nextStep() {
    if (currentLesson != null && _queuePosition < _stepQueue.length - 1) {
      _queuePosition++;
      currentStepIndex = _stepQueue[_queuePosition];
      lastResult = null;
      _saveLessonState();
      notifyListeners();
    }
  }

  bool get lessonComplete =>
      currentLesson != null &&
      _stepQueue.isNotEmpty &&
      _queuePosition == _stepQueue.length - 1 &&
      lastResult?.correct == true;

  int get sessionStepPosition =>
      _stepQueue.isEmpty ? 0 : _queuePosition + 1;

  int get sessionStepTotal => _stepQueue.length;

  ExerciseStep? get currentStep {
    if (currentLesson == null ||
        currentStepIndex >= currentLesson!.steps.length) {
      return null;
    }
    return currentLesson!.steps[currentStepIndex];
  }

  Future<void> _saveLessonState() async {
    if (currentLesson == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lesson_${currentLesson!.id}_step', currentStepIndex);
  }

  Future<void> refreshProgress() async {
    try {
      progress = await _api.fetchProgress();
      skills = await _api.fetchSkills();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> finishLesson() async {
    await loadHome();
    await refreshLibrary();
  }

  Future<String?> assessSpeech(
    List<int> pcmBytes,
    String expectedText,
    String expectedJyutping,
  ) {
    return _api.assessSpeech(
      pcmBytes: pcmBytes,
      expectedText: expectedText,
      expectedJyutping: expectedJyutping,
    );
  }

  Future<ConversationSession> createConversation({required String scenarioId}) {
    return _api.createConversation(scenarioId: scenarioId);
  }

  Uri authenticatedWebSocketUri(String path) {
    return _api.authenticatedWebSocketUri(path);
  }

  Future<void> _restoreLessonState() async {
    final prefs = await SharedPreferences.getInstance();
    for (final lesson in lessons) {
      final step = prefs.getInt('lesson_${lesson.id}_step');
      if (step != null && step > lesson.currentStep) {
        // Local cache may be ahead if offline
      }
    }
  }
}
