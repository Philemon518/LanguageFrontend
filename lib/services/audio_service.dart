import 'package:just_audio/just_audio.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();
  final AudioPlayer _player = AudioPlayer();

  Future<void> play(String? url) async {
    if (url == null || url.isEmpty) return;
    await _player.stop();
    await _player.setUrl(url);
    await _player.play();
  }

  Future<void> dispose() => _player.dispose();
}
