// lib/services/fcm_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// A safer, non-blocking Firebase Messaging initializer.
/// It will not crash your app if Firebase is not configured yet.
/// Works fine in mock mode too.
class FcmService {
  static Future<void> safeInit() async {
    try {
      // Ask for permissions (Android auto-grants, iOS may prompt)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Enable auto-init so FCM handles background registration
      await FirebaseMessaging.instance.setAutoInitEnabled(true);

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((msg) {
        debugPrint('💬 FCM (foreground): ${msg.data}');
      });

      // Optionally log the current token (don’t block on it)
      unawaited(
        FirebaseMessaging.instance.getToken().then(
          (t) => debugPrint('🔑 FCM token: $t'),
          onError: (e) => debugPrint('Token error: $e'),
        ),
      );
    } catch (e, st) {
      debugPrint('⚠️ FCM init skipped or failed: $e\n$st');
    }
  }
}
