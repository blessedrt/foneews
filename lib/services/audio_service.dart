import 'package:just_audio/just_audio.dart';

class AudioService {
  static final _player = AudioPlayer();
  static Future<void> playFile(String path) async { await _player.setFilePath(path); await _player.play(); }
  static Future<void> stop() async => _player.stop();
}
