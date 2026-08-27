import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/curriculum.dart';
import '../../services/app_state.dart';
import '../../services/audio_service.dart';
import '../../core/config.dart';
import '../../widgets/question_stage.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lessonId});
  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  Map<String, dynamic>? response;
  bool checking = false;
  bool finished = false;
  bool introDismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadLesson(widget.lessonId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lesson = state.currentLesson;
    final step = state.currentStep;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : lesson == null
          ? Center(child: Text(state.error ?? 'Lesson not found'))
          : finished
          ? _CompletionView(
              correct: state.sessionCorrect,
              total: lesson.steps.length,
              mistakes: state.sessionMistakes.length,
              onDone: () async {
                await state.finishLesson();
                if (context.mounted) context.pop();
              },
            )
          : !introDismissed &&
              lesson.lessonIntro != null &&
              state.currentStepIndex == 0
          ? _LessonIntroView(
              lesson: lesson,
              onClose: () => context.pop(),
              onContinue: () => _dismissIntro(state),
            )
          : step == null
          ? Center(child: Text(state.error ?? 'Lesson has no exercises'))
          : SafeArea(
              child: Column(
                children: [
                  _LessonHeader(
                    current: state.sessionStepPosition - 1,
                    total: state.sessionStepTotal,
                    onClose: () => context.pop(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SkillChip(skill: step.skill),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                      child: QuestionStage(
                        key: ValueKey(step.id),
                        step: step,
                        disabled: state.lastResult != null || checking,
                        onResponseChanged: (value) {
                          setState(() => response = value);
                        },
                        onAssessSpeech: state.assessSpeech,
                      ),
                    ),
                  ),
                  _BottomTray(
                    result: state.lastResult,
                    step: step,
                    enabled: response != null && !checking,
                    checking: checking,
                    isLast: state.lessonComplete,
                    onPressed: () => _handleAction(state),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _dismissIntro(AppState state) async {
    if (state.currentStep?.type == 'lesson_intro') {
      await state.submitCurrentStep({'selected_option_id': 'intro-ready'});
      state.nextStep();
    }
    if (!mounted) return;
    setState(() => introDismissed = true);
  }

  Future<void> _handleAction(AppState state) async {
    final step = state.currentStep;
    if ((step?.type == 'word_intro' || step?.type == 'lesson_intro') &&
        state.lastResult == null) {
      setState(() => checking = true);
      await state.submitCurrentStep({'selected_option_id': 'intro-ready'});
      state.nextStep();
      if (!mounted) return;
      setState(() {
        response = null;
        checking = false;
      });
      return;
    }

    if (state.lastResult == null) {
      if (response == null) return;
      setState(() => checking = true);
      final result = await state.submitCurrentStep(response!);
      if (result != null) {
        unawaited(AudioService.instance.playFeedback(correct: result.correct));
      }
      if (mounted) setState(() => checking = false);
      return;
    }
    if (state.lessonComplete) {
      setState(() => finished = true);
      return;
    }
    state.nextStep();
    setState(() {
      response = null;
      checking = false;
    });
  }
}

class _LessonIntroView extends StatelessWidget {
  const _LessonIntroView({
    required this.lesson,
    required this.onClose,
    required this.onContinue,
  });

  final LessonDocument lesson;
  final VoidCallback onClose;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final intro = lesson.lessonIntro!;
    final title = _text(intro['title']) ?? lesson.title;
    final subtitle =
        _text(intro['subtitle']) ??
        _text(intro['description']) ??
        _text(intro['body']);
    final image = _mediaSource(
      intro['image'] ?? intro['image_url'] ?? intro['image_asset'],
    );
    final sections = intro['sections'] is List
        ? intro['sections'] as List
        : const <dynamic>[];
    final objectives = intro['objectives'] is List
        ? intro['objectives'] as List
        : lesson.objectives;

    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, color: AppTheme.muted),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const Key('lessonIntroScrollView'),
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 17,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (image != null) ...[
                    const SizedBox(height: 22),
                    _LessonIntroImage(source: image),
                  ],
                  if (objectives.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _IntroHeading('WHAT YOU’LL LEARN'),
                    const SizedBox(height: 8),
                    ...objectives.map(
                      (objective) => _IntroBullet(text: objective.toString()),
                    ),
                  ],
                  ...sections.expand(
                    (raw) => [
                      const SizedBox(height: 20),
                      _IntroSection(data: raw),
                    ],
                  ),
                  if (intro['tips'] is List) ...[
                    const SizedBox(height: 20),
                    const _IntroHeading('TIPS'),
                    const SizedBox(height: 8),
                    ...(intro['tips'] as List).map(
                      (tip) => _IntroBullet(text: tip.toString()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            child: _LessonButton(
              label: 'START LESSON',
              color: AppTheme.green,
              shadow: AppTheme.greenDark,
              enabled: true,
              onTap: onContinue,
            ),
          ),
        ],
      ),
    );
  }

  static String? _text(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static String? _mediaSource(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      for (final key in const ['url', 'asset', 'asset_path', 'path']) {
        final source = value[key];
        if (source is String && source.isNotEmpty) return source;
      }
    }
    return null;
  }
}

class _IntroHeading extends StatelessWidget {
  const _IntroHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.blue,
      fontWeight: FontWeight.w900,
      letterSpacing: .8,
      fontSize: 12,
    ),
  );
}

class _IntroBullet extends StatelessWidget {
  const _IntroBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_circle_rounded,
            color: AppTheme.green,
            size: 19,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

class _IntroSection extends StatelessWidget {
  const _IntroSection({required this.data});
  final dynamic data;

  @override
  Widget build(BuildContext context) {
    if (data is String) return _IntroBullet(text: data as String);
    if (data is! Map) return const SizedBox.shrink();
    final map = data as Map;
    final heading =
        map['title']?.toString() ??
        map['heading']?.toString() ??
        map['label']?.toString();
    final body = map['body'] ?? map['text'] ?? map['description'];
    final items = map['items'] is List ? map['items'] as List : const [];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) _IntroHeading(heading.toUpperCase()),
          if (heading != null && body != null) const SizedBox(height: 7),
          if (body != null)
            Text(
              body.toString(),
              style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 9),
            ...items.map((item) => _IntroBullet(text: item.toString())),
          ],
        ],
      ),
    );
  }
}

class _LessonIntroImage extends StatelessWidget {
  const _LessonIntroImage({required this.source});
  final String source;

  @override
  Widget build(BuildContext context) {
    final normalized = source.startsWith('/') ? source.substring(1) : source;
    return SizedBox(
      height: 210,
      child: source.startsWith('http://') || source.startsWith('https://')
          ? Image.network(source, fit: BoxFit.contain)
          : Image.asset(normalized, fit: BoxFit.contain),
    );
  }
}

class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.skill});
  final String skill;

  @override
  Widget build(BuildContext context) {
    final icons = {
      'listening': Icons.hearing,
      'speaking': Icons.mic,
      'reading': Icons.menu_book,
      'writing': Icons.edit,
    };
    return Chip(
      backgroundColor: const Color(0xFFF1F1F1),
      side: BorderSide.none,
      avatar: Icon(icons[skill] ?? Icons.school, size: 18),
      label: Text(
        skill.toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({
    required this.current,
    required this.total,
    required this.onClose,
  });
  final int current;
  final int total;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 18, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: AppTheme.muted),
        ),
        Expanded(
          child: Row(
            children: List.generate(
              total,
              (index) => Expanded(
                child: Container(
                  height: 10,
                  margin: EdgeInsets.only(right: index == total - 1 ? 0 : 4),
                  decoration: BoxDecoration(
                    color: index <= current ? AppTheme.green : AppTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${current + 1}/$total',
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _BottomTray extends StatelessWidget {
  const _BottomTray({
    required this.result,
    required this.step,
    required this.enabled,
    required this.checking,
    required this.isLast,
    required this.onPressed,
  });
  final AttemptResult? result;
  final ExerciseStep step;
  final bool enabled;
  final bool checking;
  final bool isLast;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final correct = result?.correct == true;
    final isIntro = step.type == 'word_intro' || step.type == 'lesson_intro';
    final color = result == null
        ? AppTheme.green
        : correct
        ? AppTheme.green
        : AppTheme.red;
    final shadow = result == null || correct
        ? AppTheme.greenDark
        : const Color(0xFFC93B3B);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: result == null
            ? Colors.white
            : correct
            ? const Color(0xFFEAF8D8)
            : const Color(0xFFFFE5E5),
        border: const Border(top: BorderSide(color: AppTheme.border, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (result != null) ...[
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 28,
                ),
                const SizedBox(width: 9),
                Text(
                  correct ? 'Excellent!' : 'Good try!',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              result!.feedback ??
                  _answerReveal(step) ??
                  (correct ? 'You got it.' : 'Review the answer and continue.'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _LessonButton(
            label: result == null
                ? checking
                      ? 'CHECKING…'
                      : isIntro
                      ? 'CONTINUE'
                      : 'CHECK'
                : isLast
                ? 'FINISH'
                : 'CONTINUE',
            color: color,
            shadow: shadow,
            enabled: result != null || enabled || isIntro,
            onTap: onPressed,
          ),
        ],
      ),
    );
  }

  String? _answerReveal(ExerciseStep step) {
    final parts = [
      step.revealCharacter,
      step.revealJyutping,
      step.revealEnglish,
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

class _LessonButton extends StatelessWidget {
  const _LessonButton({
    required this.label,
    required this.color,
    required this.shadow,
    required this.enabled,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color shadow;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 55,
    child: Stack(
      children: [
        Positioned.fill(
          top: 5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: enabled ? shadow : const Color(0xFFB7B7B7),
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        Positioned.fill(
          bottom: 5,
          child: Material(
            color: enabled ? color : AppTheme.border,
            borderRadius: BorderRadius.circular(15),
            child: InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(15),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: enabled ? Colors.white : AppTheme.muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CompletionView extends StatelessWidget {
  const _CompletionView({
    required this.correct,
    required this.total,
    required this.mistakes,
    required this.onDone,
  });
  final int correct;
  final int total;
  final int mistakes;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final accuracy = total == 0 ? 0 : (correct / total * 100).round();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 132,
              height: 132,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF8D8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                size: 76,
                color: AppTheme.orange,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Lesson complete!',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Cantonese path just moved forward.',
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: _ResultCard(
                    label: 'ACCURACY',
                    value: '$accuracy%',
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ResultCard(
                    label: 'MISTAKES',
                    value: '$mistakes',
                    color: AppTheme.red,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _LessonButton(
              label: 'BACK TO ROAD',
              color: AppTheme.green,
              shadow: AppTheme.greenDark,
              enabled: true,
              onTap: onDone,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: color, width: 2),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}
