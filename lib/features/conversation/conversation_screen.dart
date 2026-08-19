import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../services/app_state.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  WebSocketChannel? _channel;
  final List<Map<String, String>> _transcript = [];
  List<String> _targetVocab = [];
  bool _connecting = false;
  String? _error;
  String _status = 'Tap to start a Cantonese call';

  Future<void> _startCall() async {
    setState(() {
      _connecting = true;
      _error = null;
      _transcript.clear();
    });
    try {
      final appState = context.read<AppState>();
      final session = await appState.createConversation(
        scenarioId: 'restaurant-order',
      );
      _targetVocab = session.targetVocab;
      final uri = appState.authenticatedWebSocketUri(session.wsUrl);
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen((event) {
        final data = jsonDecode(event as String) as Map<String, dynamic>;
        final type = data['type'] as String? ?? '';
        if (type == 'response.audio_transcript.done') {
          setState(
            () => _transcript.add({
              'role': 'assistant',
              'text': data['transcript'] as String? ?? '',
            }),
          );
        } else if (type ==
            'conversation.item.input_audio_transcription.completed') {
          setState(
            () => _transcript.add({
              'role': 'user',
              'text': data['transcript'] as String? ?? '',
            }),
          );
        } else if (type == 'session.timeout') {
          setState(() => _status = 'Session ended');
        }
      });
      setState(() {
        _connecting = false;
        _status = 'Connected — speak Cantonese!';
      });
    } catch (e) {
      setState(() {
        _connecting = false;
        _error = e.toString();
      });
    }
  }

  void _endCall() {
    _channel?.sink.add(jsonEncode({'type': 'close'}));
    _channel?.sink.close();
    _channel = null;
    setState(() => _status = 'Call ended');
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Conversation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: SizedBox(
                width: double.infinity,
                height: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(_status, textAlign: TextAlign.center),
                    if (_connecting)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            if (_targetVocab.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _targetVocab
                    .map((v) => Chip(label: Text(v)))
                    .toList(),
              ),
            ],
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _transcript.length,
                itemBuilder: (_, i) {
                  final entry = _transcript[i];
                  final isUser = entry['role'] == 'user';
                  return Align(
                    alignment: isUser
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUser
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.15)
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(entry['text'] ?? ''),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _connecting
                        ? null
                        : (_channel == null ? _startCall : _endCall),
                    icon: Icon(_channel == null ? Icons.phone : Icons.call_end),
                    label: Text(_channel == null ? 'Start call' : 'End call'),
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
