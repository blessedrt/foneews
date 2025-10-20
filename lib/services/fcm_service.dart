import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geo_fence_service.dart';
import 's3_service.dart';
import 'audio_service.dart';
import 'notifications_service.dart';

class FcmService {
  static const _messageIdsKey = 'processed_message_ids';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleMessage);
    
    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_handleMessage);
    
    // Request permissions
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    try {
      // Extract message data
      final messageId = message.data['messageId'];
      final encryptedPolygon = message.data['polygon'];
      final s3key = message.data['s3key'];
      final priority = int.tryParse(message.data['priority'] ?? '1') ?? 1;
      
      // Check if already processed
      if (await _isMessageProcessed(messageId)) {
        return;
      }
      
      // Check location against polygon
      if (!await GeoFenceService.isWithinPolygon(encryptedPolygon)) {
        return;
      }
      
      // Download audio file
      final filePath = await S3Service.downloadAudioFile(s3key);
      if (filePath == null) {
        throw 'Failed to download audio';
      }
      
      // Play alert and show notification
      await AudioService.playAlert(priority);
      await Noti.show(
        'New Message',
        'Tap to listen to the emergency message',
        actions: [
          NotificationAction(
            'listen',
            'Listen',
            onPressed: () => AudioService.playMessage(filePath),
          ),
        ],
      );
      
      // Mark as processed
      await _markMessageProcessed(messageId);
      
    } catch (e) {
      print('Error handling message: $e');
    }
  }

  static Future<bool> _isMessageProcessed(String messageId) async {
    final processedIds = _prefs?.getStringList(_messageIdsKey) ?? [];
    return processedIds.contains(messageId);
  }

  static Future<void> _markMessageProcessed(String messageId) async {
    final processedIds = _prefs?.getStringList(_messageIdsKey) ?? [];
    processedIds.add(messageId);
    await _prefs?.setStringList(_messageIdsKey, processedIds);
  }

  static Future<void> safeInit() async {}
}