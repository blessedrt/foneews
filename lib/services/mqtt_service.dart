import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../config.dart';

class MqttSvc {
  static Future<void> sendSOS(double? lat, double? lon) async {
    // mock
    if (AppConfig.mockMode) return;
    final c = MqttServerClient.withPort('test.mosquitto.org', 'foneews-${DateTime.now().millisecondsSinceEpoch}', 8883);
    c.secure = true;
    c.logging(on: false);
    await c.connect();
    final payload = jsonEncode({'type':'SOS','lat':lat,'lon':lon,'time':DateTime.now().toIso8601String()});
    final msg = MqttClientPayloadBuilder()..addUTF8String(payload);
    c.publishMessage(AppConfig.topicSOS, MqttQos.atLeastOnce, msg.payload!);
    c.disconnect();
  }
}
