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
  });

  factory ExerciseStep.fromJson(Map<String, dynamic> json) => ExerciseStep(
    id: json['id'] as String,
    type: json['type'] as String,
    skill: json['skill'] as String,
    prompt: json['prompt'] as String,
    audio: json['audio'] as Map<String, dynamic>?,
    options: List<Map<String, dynamic>>.from(json['options'] ?? []),
    correctOptionId: json['correct_option_id'] as String?,
    revealJyutping: json['reveal_jyutping'] as String?,
    revealCharacter: json['reveal_character'] as String?,
    revealEnglish: json['reveal_english'] as String?,
    hint: json['hint'] as String?,
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
  );
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

  LessonDocument({
    required this.id,
    required this.unitId,
    required this.title,
    required this.lessonType,
    required this.objectives,
    required this.steps,
    this.vocabulary = const [],
    this.grammarPoints = const [],
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
  );
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
