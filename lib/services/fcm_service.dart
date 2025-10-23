import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'geo_fence_service.dart';
import 's3_service.dart';
import 'audio_service.dart';
import 'notifications_service.dart';
import 'safe_track_service.dart';
import 'package:flutter/foundation.dart';

// TOP-LEVEL function for background messages (REQUIRED)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');
  // Initialize SharedPreferences in background isolate
  await FcmService._initializePreferences();
  await FcmService._handleMessage(message);
}

class FcmService {
  static const _messageIdsKey = 'processed_message_ids';
  static SharedPreferences? _prefs;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      debugPrint('⚠️ FCM Service already initialized');
      return;
    }
    
    debugPrint('🚀 Initializing FCM Service...');
    
    try {
      await _initializePreferences();
      
      // Request permissions (iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('📱 FCM Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('⚠️ FCM permissions not granted: ${settings.authorizationStatus}');
      }
      
      // Get FCM token
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('🔑 FCM Token received (length: ${token.length})');
        debugPrint('Token preview: $token...');
        // TODO: Send token to your server
      } else {
        debugPrint('⚠️ Failed to get FCM token');
      }
      
      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed');
        // TODO: Update token on your server
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('🔔 Foreground message received: ${message.messageId}');
        _handleMessage(message);
      });
      
      // Handle background/terminated messages
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      
      // Handle notification taps
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('👆 Notification tapped: ${message.messageId}');
        // Handle notification tap if needed
      });
      
      // Check for initial message (app opened from terminated state via notification)
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('📱 App opened from notification: ${initialMessage.messageId}');
        await _handleMessage(initialMessage);
      }
      
      _initialized = true;
      debugPrint('✅ FCM Service initialized successfully');
      
    } catch (e, st) {
      debugPrint('❌ FCM initialization failed: $e');
      debugPrint('Stack trace: $st');
      _initialized = false;
    }
  }

  static Future<void> _initializePreferences() async {
    if (_prefs != null) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      debugPrint('✅ SharedPreferences initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize SharedPreferences: $e');
    }
  }

  static Future<void> _handleMessage(RemoteMessage message) async {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📨 PROCESSING FCM MESSAGE');
    debugPrint('═══════════════════════════════════════');
    
    debugPrint('🆔 Message ID: ${message.messageId}');
    debugPrint('📦 Message data: ${message.data}');
    
    try {
      // Ensure preferences are initialized
      await _initializePreferences();
      
      // Extract message data with validation
      final messageId = message.data['messageId']?.toString();
      final encryptedPolygon = message.data['polygon']?.toString();
      final s3key = message.data['s3key']?.toString();
      final priorityStr = message.data['priority']?.toString();
      final priority = priorityStr != null ? int.tryParse(priorityStr) ?? 1 : 1;
      
      debugPrint('📋 Parsed data:');
      debugPrint('  Message ID: ${messageId ?? "MISSING"}');
      debugPrint('  S3 Key: ${s3key ?? "MISSING"}');
      debugPrint('  Priority: $priority');
      debugPrint('  Polygon: ${encryptedPolygon != null ? "Present (${encryptedPolygon.length} chars)" : "None"}');
      
      // Validate required fields
      if (s3key == null || s3key.isEmpty) {
        debugPrint('❌ Missing required s3key field');
        return;
      }
      
      // Check if already processed (only if messageId exists)
      if (messageId != null && messageId.isNotEmpty) {
        if (await _isMessageProcessed(messageId)) {
          debugPrint('⏭️ Message $messageId already processed, skipping');
          return;
        }
      } else {
        debugPrint('⚠️ No messageId provided, cannot track duplicates');
      }
      
      // STEP 1: Check geofence (if polygon provided)
      if (encryptedPolygon != null && encryptedPolygon.isNotEmpty) {
        debugPrint('🗺️ [STEP 1/4] Checking geofence...');
        try {
          final withinPolygon = await GeoFenceService.isWithinPolygon(encryptedPolygon)
              .timeout(const Duration(seconds: 10));
          
          if (!withinPolygon) {
            debugPrint('🚫 Outside geofence boundary, ignoring message');
            return;
          }
          debugPrint('✅ Inside geofence boundary, proceeding');
        } catch (e) {
          debugPrint('⚠️ Geofence check failed: $e');
          debugPrint('⚠️ Allowing message through due to geofence error');
          // Continue processing on geofence error (fail-open for safety)
        }
      } else {
        debugPrint('ℹ️ [STEP 1/4] No geofence polygon provided, skipping location check');
      }
      
      // STEP 2: Test S3 connection first
      debugPrint('🔌 [STEP 2/4] Testing S3 connection...');
      final s3Connected = await S3Service.testConnection()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      
      if (!s3Connected) {
        debugPrint('⚠️ S3 connection test failed - download may fail');
      } else {
        debugPrint('✅ S3 connection test passed');
      }
      
      // STEP 3: Download audio file
      debugPrint('📥 [STEP 3/4] Downloading audio from S3...');
      debugPrint('  S3 Key: $s3key');
      
      final filePath = await S3Service.downloadAudioFile(s3key)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏱️ S3 download timeout after 30 seconds');
              return null;
            }
          );
      
      if (filePath == null) {
        debugPrint('❌ Failed to download audio file from S3');
        debugPrint('❌ Cannot proceed without audio file');
        
        // Show error notification
        await Noti.show(
          'Emergency Alert Failed',
          'Failed to download emergency message. Check your internet connection.',
        );
        return;
      }
      
      debugPrint('✅ Audio downloaded successfully to: $filePath');
      
      // STEP 4: Play alert and show notification
      debugPrint('🔊 [STEP 4/4] Playing alert and showing notification...');
      
      // Play alert sound
      try {
        await AudioService.playAlert(priority)
            .timeout(const Duration(seconds: 10));
        debugPrint('✅ Alert sound played (priority: $priority)');
      } catch (e) {
        debugPrint('⚠️ Failed to play alert sound: $e');
        // Continue even if alert fails
      }
      
      // Start SafeTrack service
      try {
        debugPrint('🛡️ Starting SafeTrack service...');
        await SafeTrackService.startTracking();
        debugPrint('✅ SafeTrack started');
      } catch (e) {
        debugPrint('⚠️ Failed to start SafeTrack: $e');
        // Continue even if SafeTrack fails
      }
      
      // Show notification with Listen action
      try {
        await Noti.show(
          'Emergency Alert',
          'Tap to listen to the emergency message',
          actions: [
            NotificationAction(
              'listen_${messageId ?? DateTime.now().millisecondsSinceEpoch}',
              'Listen Now',
              onPressed: () async {
                debugPrint('🎵 Playing message audio from: $filePath');
                try {
                  await AudioService.playMessage(filePath);
                } catch (e) {
                  debugPrint('❌ Failed to play message: $e');
                }
              },
            ),
          ],
        );
        debugPrint('✅ Notification displayed');
      } catch (e) {
        debugPrint('❌ Failed to show notification: $e');
      }
      
      // Mark as processed (only if messageId exists)
      if (messageId != null && messageId.isNotEmpty) {
        await _markMessageProcessed(messageId);
        debugPrint('✅ Message $messageId marked as processed');
      }
      
      debugPrint('═══════════════════════════════════════');
      debugPrint('🎉 MESSAGE PROCESSING COMPLETE');
      debugPrint('═══════════════════════════════════════');
      
    } catch (e, st) {
      debugPrint('═══════════════════════════════════════');
      debugPrint('❌ ERROR HANDLING MESSAGE');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $st');
      
      // Try to show error notification
      try {
        await Noti.show(
          'Emergency Alert Error',
          'Failed to process emergency message. Please check the app.',
        );
      } catch (e) {
        debugPrint('❌ Could not show error notification: $e');
      }
    }
  }

  static Future<bool> _isMessageProcessed(String messageId) async {
    if (_prefs == null) {
      debugPrint('⚠️ SharedPreferences not initialized, cannot check duplicates');
      return false;
    }
    
    final processedIds = _prefs!.getStringList(_messageIdsKey) ?? [];
    final isProcessed = processedIds.contains(messageId);
    
    if (isProcessed) {
      debugPrint('ℹ️ Message $messageId was previously processed');
    }
    
    return isProcessed;
  }

  static Future<void> _markMessageProcessed(String messageId) async {
    if (_prefs == null) {
      debugPrint('⚠️ SharedPreferences not initialized, cannot mark as processed');
      return;
    }
    
    try {
      final processedIds = _prefs!.getStringList(_messageIdsKey) ?? [];
      
      if (!processedIds.contains(messageId)) {
        processedIds.add(messageId);
        
        // Keep only last 100 message IDs to prevent unlimited growth
        if (processedIds.length > 100) {
          final toRemove = processedIds.length - 100;
          processedIds.removeRange(0, toRemove);
          debugPrint('🗑️ Cleaned up $toRemove old message IDs');
        }
        
        await _prefs!.setStringList(_messageIdsKey, processedIds);
        debugPrint('💾 Message ID saved to processed list');
      }
    } catch (e) {
      debugPrint('❌ Failed to mark message as processed: $e');
    }
  }

  // Test function to manually trigger message handling
  static Future<void> testMessage({
    String? messageId,
    String? s3key,
    String? polygon,
    int priority = 2,
  }) async {
    debugPrint('🧪 TESTING FCM MESSAGE HANDLING');
    debugPrint('🧪 Test parameters:');
    debugPrint('  Message ID: ${messageId ?? "auto-generated"}');
    debugPrint('  S3 Key: ${s3key ?? "test.mp3"}');
    debugPrint('  Priority: $priority');
    debugPrint('  Polygon: ${polygon != null ? "provided" : "none"}');
    
    final testMessage = RemoteMessage(
      messageId: messageId ?? 'test_${DateTime.now().millisecondsSinceEpoch}',
      data: {
        'messageId': messageId ?? 'test_${DateTime.now().millisecondsSinceEpoch}',
        's3key': s3key ?? 'test.mp3',
        'priority': priority.toString(),
        if (polygon != null) 'polygon': polygon,
      },
    );
    
    await _handleMessage(testMessage);
  }

  // Cleanup method
  static void dispose() {
    _initialized = false;
    _prefs = null;
    debugPrint('🧹 FCM Service disposed');
  }
}