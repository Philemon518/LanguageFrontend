import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../models/curriculum.dart';
import '../../services/app_state.dart';
import '../../services/audio_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final words = state.libraryWords;

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Library')),
      body: SafeArea(
        child: words.isEmpty && state.loading
            ? const Center(child: CircularProgressIndicator())
            : words.isEmpty
            ? _EmptyLibrary(onRefresh: state.refreshLibrary)
            : RefreshIndicator(
                onRefresh: state.refreshLibrary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  children: [
                    Text(
                      'Your word bank',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${words.length} word${words.length == 1 ? '' : 's'} collected from lessons you have started.',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...words.map((word) => _WordCard(word: word)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 72,
              color: AppTheme.purple.withValues(alpha: .55),
            ),
            const SizedBox(height: 16),
            Text('No words yet', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Start a lesson on the Learn tab. Every new word you meet will appear here for review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRefresh, child: const Text('REFRESH')),
          ],
        ),
      ),
    );
  }
}

class _WordCard extends StatefulWidget {
  const _WordCard({required this.word});

  final LibraryWord word;

  @override
  State<_WordCard> createState() => _WordCardState();
}

class _WordCardState extends State<_WordCard> {
  int audioTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final word = widget.word;
    final phaseColor = AppTheme.phaseColor(word.phase);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.phaseShadow(word.phase).withValues(alpha: .18),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: phaseColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    word.traditional,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.jyutping,
                        style: TextStyle(
                          color: phaseColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        word.english,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (word.wordType != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          word.wordType!,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (word.audioUrl != null)
                  IconButton.filled(
                    tooltip: 'Play pronunciation',
                    style: IconButton.styleFrom(
                      backgroundColor: phaseColor.withValues(alpha: .16),
                      foregroundColor: phaseColor,
                    ),
                    onPressed: () {
                      final speed = AudioService.manualSpeedForTap(
                        audioTapCount,
                      );
                      setState(() => audioTapCount++);
                      AudioService.instance.play(word.audioUrl, speed: speed);
                    },
                    icon: Icon(
                      audioTapCount.isEven
                          ? Icons.volume_up_rounded
                          : Icons.slow_motion_video_rounded,
                    ),
                  ),
              ],
            ),
            if (word.components != null) ...[
              const SizedBox(height: 12),
              Text(
                word.components!,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (word.contextTraditional != null &&
                word.contextTraditional!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      word.contextTraditional!,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (word.contextJyutping != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.contextJyutping!,
                        style: TextStyle(
                          color: phaseColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (word.contextEnglish != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        word.contextEnglish!,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _PhaseChip(label: word.phase, color: phaseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    word.lessonTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }
}
