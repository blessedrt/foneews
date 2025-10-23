import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'safe_track_service.dart';

class AudioService {
  static final AudioPlayer _alertPlayer = AudioPlayer();
  static final AudioPlayer _messagePlayer = AudioPlayer();
  
  static final Map<int, String> _alertSounds = {
    1: 'assets/audio/alarm1.mp3',
    2: 'assets/audio/alarm2.mp3',
    3: 'assets/audio/alarm3.mp3',
  };

  static Future<void> playAlert(int priority) async {
    try {
      debugPrint('🔊 Playing alert sound (priority: $priority)...');
      
      final alertSound = _alertSounds[priority] ?? _alertSounds[1]!;
      debugPrint('🎵 Alert sound path: $alertSound');
      
      // Stop any currently playing alert
      await _alertPlayer.stop();
      
      // Set volume to maximum
      await _alertPlayer.setVolume(1.0);
      
      // Load and play the asset
      await _alertPlayer.setAsset(alertSound);
      debugPrint('✅ Alert asset loaded');
      
      await _alertPlayer.play();
      debugPrint('✅ Alert playing');
      
      // Wait for it to complete
      await _alertPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
        orElse: () => _alertPlayer.playerState,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⚠️ Alert playback timeout');
          return _alertPlayer.playerState;
        },
      );
      
      debugPrint('✅ Alert playback completed');
    } catch (e, st) {
      debugPrint('❌ Failed to play alert: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  static Future<void> playMessage(String filePath) async {
    try {
      debugPrint('🎵 Playing message from: $filePath');
      
      // Check if file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ Audio file does not exist: $filePath');
        throw 'Audio file not found';
      }
      
      final fileSize = await file.length();
      debugPrint('📄 File size: ${fileSize} bytes');
      
      // Stop any currently playing message
      await _messagePlayer.stop();
      
      // Set volume to maximum
      await _messagePlayer.setVolume(1.0);
      
      // Load and play the file
      await _messagePlayer.setFilePath(filePath);
      debugPrint('✅ Message file loaded');
      
      await _messagePlayer.play();
      debugPrint('✅ Message playing');
      
      // Start SafeTrack when message plays
      debugPrint('🛡️ Starting SafeTrack...');
      await SafeTrackService.startTracking();
      
    } catch (e, st) {
      debugPrint('❌ Failed to play message: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }

  static Future<void> stopAlert() async {
    try {
      await _alertPlayer.stop();
      debugPrint('⏹️ Alert stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping alert: $e');
    }
  }

  static Future<void> stopMessage() async {
    try {
      await _messagePlayer.stop();
      debugPrint('⏹️ Message stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping message: $e');
    }
  }

  static Future<void> stopAll() async {
    await stopAlert();
    await stopMessage();
  }

  // Test function to verify audio assets
  static Future<bool> testAlertSounds() async {
    debugPrint('🧪 Testing alert sounds...');
    
    for (final entry in _alertSounds.entries) {
      try {
        debugPrint('Testing alert ${entry.key}: ${entry.value}');
        await _alertPlayer.setAsset(entry.value);
        debugPrint('✅ Alert ${entry.key} loaded successfully');
      } catch (e) {
        debugPrint('❌ Alert ${entry.key} failed to load: $e');
        return false;
      }
    }
    
    debugPrint('✅ All alert sounds verified');
    return true;
  }

  static void dispose() {
    _alertPlayer.dispose();
    _messagePlayer.dispose();
  }
}