import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/curriculum.dart';
import '../../services/app_state.dart';
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
          : lesson == null || step == null
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
          : SafeArea(
              child: Column(
                children: [
                  _LessonHeader(
                    current: state.currentStepIndex,
                    total: lesson.steps.length,
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

  Future<void> _handleAction(AppState state) async {
    final step = state.currentStep;
    if (step?.type == 'word_intro' && state.lastResult == null) {
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
      await state.submitCurrentStep(response!);
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
    final isIntro = step.type == 'word_intro';
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
