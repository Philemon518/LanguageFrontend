import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../core/config.dart';
import '../models/curriculum.dart';
import '../services/audio_service.dart';
import '../utils/exercise_shuffle.dart';

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
  late List<Map<String, dynamic>> shuffledOptions;
  final recorder = AudioRecorder();
  StreamSubscription<Uint8List>? recordingSubscription;
  final recordedBytes = <int>[];
  bool recording = false;
  bool assessing = false;
  bool manualInput = false;
  String? speechTranscript;
  final Map<String, int> optionAudioTapCounts = {};

  @override
  void initState() {
    super.initState();
    shuffledOptions = shuffleExerciseOptions(widget.step.options);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.step.type == 'cloze') return;
      final url = widget.step.audio?['url'] as String?;
      if (url != null) AudioService.instance.play(url, speed: 1.0);
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
      'word_intro' || 'lesson_intro' => _buildWordIntro(),
      'order_words' => _buildOrder(),
      'cloze' => _buildCloze(),
      'dictation' ||
      'write_sentence' ||
      'typing' ||
      'type_character' ||
      'character_input' => _buildWriting(),
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
    if (widget.step.type == 'lesson_intro') {
      return _buildLessonIntro();
    }
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
      ('FOCUS', metadata['focus_token'] as String? ?? ''),
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
                audioUrl: widget.step.audio?['url'] as String?,
                enabled: !widget.disabled,
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

  Widget _buildLessonIntro() {
    final raw = widget.step.metadata['lesson_intro'];
    if (raw is! Map) return _buildWordIntroFallback();
    final intro = Map<String, dynamic>.from(raw);
    final summary = intro['summary']?.toString();
    final goals = intro['learning_goals'] is List
        ? intro['learning_goals'] as List
        : const [];
    final newItems = intro['new_items'] is List
        ? intro['new_items'] as List
        : const [];
    final reviewItems = intro['review_items'] is List
        ? intro['review_items'] as List
        : const [];
    final sections = intro['sections'] is List
        ? intro['sections'] as List
        : const [];
    final newItemsAreRenderedInSections = sections.any(
      (section) =>
          section is Map &&
          (section['type'] == 'number_rows' || section['type'] == 'audio_grid'),
    );

    return ListView(
      key: const Key('exerciseLessonIntroScrollView'),
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (summary != null && summary.isNotEmpty)
          Text(
            summary,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _StageSectionHeading('WHAT YOU’LL LEARN'),
          const SizedBox(height: 8),
          ...goals.map((goal) => _StageBullet(goal.toString())),
        ],
        if (sections.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...sections.map((section) => _IntroSection(section: section)),
        ],
        if (newItems.isNotEmpty && !newItemsAreRenderedInSections) ...[
          const SizedBox(height: 20),
          const _StageSectionHeading('NEW IN THIS LESSON'),
          const SizedBox(height: 8),
          ...newItems.map(
            (item) => _IntroItemCard(item: item, isReview: false),
          ),
        ],
        if (reviewItems.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _StageSectionHeading('QUICK REVIEW'),
          const SizedBox(height: 8),
          ...reviewItems.map(
            (item) => _IntroItemCard(item: item, isReview: true),
          ),
        ],
      ],
    );
  }

  Widget _buildWordIntroFallback() {
    final character = widget.step.revealCharacter ?? '';
    final jyutping = widget.step.revealJyutping ?? '';
    final english = widget.step.revealEnglish ?? '';
    return SingleChildScrollView(
      child: Column(
        children: [
          Text(
            character,
            style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
          ),
          Text(
            jyutping,
            style: const TextStyle(
              color: AppTheme.blue,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(english, style: const TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 16),
          _AudioOrb(
            audioUrl: widget.step.audio?['url'] as String?,
            enabled: !widget.disabled,
          ),
        ],
      ),
    );
  }

  Widget _buildChoice() {
    final step = widget.step;
    final visibleOptions = widget.disabled && selected != null
        ? shuffledOptions.where((option) => option['id'] == selected)
        : shuffledOptions;
    final audioRefs = step.audioRefs;
    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (step.imageSource != null) ...[
          _MediaImage(source: step.imageSource!, height: 190),
          const SizedBox(height: 16),
        ],
        if (audioRefs.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var index = 0; index < audioRefs.length; index++)
                Column(
                  children: [
                    Text(
                      String.fromCharCode(65 + index),
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _AudioOrb(
                      audioUrl: audioRefs[index]['url'] as String?,
                      enabled: !widget.disabled,
                      compact: true,
                    ),
                  ],
                ),
            ],
          )
        else if (audioRefs.isNotEmpty)
          _AudioOrb(
            audioUrl: audioRefs.first['url'] as String?,
            enabled: !widget.disabled,
          )
        else if (step.imageSource == null)
          _RepresentationCard(step: step),
        const SizedBox(height: 24),
        ...visibleOptions.indexed.map((entry) {
          final index = entry.$1;
          final option = entry.$2;
          final id = option['id'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnswerTile(
              label: option['label'] as String? ?? 'Choice ${index + 1}',
              selected: selected == id,
              disabled: widget.disabled,
              audioUrl: (option['audio'] as Map?)?['url'] as String?,
              imageSource: ExerciseStep.imageSourceForOption(option),
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
    final available = shuffledOptions
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
    final id = option['id']?.toString() ?? '';
    final tapCount = optionAudioTapCounts[id] ?? 0;
    optionAudioTapCounts[id] = tapCount + 1;
    AudioService.instance.play(
      (option['audio'] as Map?)?['url'] as String?,
      speed: AudioService.manualSpeedForTap(tapCount),
    );
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
        ? shuffledOptions.where((option) => option['id'] == selected)
        : shuffledOptions;

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        if (step.audio != null) ...[
          Center(
            child: _AudioOrb(
              audioUrl: step.audio?['url'] as String?,
              enabled: !widget.disabled,
            ),
          ),
          const SizedBox(height: 18),
        ],
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
                borderSide: const BorderSide(color: AppTheme.border, width: 2),
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
            audioUrl: widget.step.audio?['url'] as String?,
            enabled: !widget.disabled,
          ),
        const Spacer(),
        TextField(
          controller: textController,
          enabled: !widget.disabled,
          maxLines: isLong ? 3 : 1,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText:
                widget.step.type == 'type_character' ||
                    widget.step.type == 'character_input'
                ? '輸入漢字 · Type the Chinese character'
                : isLong
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
                ? shuffledOptions.where((option) => option['id'] == selected)
                : shuffledOptions)
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

class _StageSectionHeading extends StatelessWidget {
  const _StageSectionHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppTheme.blue,
      fontSize: 12,
      fontWeight: FontWeight.w900,
      letterSpacing: .8,
    ),
  );
}

class _StageBullet extends StatelessWidget {
  const _StageBullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.green, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3),
          ),
        ),
      ],
    ),
  );
}

class _IntroItemCard extends StatelessWidget {
  const _IntroItemCard({required this.item, required this.isReview});
  final dynamic item;
  final bool isReview;

  @override
  Widget build(BuildContext context) {
    if (item is! Map) return const SizedBox.shrink();
    final data = item as Map;
    final traditional = data['traditional']?.toString() ?? '';
    final jyutping = data['jyutping']?.toString() ?? '';
    final english = data['english']?.toString() ?? '';
    final audioUrl = (data['audio'] as Map?)?['url'] as String?;
    final image = ExerciseStep.imageSourceForOption(
      Map<String, dynamic>.from(data),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReview ? const Color(0xFFF7F7F7) : Colors.white,
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (image != null) ...[
            SizedBox(width: 76, child: _MediaImage(source: image, height: 72)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  traditional,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  jyutping,
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  english,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (audioUrl != null) _AudioOrb(audioUrl: audioUrl, compact: true),
        ],
      ),
    );
  }
}

class _IntroSection extends StatelessWidget {
  const _IntroSection({required this.section});
  final dynamic section;

  @override
  Widget build(BuildContext context) {
    if (section is! Map) return const SizedBox.shrink();
    final data = section as Map;
    final type = data['type']?.toString() ?? 'text';
    final title = data['title']?.toString() ?? '';
    final body = data['body']?.toString() ?? '';
    final items = data['items'] is List ? data['items'] as List : const [];
    final cards = data['cards'] is List ? data['cards'] as List : const [];
    final rows = data['rows'] is List ? data['rows'] as List : const [];
    final audio = data['audio'] is List ? data['audio'] as List : const [];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: type == 'hero' ? const Color(0xFFE4F6FE) : Colors.white,
        border: Border.all(color: AppTheme.border, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
          if (audio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: audio
                  .whereType<Map>()
                  .map(
                    (sample) => _ManualAudioIcon(
                      url: sample['url']?.toString() ?? '',
                      enabled: sample['url'] != null,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (type == 'number_rows')
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _IntroItemCard(item: item, isReview: false),
              ),
            )
          else if (type == 'audio_grid') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.whereType<Map>().map((item) {
                final sample = item['audio'] as Map?;
                return Container(
                  width: 132,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        item['label']?.toString() ?? '',
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        item['tone_label']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sample?['url'] is String)
                        _ManualAudioIcon(
                          url: sample!['url'] as String,
                          enabled: true,
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            ...[...items, ...cards].whereType<Map>().map(
              (item) => _IntroTextCard(
                label:
                    item['label']?.toString() ??
                    item['title']?.toString() ??
                    '',
                body: item['body']?.toString() ?? '',
              ),
            ),
            ...rows.whereType<Map>().map(
              (row) => _IntroTextCard(
                label: row['source']?.toString() ?? '',
                body: '→ ${row['target']?.toString() ?? ''}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntroTextCard extends StatelessWidget {
  const _IntroTextCard({required this.label, required this.body});
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              body,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _AudioOrb extends StatefulWidget {
  const _AudioOrb({
    required this.audioUrl,
    this.enabled = true,
    this.compact = false,
  });
  final String? audioUrl;
  final bool enabled;
  final bool compact;

  @override
  State<_AudioOrb> createState() => _AudioOrbState();
}

class _AudioOrbState extends State<_AudioOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController pulse;
  bool pressed = false;
  int tapCount = 0;

  bool get enabled => widget.enabled;

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
      onTapDown: !enabled ? null : (_) => setState(() => pressed = true),
      onTapCancel: !enabled ? null : () => setState(() => pressed = false),
      onTapUp: !enabled
          ? null
          : (_) {
              setState(() => pressed = false);
              pulse.forward(from: 0);
              final speed = AudioService.manualSpeedForTap(tapCount);
              tapCount++;
              AudioService.instance.play(widget.audioUrl, speed: speed);
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
              width: widget.compact ? 68 : 88,
              height: widget.compact ? 68 : 88,
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
                size: widget.compact ? 34 : 44,
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
    this.imageSource,
  });

  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  final String? audioUrl;
  final String? imageSource;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: disabled
        ? null
        : () {
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
      child: Column(
        children: [
          if (imageSource != null) ...[
            _MediaImage(source: imageSource!, height: 112),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (audioUrl != null) ...[
                _ManualAudioIcon(url: audioUrl!, enabled: !disabled),
                const SizedBox(width: 8),
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
              if (audioUrl != null) const SizedBox(width: 40),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ManualAudioIcon extends StatefulWidget {
  const _ManualAudioIcon({required this.url, required this.enabled});
  final String url;
  final bool enabled;

  @override
  State<_ManualAudioIcon> createState() => _ManualAudioIconState();
}

class _ManualAudioIconState extends State<_ManualAudioIcon> {
  int tapCount = 0;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tapCount.isEven ? 'Play at normal speed' : 'Play slowly',
    onPressed: widget.enabled
        ? () {
            final speed = AudioService.manualSpeedForTap(tapCount);
            setState(() => tapCount++);
            AudioService.instance.play(widget.url, speed: speed);
          }
        : null,
    icon: Icon(
      tapCount.isEven
          ? Icons.volume_up_rounded
          : Icons.slow_motion_video_rounded,
      color: AppTheme.blue,
    ),
  );
}

class _MediaImage extends StatelessWidget {
  const _MediaImage({required this.source, required this.height});
  final String source;
  final double height;

  @override
  Widget build(BuildContext context) {
    final normalized = source.startsWith('/') ? source.substring(1) : source;
    final image = source.startsWith('http://') || source.startsWith('https://')
        ? Image.network(
            source,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback,
          )
        : Image.asset(
            normalized,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _fallback,
          );
    return Semantics(
      label: 'Exercise illustration',
      image: true,
      child: SizedBox(width: double.infinity, height: height, child: image),
    );
  }

  Widget get _fallback => const Center(
    child: Icon(Icons.image_not_supported_outlined, color: AppTheme.muted),
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
