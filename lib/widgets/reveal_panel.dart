import 'package:flutter/material.dart';

import '../models/curriculum.dart';

class RevealPanel extends StatelessWidget {
  const RevealPanel({super.key, required this.step, this.result});
  final ExerciseStep step;
  final AttemptResult? result;

  @override
  Widget build(BuildContext context) {
    final correct = result?.correct ?? false;
    return Card(
      color: correct
          ? Colors.green.withValues(alpha: 0.1)
          : Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  correct ? Icons.check_circle : Icons.info_outline,
                  color: correct
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Text(
                  correct ? 'Correct!' : 'Keep practicing',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            if (result?.feedback != null) ...[
              const SizedBox(height: 8),
              Text(result!.feedback!),
            ],
            if (step.revealJyutping != null) ...[
              const SizedBox(height: 12),
              Text('Jyutping', style: Theme.of(context).textTheme.labelMedium),
              Text(step.revealJyutping!, style: const TextStyle(fontSize: 20)),
            ],
            if (step.revealCharacter != null) ...[
              const SizedBox(height: 8),
              Text('Character', style: Theme.of(context).textTheme.labelMedium),
              Text(step.revealCharacter!, style: const TextStyle(fontSize: 36)),
            ],
            if (step.revealEnglish != null) ...[
              const SizedBox(height: 8),
              Text(
                step.revealEnglish!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
