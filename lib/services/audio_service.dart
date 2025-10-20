import 'package:just_audio/just_audio.dart';
import 'safe_track_service.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();
  static final Map<int, String> _alertSounds = {
    1: 'assets/audio/alarm1.mp3',
    2: 'assets/audio/alarm2.mp3',
    3: 'assets/audio/alarm3.mp3',
  };

  static Future<void> playAlert(int priority) async {
    final alertSound = _alertSounds[priority] ?? _alertSounds[1]!;
    await _player.setAsset(alertSound);
    await _player.play();
  }

  static Future<void> playMessage(String filePath) async {
    await _player.setFilePath(filePath);
    await _player.play();
    
    // Start SafeTrack when message plays
    await SafeTrackService.startTracking();
  }

  static void stop() {
    _player.stop();
  }
}