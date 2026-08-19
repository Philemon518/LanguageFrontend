import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../core/config.dart';
import '../models/curriculum.dart';
import '../services/audio_service.dart';

typedef SpeechAssessor =
    Future<String?> Function(
      List<int> bytes,
      String expectedText,
      String expectedJyutping,
    );

class QuestionStage extends StatefulWidget {
  const QuestionStage({
    super.key,
    required this.step,
    required this.onResponseChanged,
    required this.onAssessSpeech,
    this.disabled = false,
  });

  final ExerciseStep step;
  final ValueChanged<Map<String, dynamic>?> onResponseChanged;
  final SpeechAssessor onAssessSpeech;
  final bool disabled;

  @override
  State<QuestionStage> createState() => _QuestionStageState();
}

class _QuestionStageState extends State<QuestionStage> {
  String? selected;
  final textController = TextEditingController();
  final ordered = <Map<String, dynamic>>[];
  final recorder = AudioRecorder();
  StreamSubscription<Uint8List>? recordingSubscription;
  final recordedBytes = <int>[];
  bool recording = false;
  bool assessing = false;
  bool manualInput = false;
  String? speechTranscript;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final url = widget.step.audio?['url'] as String?;
      if (url != null) AudioService.instance.play(url);
    });
  }

  @override
  void dispose() {
    recordingSubscription?.cancel();
    recorder.dispose();
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final body = switch (step.type) {
      'word_intro' => _buildWordIntro(),
      'order_words' => _buildOrder(),
      'cloze' => _buildCloze(),
      'dictation' || 'write_sentence' => _buildWriting(),
      'speak' => _buildSpeaking(),
      'component_tree' => _buildComponentTree(),
      _ => _buildChoice(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          step.prompt,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 14),
        Expanded(child: body),
      ],
    );
  }

  Widget _buildWordIntro() {
    final metadata = widget.step.metadata;
    final character =
        metadata['character'] as String? ?? widget.step.revealCharacter ?? '';
    final jyutping =
        metadata['jyutping'] as String? ?? widget.step.revealJyutping ?? '';
    final facts = <(String, String)>[
      ('PRONUNCIATION', metadata['pronunciation'] as String? ?? jyutping),
      ('TONE', metadata['tone_label'] as String? ?? ''),
      ('MEANING', metadata['meaning'] as String? ?? ''),
      ('WORD TYPE', metadata['word_type'] as String? ?? ''),
      ('COMPONENTS', metadata['components_label'] as String? ?? ''),
    ].where((fact) => fact.$2.trim().isNotEmpty).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Text(
                character,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jyutping,
                    style: const TextStyle(
                      color: AppTheme.blue,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if ((metadata['meaning'] as String? ?? '').isNotEmpty)
                    Text(
                      metadata['meaning'] as String? ?? '',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              _AudioOrb(
                onTap: widget.disabled
                    ? null
                    : () => AudioService.instance.play(
                        widget.step.audio?['url'] as String?,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...facts.map(
            (fact) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fact.$1,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fact.$2,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoice() {
    final step = widget.step;
    final visibleOptions = widget.disabled && selected != null
        ? step.options.where((option) => option['id'] == selected)
        : step.options;
    return Column(
      children: [
        if (step.audio != null)
          _AudioOrb(
            onTap: widget.disabled
                ? null
                : () =>
                      AudioService.instance.play(step.audio?['url'] as String?),
          )
        else
          _RepresentationCard(step: step),
        const Spacer(),
        ...visibleOptions.map((option) {
          final id = option['id'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _AnswerTile(
              label: option['label'] as String,
              selected: selected == id,
              disabled: widget.disabled,
              audioUrl: (option['audio'] as Map?)?['url'] as String?,
              onTap: () {
                setState(() => selected = id);
                widget.onResponseChanged({'selected_option_id': id});
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOrder() {
    final available = widget.step.options
        .where((option) => !ordered.any((item) => item['id'] == option['id']))
        .toList();
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border, width: 2),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ordered
                .map(
                  (word) => _WordChip(
                    label: word['label'] as String,
                    onTap: widget.disabled
                        ? null
                        : () {
                            _playOptionAudio(word);
                            setState(() => ordered.remove(word));
                            _notifyOrder();
                          },
                  ),
                )
                .toList(),
          ),
        ),
        const Spacer(),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 9,
          runSpacing: 10,
          children: available
              .map(
                (word) => _WordChip(
                  label: word['label'] as String,
                  onTap: widget.disabled
                      ? null
                      : () {
                          _playOptionAudio(word);
                          setState(() => ordered.add(word));
                          _notifyOrder();
                        },
                ),
              )
              .toList(),
        ),
        const Spacer(),
      ],
    );
  }

  void _playOptionAudio(Map<String, dynamic> option) {
    AudioService.instance.play((option['audio'] as Map?)?['url'] as String?);
  }

  void _notifyOrder() {
    widget.onResponseChanged(
      ordered.isEmpty
          ? null
          : {'order': ordered.map((word) => word['id']).toList()},
    );
  }

  Widget _buildCloze() {
    final step = widget.step;
    final visibleOptions = widget.disabled && selected != null
        ? step.options.where((option) => option['id'] == selected)
        : step.options;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (step.revealEnglish != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F6FE),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              step.revealEnglish!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        if (!manualInput)
          ...visibleOptions.map((option) {
            final id = option['id'] as String;
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _AnswerTile(
                label: option['label'] as String,
                selected: selected == id,
                disabled: widget.disabled,
                audioUrl: (option['audio'] as Map?)?['url'] as String?,
                onTap: () {
                  setState(() => selected = id);
                  widget.onResponseChanged({'selected_option_id': id});
                },
              ),
            );
          })
        else
          TextField(
            controller: textController,
            enabled: !widget.disabled,
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: 'Type the missing word',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.border,
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              final answer = value.trim();
              widget.onResponseChanged(
                answer.isEmpty ? null : {'answer': answer},
              );
            },
          ),
        if (step.metadata['allow_manual_input'] == true && !widget.disabled)
          TextButton(
            onPressed: () {
              setState(() {
                manualInput = !manualInput;
                selected = null;
                textController.clear();
              });
              widget.onResponseChanged(null);
            },
            child: Text(manualInput ? 'USE WORD CHOICES' : 'TYPE INSTEAD'),
          ),
      ],
    );
  }

  Widget _buildWriting() {
    final isLong = widget.step.type == 'write_sentence';
    return Column(
      children: [
        if (widget.step.audio != null)
          _AudioOrb(
            onTap: widget.disabled
                ? null
                : () => AudioService.instance.play(
                    widget.step.audio?['url'] as String?,
                  ),
          ),
        const Spacer(),
        TextField(
          controller: textController,
          enabled: !widget.disabled,
          maxLines: isLong ? 3 : 1,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: isLong
                ? 'Write your Cantonese sentence'
                : 'Type your answer',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.border, width: 2),
            ),
          ),
          onChanged: (value) {
            final text = value.trim();
            widget.onResponseChanged(
              text.isEmpty ? null : {'text': text, 'answer': text},
            );
          },
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildSpeaking() {
    final expectedText =
        widget.step.metadata['expected_text'] as String? ??
        widget.step.revealCharacter ??
        '';
    final expectedJyutping =
        widget.step.metadata['expected'] as String? ??
        widget.step.revealJyutping ??
        '';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (expectedJyutping.isNotEmpty)
          Text(
            expectedJyutping,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        if (expectedText.isNotEmpty)
          Text(
            expectedText,
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
          ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: widget.disabled || assessing ? null : _toggleRecording,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: recording ? AppTheme.red : AppTheme.blue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: recording
                      ? const Color(0xFFC43B3B)
                      : AppTheme.blueDark,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              recording ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          assessing
              ? 'Listening to your answer…'
              : recording
              ? 'Tap to stop'
              : speechTranscript ?? 'Tap, speak, then tap again',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (assessing)
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Future<void> _toggleRecording() async {
    if (recording) {
      await recorder.stop();
      await recordingSubscription?.cancel();
      setState(() {
        recording = false;
        assessing = true;
      });
      final transcript = await widget.onAssessSpeech(
        recordedBytes,
        widget.step.metadata['expected_text'] as String? ??
            widget.step.revealCharacter ??
            '',
        widget.step.metadata['expected'] as String? ??
            widget.step.revealJyutping ??
            '',
      );
      if (!mounted) return;
      setState(() {
        assessing = false;
        speechTranscript = transcript ?? 'Could not hear that—try again';
      });
      widget.onResponseChanged(
        transcript == null ? null : {'transcript': transcript},
      );
      return;
    }

    if (!await recorder.hasPermission()) {
      if (mounted) {
        setState(() {
          speechTranscript =
              'Microphone permission is required for this exercise';
        });
      }
      return;
    }
    recordedBytes.clear();
    final stream = await recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
    recordingSubscription = stream.listen(recordedBytes.addAll);
    setState(() {
      recording = true;
      speechTranscript = null;
    });
  }

  Widget _buildComponentTree() {
    final root = widget.step.metadata['root'] as String? ?? '食';
    final related = List<String>.from(
      widget.step.metadata['related'] ?? const <String>[],
    );
    return Column(
      children: [
        Text(
          root,
          style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(width: 3, height: 28, color: AppTheme.purple),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 9,
          runSpacing: 9,
          children: related.map((word) => _WordChip(label: word)).toList(),
        ),
        const Spacer(),
        ...(widget.disabled && selected != null
                ? widget.step.options.where(
                    (option) => option['id'] == selected,
                  )
                : widget.step.options)
            .map((option) {
              final id = option['id'] as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _AnswerTile(
                  label: option['label'] as String,
                  selected: selected == id,
                  disabled: widget.disabled,
                  onTap: () {
                    setState(() => selected = id);
                    widget.onResponseChanged({'selected_option_id': id});
                  },
                ),
              );
            }),
      ],
    );
  }
}

class _AudioOrb extends StatefulWidget {
  const _AudioOrb({this.onTap});
  final VoidCallback? onTap;

  @override
  State<_AudioOrb> createState() => _AudioOrbState();
}

class _AudioOrbState extends State<_AudioOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  bool pressed = false;

  @override
  void initState() {
    super.initState();
    pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => pressed = true),
      onTapCancel: widget.onTap == null
          ? null
          : () => setState(() => pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => pressed = false);
              pulse.forward(from: 0);
              widget.onTap?.call();
            },
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final wave = Curves.easeOutBack.transform(pulse.value);
          return AnimatedScale(
            scale: pressed ? .9 : 1 + wave * .08,
            duration: const Duration(milliseconds: 90),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              width: 88,
              height: 88,
              transform: Matrix4.translationValues(0, pressed ? 5 : 0, 0),
              decoration: BoxDecoration(
                color: pressed
                    ? const Color(0xFFC9ECFC)
                    : const Color(0xFFE4F6FE),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.blue.withValues(
                    alpha: .2 + pulse.value * .35,
                  ),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.blueDark.withValues(alpha: .35),
                    offset: Offset(0, pressed ? 1 : 6),
                  ),
                ],
              ),
              child: Icon(
                pulse.isAnimating
                    ? Icons.graphic_eq_rounded
                    : Icons.volume_up_rounded,
                color: AppTheme.blue,
                size: 44,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _RepresentationCard extends StatelessWidget {
  const _RepresentationCard({required this.step});
  final ExerciseStep step;

  @override
  Widget build(BuildContext context) {
    final primary =
        step.metadata['display'] as String? ??
        step.revealJyutping ??
        step.revealCharacter ??
        step.revealEnglish;
    if (primary == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: Text(
        primary,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
    this.audioUrl,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final String? audioUrl;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled
        ? null
        : () {
            if (audioUrl != null) AudioService.instance.play(audioUrl);
            onTap();
          },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE4F6FE) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: selected ? AppTheme.blue : AppTheme.border,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(color: AppTheme.border, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          if (audioUrl != null) ...[
            const Icon(Icons.volume_up_rounded, color: AppTheme.blue),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _WordChip extends StatelessWidget {
  const _WordChip({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    onPressed: onTap,
    backgroundColor: Colors.white,
    side: const BorderSide(color: AppTheme.border, width: 2),
    label: Text(
      label,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    ),
  );
}
