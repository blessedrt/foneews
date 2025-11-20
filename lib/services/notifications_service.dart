import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

class NotificationAction {
  final String id;
  final String title;
  final Function() onPressed;
  
  const NotificationAction(this.id, this.title, {required this.onPressed});
}

class Noti {
  static final _plugin = FlutterLocalNotificationsPlugin();
  
  // Store callbacks for notification actions
  static final Map<String, Function()> _actionCallbacks = {};
  
  static Future<void> init() async {
    debugPrint('🔔 Initializing notification service...');
    
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    final initialized = await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleNotificationAction,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationAction,
    );
    
    if (initialized == true) {
      debugPrint('✅ Notification service initialized');
      
      // Request permissions explicitly (especially for iOS)
      await _requestPermissions();
      
      // Create notification channel for Android
      await _createNotificationChannel();
    } else {
      debugPrint('⚠️ Notification service initialization returned false');
    }
  }
  
  static Future<void> _requestPermissions() async {
    try {
      // Android 13+ requires runtime notification permission
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint('📱 Android notification permission: ${granted == true ? "✅ Granted" : "❌ Denied"}');
      }
      
      // iOS permissions
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🍎 iOS notification permission: ${granted == true ? "✅ Granted" : "❌ Denied"}');
      }
    } catch (e) {
      debugPrint('⚠️ Error requesting permissions: $e');
    }
  }
  
  static Future<void> _createNotificationChannel() async {
    try {
      const androidChannel = AndroidNotificationChannel(
        'ews_emergency', // channel id
        'Emergency Alerts', // channel name
        description: 'Critical emergency alert notifications',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );
      
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidChannel);
        debugPrint('✅ Android notification channel created');
      }
    } catch (e) {
      debugPrint('⚠️ Error creating notification channel: $e');
    }
  }
  
  static Future<void> show(
    String title,
    String body, {
    List<NotificationAction> actions = const [],
  }) async {
    try {
      debugPrint('📨 Showing notification:');
      debugPrint('   Title: $title');
      debugPrint('   Body: $body');
      debugPrint('   Actions: ${actions.length}');
      
      // Store action callbacks
      for (final action in actions) {
        _actionCallbacks[action.id] = action.onPressed;
        debugPrint('   Stored callback for: ${action.id}');
      }
      
      // Create Android actions
      final androidActions = actions.map((a) => 
        AndroidNotificationAction(
          a.id, 
          a.title,
          showsUserInterface: true,
          cancelNotification: false,
        )).toList();
      
      // Show the notification
      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'ews_emergency', // Must match the channel created above
            'Emergency Alerts',
            channelDescription: 'Critical emergency alert notifications',
            importance: Importance.max,
            actions: androidActions,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            color: const Color(0xFFFF4757), // Red color for emergency
            ledColor: const Color(0xFFFF4757),
            ledOnMs: 1000,
            ledOffMs: 500,
            ticker: 'Emergency Alert',
            autoCancel: false, // Don't dismiss when tapped
            ongoing: false, // Allow user to dismiss
            styleInformation: const BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: 1,
            threadIdentifier: 'ews_emergency',
            interruptionLevel: InterruptionLevel.critical,
          ),
        ),
      );
      
      debugPrint('✅ Notification displayed successfully');
      
    } catch (e, st) {
      debugPrint('❌ Failed to show notification: $e');
      debugPrint('Stack trace: $st');
      rethrow;
    }
  }
  
  @pragma('vm:entry-point')
  static void _handleNotificationAction(NotificationResponse response) {
    debugPrint('👆 Notification action received:');
    debugPrint('   Action ID: ${response.actionId}');
    debugPrint('   Notification ID: ${response.id}');
    debugPrint('   Input: ${response.input}');
    
    if (response.actionId != null) {
      final callback = _actionCallbacks[response.actionId];
      
      if (callback != null) {
        debugPrint('✅ Executing stored callback for: ${response.actionId}');
        try {
          callback();
        } catch (e) {
          debugPrint('❌ Error executing callback: $e');
        }
      } else {
        debugPrint('⚠️ No callback found for action: ${response.actionId}');
        debugPrint('   Available callbacks: ${_actionCallbacks.keys.toList()}');
      }
    } else if (response.notificationResponseType == NotificationResponseType.selectedNotification) {
      debugPrint('📱 Notification body tapped (no action button)');
    }
  }
  
  // Test notification function
  static Future<void> showTest() async {
    debugPrint('🧪 Showing test notification...');
    await show(
      'Test Notification',
      'If you see this, notifications are working!',
      actions: [
        NotificationAction(
          'test_action',
          'Test Action',
          onPressed: () {
            debugPrint('🎉 Test action button pressed!');
          },
        ),
      ],
    );
  }
  
  // Clear all notifications
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
    _actionCallbacks.clear();
    debugPrint('🗑️ All notifications cleared');
  }
  
  // Clear action callbacks (call this on app restart)
  static void clearCallbacks() {
    _actionCallbacks.clear();
    debugPrint('🗑️ Notification callbacks cleared');
  }
}