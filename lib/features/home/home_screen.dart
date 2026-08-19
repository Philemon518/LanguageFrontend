import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../models/curriculum.dart';
import '../../services/app_state.dart';
import '../../widgets/lesson_node_3d.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? _ErrorState(message: state.error!, onRetry: state.loadHome)
          : RefreshIndicator(
              onRefresh: () => state.loadHome(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HomeHeader(
                      xp: state.progress?.totalXp ?? 0,
                      streak: state.progress?.streakDays ?? 0,
                      completed: state.progress?.lessonsCompleted ?? 0,
                    ),
                  ),
                  if (state.lessons.isEmpty)
                    SliverToBoxAdapter(
                      child: _EmptyRoadState(onRetry: state.loadHome),
                    ),
                  SliverList.builder(
                    itemCount: state.lessons.length,
                    itemBuilder: (context, index) {
                      final lesson = state.lessons[index];
                      final previous = index > 0
                          ? state.lessons[index - 1]
                          : null;
                      final startsPhase =
                          previous == null || previous.phase != lesson.phase;
                      final currentIndex = state.lessons.indexWhere(
                        (item) => !item.completed && !item.locked,
                      );
                      return Column(
                        children: [
                          if (startsPhase)
                            _PhaseBanner(
                              phase: lesson.phase,
                              number:
                                  state.units.indexWhere(
                                    (u) => u.id == lesson.unitId,
                                  ) +
                                  1,
                            ),
                          _RoadRow(
                            lesson: lesson,
                            index: index,
                            previous: previous,
                            isCurrent: index == currentIndex,
                            onTap: () => _showLessonCard(context, lesson),
                          ),
                        ],
                      );
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  void _showLessonCard(BuildContext context, LessonSummary lesson) {
    if (lesson.locked) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${lesson.questionCount} questions · ${_label(lesson.phase)}',
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _ChunkyButton(
              label: lesson.completed ? 'PRACTICE AGAIN' : 'START LESSON',
              color: AppTheme.phaseColor(lesson.phase),
              shadow: AppTheme.phaseShadow(lesson.phase),
              onTap: () {
                Navigator.pop(context);
                context.push('/lesson/${lesson.id}');
              },
            ),
          ],
        ),
      ),
    );
  }

  String _label(String phase) => switch (phase) {
    'sound' => 'Sound & tones',
    'components' => 'Characters',
    'vocabulary' => 'Vocabulary',
    'sentences' || 'grammar' => 'Sentences',
    _ => phase,
  };
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.xp,
    required this.streak,
    required this.completed,
  });

  final int xp;
  final int streak;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Canto',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                _StatPill(icon: Icons.local_fire_department, value: '$streak'),
                const SizedBox(width: 8),
                _StatPill(icon: Icons.bolt_rounded, value: '$xp'),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1CB0F6), Color(0xFF3DCCF5)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: AppTheme.blueDark, offset: Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.waves_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BEGINNER · UNIT 1',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const Text(
                          'Sounds → words → sentences',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          '$completed of 40 lessons complete',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppTheme.border, width: 2),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppTheme.orange, size: 20),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    ),
  );
}

class _PhaseBanner extends StatelessWidget {
  const _PhaseBanner({required this.phase, required this.number});
  final String phase;
  final int number;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.phaseColor(phase);
    final title = switch (phase) {
      'sound' => 'Hear the shape of Cantonese',
      'components' => 'Build characters from parts',
      'vocabulary' => 'Use words in real life',
      'sentences' || 'grammar' => 'Make meaning with sentences',
      _ => phase,
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            'PHASE $number',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadRow extends StatelessWidget {
  const _RoadRow({
    required this.lesson,
    required this.index,
    required this.previous,
    required this.isCurrent,
    required this.onTap,
  });

  final LessonSummary lesson;
  final LessonSummary? previous;
  final int index;
  final bool isCurrent;
  final VoidCallback onTap;

  double get offset => math.sin(index * math.pi / 2.5) * 92;

  @override
  Widget build(BuildContext context) {
    final previousOffset = index == 0
        ? 0.0
        : math.sin((index - 1) * math.pi / 2.5) * 92;
    return SizedBox(
      height: 116,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final center = constraints.maxWidth / 2;
          return Stack(
            children: [
              if (previous != null)
                CustomPaint(
                  size: Size(constraints.maxWidth, 116),
                  painter: _ConnectorPainter(
                    from: Offset(center + previousOffset, 0),
                    to: Offset(center + offset, 54),
                    active: previous!.completed,
                  ),
                ),
              Positioned(
                left: center + offset - 41,
                top: 16,
                child: Column(
                  children: [
                    LessonNode3D(
                      lesson: lesson,
                      isCurrent: isCurrent,
                      onTap: onTap,
                    ),
                    SizedBox(
                      width: 150,
                      child: Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: lesson.locked ? AppTheme.muted : AppTheme.ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.from,
    required this.to,
    required this.active,
  });
  final Offset from;
  final Offset to;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = active ? AppTheme.green : AppTheme.border
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..cubicTo(from.dx, 20, to.dx, 32, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) =>
      oldDelegate.from != from ||
      oldDelegate.to != to ||
      oldDelegate.active != active;
}

class _ChunkyButton extends StatefulWidget {
  const _ChunkyButton({
    required this.label,
    required this.color,
    required this.shadow,
    required this.onTap,
  });
  final String label;
  final Color color;
  final Color shadow;
  final VoidCallback onTap;

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => pressed = true),
    onTapCancel: () => setState(() => pressed = false),
    onTapUp: (_) {
      setState(() => pressed = false);
      widget.onTap();
    },
    child: SizedBox(
      height: 58,
      child: Stack(
        children: [
          Positioned.fill(
            top: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.shadow,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 80),
            top: pressed ? 6 : 0,
            left: 0,
            right: 0,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyRoadState extends StatelessWidget {
  const _EmptyRoadState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
    child: Column(
      children: [
        const Icon(Icons.route_rounded, size: 48, color: AppTheme.muted),
        const SizedBox(height: 12),
        const Text(
          'Lessons are still loading',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const Text(
          'The course path appears once the backend finishes importing the curriculum.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('REFRESH')),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('TRY AGAIN')),
        ],
      ),
    ),
  );
}
