import 'package:flutter/material.dart';

import '../models/curriculum.dart';

class ExerciseCard extends StatefulWidget {
  const ExerciseCard({super.key, required this.step, required this.onAnswer});
  final ExerciseStep step;
  final Future<void> Function(Map<String, dynamic> response) onAnswer;

  @override
  State<ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<ExerciseCard> {
  String? _selected;
  final _textController = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (step.audio?['text'] != null ||
                step.prompt.contains(RegExp(r'[\u4e00-\u9fff]')))
              _AudioPrompt(text: step.audio?['text'] as String? ?? step.prompt),
            const SizedBox(height: 16),
            Text(step.prompt, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            if (_isChoiceType(step.type)) ...[
              ...step.options.map((opt) {
                final id = opt['id'] as String;
                final label = opt['label'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () async {
                            setState(() {
                              _selected = id;
                              _submitting = true;
                            });
                            await widget.onAnswer({'selected_option_id': id});
                            setState(() => _submitting = false);
                          },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _selected == id
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(label, style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                );
              }),
            ] else if (step.type == 'order_words') ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: step.options.map((opt) {
                  return ActionChip(label: Text(opt['label'] as String));
                }).toList(),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onAnswer({
                          'order': step.options.map((o) => o['id']).toList(),
                        });
                        setState(() => _submitting = false);
                      },
                child: const Text('Check order'),
              ),
            ] else if (step.type == 'cloze' ||
                step.type == 'dictation' ||
                step.type == 'write_sentence') ...[
              TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: step.type == 'write_sentence'
                      ? 'Write in Cantonese characters...'
                      : 'Your answer',
                  border: const OutlineInputBorder(),
                ),
                maxLines: step.type == 'write_sentence' ? 3 : 1,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onAnswer({
                          'text': _textController.text,
                          'answer': _textController.text,
                        });
                        setState(() => _submitting = false);
                      },
                child: const Text('Submit'),
              ),
            ] else if (step.type == 'speak') ...[
              const Icon(Icons.mic, size: 48),
              const SizedBox(height: 8),
              Text('Tap record, then say: ${step.revealJyutping ?? ""}'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : () async {
                        setState(() => _submitting = true);
                        await widget.onAnswer({
                          'transcript':
                              step.revealJyutping ??
                              step.metadata['expected'] ??
                              '',
                        });
                        setState(() => _submitting = false);
                      },
                icon: const Icon(Icons.mic),
                label: const Text('Record (simulated)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isChoiceType(String type) {
    return [
      'select_tone',
      'select_meaning',
      'select_jyutping',
      'select_character',
      'match',
    ].contains(type);
  }
}

class _AudioPrompt extends StatelessWidget {
  const _AudioPrompt({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.volume_up,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text('Listen first', style: Theme.of(context).textTheme.labelLarge),
          if (text.contains(RegExp(r'[\u4e00-\u9fff]')))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(text, style: const TextStyle(fontSize: 28)),
            ),
        ],
      ),
    );
  }
}
