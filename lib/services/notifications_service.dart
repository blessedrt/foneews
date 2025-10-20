import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationAction {
  final String id;
  final String title;
  final Function() onPressed;
  
  const NotificationAction(this.id, this.title, {required this.onPressed});
}

class Noti {
  static final _plugin = FlutterLocalNotificationsPlugin();
  
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _handleNotificationAction,
    );
  }
  
  static Future<void> show(
    String title,
    String body, {
    List<NotificationAction> actions = const [],
  }) async {
    final androidActions = actions.map((a) => 
      AndroidNotificationAction(a.id, a.title)).toList();
      
    await _plugin.show(
      0,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ews',
          'EWS',
          importance: Importance.max,
          priority: Priority.high,
          actions: androidActions,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
  
  static void _handleNotificationAction(NotificationResponse response) {
    // Handle action taps here
  }
}