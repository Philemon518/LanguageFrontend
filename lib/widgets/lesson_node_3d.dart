import 'package:flutter/material.dart';

import '../core/config.dart';
import '../models/curriculum.dart';

class LessonNode3D extends StatefulWidget {
  const LessonNode3D({
    super.key,
    required this.lesson,
    required this.onTap,
    this.isCurrent = false,
  });

  final LessonSummary lesson;
  final VoidCallback? onTap;
  final bool isCurrent;

  @override
  State<LessonNode3D> createState() => _LessonNode3DState();
}

class _LessonNode3DState extends State<LessonNode3D>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      lowerBound: 0.97,
      upperBound: 1.04,
      value: 1,
    );
    if (widget.isCurrent) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LessonNode3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isCurrent && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.lesson.locked;
    final completed = widget.lesson.completed;
    final face = locked
        ? const Color(0xFFE5E5E5)
        : completed
        ? AppTheme.green
        : AppTheme.phaseColor(widget.lesson.phase);
    final shadow = locked
        ? const Color(0xFFB7B7B7)
        : completed
        ? AppTheme.greenDark
        : AppTheme.phaseShadow(widget.lesson.phase);
    final icon = locked
        ? Icons.lock_rounded
        : completed
        ? Icons.check_rounded
        : _iconFor(widget.lesson.lessonType);

    final button = GestureDetector(
      onTapDown: locked ? null : (_) => setState(() => _pressed = true),
      onTapCancel: locked ? null : () => setState(() => _pressed = false),
      onTapUp: locked
          ? null
          : (_) {
              setState(() => _pressed = false);
              widget.onTap?.call();
            },
      child: SizedBox(
        width: 82,
        height: 76,
        child: Stack(
          children: [
            Positioned(
              top: 8,
              child: Container(
                width: 82,
                height: 64,
                decoration: BoxDecoration(
                  color: shadow,
                  borderRadius: BorderRadius.circular(34),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 90),
              curve: Curves.easeOut,
              top: _pressed ? 8 : 0,
              child: Container(
                width: 82,
                height: 64,
                decoration: BoxDecoration(
                  color: face,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .38),
                    width: 3,
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: 34),
              ),
            ),
          ],
        ),
      ),
    );

    return ScaleTransition(scale: _pulse, child: button);
  }

  IconData _iconFor(String type) => switch (type) {
    'sound' => Icons.graphic_eq_rounded,
    'component' => Icons.account_tree_rounded,
    'vocabulary' => Icons.chat_bubble_rounded,
    'grammar' => Icons.format_quote_rounded,
    _ => Icons.star_rounded,
  };
}
