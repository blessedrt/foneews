import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class Noti {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
  }
  static Future<void> show(String title, String body) =>
    _plugin.show(0, title, body, const NotificationDetails(
      android: AndroidNotificationDetails('ews','EWS', importance: Importance.max, priority: Priority.high),
      iOS: DarwinNotificationDetails()
    ));
}
