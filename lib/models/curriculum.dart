class UnitSummary {
  final String id;
  final String title;
  final String phase;
  final int sortOrder;
  final int lessonCount;
  final List<String> prerequisites;

  UnitSummary({
    required this.id,
    required this.title,
    required this.phase,
    required this.sortOrder,
    required this.lessonCount,
    this.prerequisites = const [],
  });

  factory UnitSummary.fromJson(Map<String, dynamic> json) => UnitSummary(
    id: json['id'] as String,
    title: json['title'] as String,
    phase: json['phase'] as String,
    sortOrder: json['sort_order'] as int,
    lessonCount: json['lesson_count'] as int,
    prerequisites: List<String>.from(json['prerequisites'] ?? []),
  );
}

class LessonSummary {
  final String id;
  final String unitId;
  final String title;
  final String? targetTraditional;
  final String? targetEnglish;
  final String? theme;
  final int wordCount;
  final String lessonType;
  final int sortOrder;
  final int globalOrder;
  final int questionCount;
  final String phase;
  final bool completed;
  final int currentStep;
  final bool locked;

  LessonSummary({
    required this.id,
    required this.unitId,
    required this.title,
    this.targetTraditional,
    this.targetEnglish,
    this.theme,
    this.wordCount = 1,
    required this.lessonType,
    required this.sortOrder,
    this.globalOrder = 0,
    this.questionCount = 0,
    this.phase = 'sound',
    this.completed = false,
    this.currentStep = 0,
    this.locked = true,
  });

  factory LessonSummary.fromJson(Map<String, dynamic> json) => LessonSummary(
    id: json['id'] as String,
    unitId: json['unit_id'] as String,
    title: json['title'] as String,
    targetTraditional: json['target_traditional'] as String?,
    targetEnglish: json['target_english'] as String?,
    theme: json['theme'] as String?,
    wordCount: json['word_count'] as int? ?? 1,
    lessonType: json['lesson_type'] as String,
    sortOrder: json['sort_order'] as int,
    globalOrder: json['global_order'] as int? ?? 0,
    questionCount: json['question_count'] as int? ?? 0,
    phase: json['phase'] as String? ?? 'sound',
    completed: json['completed'] as bool? ?? false,
    currentStep: json['current_step'] as int? ?? 0,
    locked: json['locked'] as bool? ?? true,
  );
}

class ExerciseStep {
  final String id;
  final String type;
  final String skill;
  final String prompt;
  final Map<String, dynamic>? audio;
  final List<Map<String, dynamic>> options;
  final String? correctOptionId;
  final String? revealJyutping;
  final String? revealCharacter;
  final String? revealEnglish;
  final String? hint;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> extra;

  ExerciseStep({
    required this.id,
    required this.type,
    required this.skill,
    required this.prompt,
    this.audio,
    this.options = const [],
    this.correctOptionId,
    this.revealJyutping,
    this.revealCharacter,
    this.revealEnglish,
    this.hint,
    this.metadata = const {},
    this.extra = const {},
  });

  factory ExerciseStep.fromJson(Map<String, dynamic> json) {
    const knownKeys = {
      'id',
      'type',
      'skill',
      'prompt',
      'audio',
      'options',
      'correct_option_id',
      'reveal_jyutping',
      'reveal_character',
      'reveal_english',
      'hint',
      'metadata',
    };
    return ExerciseStep(
      id: json['id'] as String,
      type: json['type'] as String,
      skill: json['skill'] as String,
      prompt: json['prompt'] as String,
      audio: json['audio'] is Map
          ? Map<String, dynamic>.from(json['audio'] as Map)
          : null,
      options: List<Map<String, dynamic>>.from(json['options'] ?? []),
      correctOptionId: json['correct_option_id'] as String?,
      revealJyutping: json['reveal_jyutping'] as String?,
      revealCharacter: json['reveal_character'] as String?,
      revealEnglish: json['reveal_english'] as String?,
      hint: json['hint'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      extra: Map<String, dynamic>.fromEntries(
        json.entries.where(
          (entry) =>
              !knownKeys.contains(entry.key) ||
              (entry.key == 'audio' && entry.value is! Map),
        ),
      ),
    );
  }

  String? get imageSource {
    for (final value in [
      extra['image'],
      extra['image_url'],
      extra['image_asset'],
      metadata['image'],
      metadata['image_url'],
      metadata['image_asset'],
    ]) {
      final source = _mediaSource(value);
      if (source != null) return source;
    }
    return null;
  }

  List<Map<String, dynamic>> get audioRefs {
    final refs = <Map<String, dynamic>>[];
    void add(dynamic value) {
      if (value is Map && value['url'] is String) {
        refs.add(Map<String, dynamic>.from(value));
      } else if (value is List) {
        for (final item in value) {
          add(item);
        }
      }
    }

    add(audio);
    add(extra['audio']);
    for (final key in const [
      'audios',
      'audio_pair',
      'audio_refs',
      'audio_a',
      'audio_b',
      'audio_1',
      'audio_2',
      'first_audio',
      'second_audio',
    ]) {
      add(extra[key]);
      add(metadata[key]);
    }
    return refs;
  }

  List<String> collectAudioUrls() {
    final urls = <String>{};
    void collectNested(dynamic value) {
      if (value is List) {
        for (final item in value) {
          collectNested(item);
        }
      } else if (value is Map) {
        final url = value['url'];
        if (url is String && url.isNotEmpty) urls.add(url);
        for (final nested in value.values) {
          collectNested(nested);
        }
      }
    }

    for (final audioRef in audioRefs) {
      final url = audioRef['url'] as String?;
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    for (final option in options) {
      final optionUrl = (option['audio'] as Map?)?['url'] as String?;
      if (optionUrl != null && optionUrl.isNotEmpty) {
        urls.add(optionUrl);
      }
    }
    collectNested(metadata);
    collectNested(extra);
    return urls.toList();
  }

  static String? imageSourceForOption(Map<String, dynamic> option) {
    for (final value in [
      option['image'],
      option['image_url'],
      option['image_asset'],
    ]) {
      final source = _mediaSource(value);
      if (source != null) return source;
    }
    return null;
  }

  static String? _mediaSource(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Map) {
      for (final key in const ['url', 'asset', 'asset_path', 'path']) {
        final nested = value[key];
        if (nested is String && nested.trim().isNotEmpty) return nested.trim();
      }
    }
    return null;
  }
}

class LessonDocument {
  final String id;
  final String unitId;
  final String title;
  final String lessonType;
  final List<String> objectives;
  final List<ExerciseStep> steps;
  final List<Map<String, dynamic>> vocabulary;
  final List<Map<String, dynamic>> grammarPoints;
  final Map<String, dynamic>? lessonIntro;

  LessonDocument({
    required this.id,
    required this.unitId,
    required this.title,
    required this.lessonType,
    required this.objectives,
    required this.steps,
    this.vocabulary = const [],
    this.grammarPoints = const [],
    this.lessonIntro,
  });

  factory LessonDocument.fromJson(Map<String, dynamic> json) => LessonDocument(
    id: json['id'] as String,
    unitId: json['unit_id'] as String,
    title: json['title'] as String,
    lessonType: json['lesson_type'] as String,
    objectives: List<String>.from(json['objectives'] ?? []),
    steps: (json['steps'] as List)
        .map((s) => ExerciseStep.fromJson(s as Map<String, dynamic>))
        .toList(),
    vocabulary: List<Map<String, dynamic>>.from(json['vocabulary'] ?? []),
    grammarPoints: List<Map<String, dynamic>>.from(
      json['grammar_points'] ?? [],
    ),
    lessonIntro: json['lesson_intro'] is Map
        ? Map<String, dynamic>.from(json['lesson_intro'] as Map)
        : null,
  );

  List<String> collectAudioUrls() {
    final urls = <String>{};
    for (final step in steps) {
      urls.addAll(step.collectAudioUrls());
    }
    return urls.toList();
  }

  List<String> collectAudioUrlsForStep(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= steps.length) {
      return const [];
    }
    return steps[stepIndex].collectAudioUrls();
  }
}

class AttemptResult {
  final bool correct;
  final double score;
  final String? feedback;
  final Map<String, double> masteryDelta;
  final bool skillPointAwarded;

  AttemptResult({
    required this.correct,
    required this.score,
    this.feedback,
    this.masteryDelta = const {},
    this.skillPointAwarded = false,
  });

  factory AttemptResult.fromJson(Map<String, dynamic> json) => AttemptResult(
    correct: json['correct'] as bool,
    score: (json['score'] as num).toDouble(),
    feedback: json['feedback'] as String?,
    masteryDelta: Map<String, double>.from(
      (json['mastery_delta'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ) ??
          {},
    ),
    skillPointAwarded: json['skill_point_awarded'] as bool? ?? false,
  );
}

class SkillProgress {
  final String skill;
  final int completed;
  final int total;
  final double percentage;

  const SkillProgress({
    required this.skill,
    required this.completed,
    required this.total,
    required this.percentage,
  });

  factory SkillProgress.fromJson(Map<String, dynamic> json) => SkillProgress(
    skill: json['skill'] as String,
    completed: json['completed'] as int,
    total: json['total'] as int,
    percentage: (json['percentage'] as num).toDouble(),
  );
}

class LibraryWord {
  final String lexemeId;
  final String traditional;
  final String jyutping;
  final int tone;
  final String english;
  final String? wordType;
  final String? components;
  final String phase;
  final String lessonId;
  final String lessonTitle;
  final String lessonType;
  final String? encounteredAt;
  final String? audioUrl;
  final String? contextTraditional;
  final String? contextJyutping;
  final String? contextEnglish;

  const LibraryWord({
    required this.lexemeId,
    required this.traditional,
    required this.jyutping,
    required this.tone,
    required this.english,
    required this.phase,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonType,
    this.wordType,
    this.components,
    this.encounteredAt,
    this.audioUrl,
    this.contextTraditional,
    this.contextJyutping,
    this.contextEnglish,
  });

  factory LibraryWord.fromJson(Map<String, dynamic> json) => LibraryWord(
    lexemeId: json['lexeme_id'] as String,
    traditional: json['traditional'] as String,
    jyutping: json['jyutping'] as String,
    tone: json['tone'] as int,
    english: json['english'] as String,
    wordType: json['word_type'] as String?,
    components: json['components'] as String?,
    phase: json['phase'] as String,
    lessonId: json['lesson_id'] as String,
    lessonTitle: json['lesson_title'] as String,
    lessonType: json['lesson_type'] as String,
    encounteredAt: json['encountered_at'] as String?,
    audioUrl: json['audio_url'] as String?,
    contextTraditional: json['context_traditional'] as String?,
    contextJyutping: json['context_jyutping'] as String?,
    contextEnglish: json['context_english'] as String?,
  );
}

class ProgressData {
  final String level;
  final int streakDays;
  final int totalXp;
  final int lessonsCompleted;
  final List<Map<String, dynamic>> mastery;
  final List<String> reviewQueue;

  ProgressData({
    required this.level,
    required this.streakDays,
    required this.totalXp,
    required this.lessonsCompleted,
    this.mastery = const [],
    this.reviewQueue = const [],
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) => ProgressData(
    level: json['level'] as String,
    streakDays: json['streak_days'] as int,
    totalXp: json['total_xp'] as int,
    lessonsCompleted: json['lessons_completed'] as int,
    mastery: List<Map<String, dynamic>>.from(json['mastery'] ?? []),
    reviewQueue: List<String>.from(json['review_queue'] ?? []),
  );
}

class ConversationSession {
  final String id;
  final String scenarioId;
  final List<String> targetVocab;
  final String wsUrl;
  final String instructions;

  ConversationSession({
    required this.id,
    required this.scenarioId,
    required this.targetVocab,
    required this.wsUrl,
    required this.instructions,
  });

  factory ConversationSession.fromJson(Map<String, dynamic> json) =>
      ConversationSession(
        id: json['id'] as String,
        scenarioId: json['scenario_id'] as String,
        targetVocab: List<String>.from(json['target_vocab'] ?? []),
        wsUrl: json['ws_url'] as String,
        instructions: json['instructions'] as String,
      );
}
