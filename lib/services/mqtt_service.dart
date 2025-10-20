import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import '../config.dart';

class MqttService {
  static MqttServerClient? _client;
  static final _deviceInfo = DeviceInfoPlugin();
  
  // Encryption setup using config
  static final _key = encrypt.Key.fromUtf8(SecurityConfig.REGISTRATION_KEY);
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(
    encrypt.AES(_key, mode: encrypt.AESMode.ecb)
  );

  static Future<void> init() async {
    _client = MqttServerClient(SecurityConfig.MQTT_BROKER, 
      'ews_client_${DateTime.now().millisecondsSinceEpoch}')
      ..port = SecurityConfig.MQTT_PORT
      ..secure = true
      ..keepAlivePeriod = 20;

    try {
      await _client?.connect();
    } catch (e) {
      print('MQTT Connection failed: $e');
      _client = null;
    }
  }

  static Future<void> sendLocation(
    double lat, 
    double lon, 
    double speed, 
    double bearing
  ) async {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      await init();
    }

    try {
      final deviceData = await _getDeviceInfo();
      final payload = {
        'deviceid': 'EWS-PH-${deviceData['id']}',
        'lat': lat,
        'lon': lon,
        'speed': speed,
        'bearing': bearing,
        'time': DateTime.now().millisecondsSinceEpoch,
        'manufacturer': deviceData['manufacturer'],
        'model': deviceData['model'],
      };

      final jsonStr = json.encode(payload);
      final encrypted = _encrypter.encrypt(jsonStr, iv: _iv);
      
      final builder = MqttClientPayloadBuilder();
      builder.addString(encrypted.base64);
      
      _client?.publishMessage(
        'EWS-1',
        MqttQos.atLeastOnce,
        builder.payload!,
      );

    } catch (e) {
      print('Failed to send location: $e');
    }
  }

  static Future<Map<String, String>> _getDeviceInfo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return {
          'id': info.id,
          'manufacturer': info.manufacturer,
          'model': info.model,
        };
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return {
          'id': info.identifierForVendor ?? 'unknown',
          'manufacturer': 'Apple',
          'model': info.model ?? 'unknown',
        };
      }
    } catch (e) {
      print('Error getting device info: $e');
    }
    return {
      'id': 'unknown',
      'manufacturer': 'unknown',
      'model': 'unknown'
    };
  }
}