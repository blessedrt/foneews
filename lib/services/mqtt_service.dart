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
  
  // Encryption setup using POLYGON_KEY (the actual encryption key)
  static final _key = encrypt.Key.fromUtf8(SecurityConfig.polygonKeyBase64);
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(
    encrypt.AES(_key, mode: encrypt.AESMode.ecb)
  );

  static Future<void> init() async {
    final clientId = 'ews_client_${DateTime.now().millisecondsSinceEpoch}';
    
    _client = MqttServerClient(SecurityConfig.MQTT_BROKER, clientId)
      ..port = SecurityConfig.MQTT_PORT
      ..secure = true
      ..keepAlivePeriod = 20
      ..logging(on: false);

    // Set up connection message with username and password
    final connMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .authenticateAs(
        SecurityConfig.MQTT_USERNAME, 
        SecurityConfig.MQTT_PASSWORD
      )
      .startClean()
      .withWillQos(MqttQos.atLeastOnce);
    
    _client!.connectionMessage = connMessage;

    try {
      print('Connecting to MQTT broker: ${SecurityConfig.MQTT_BROKER}:${SecurityConfig.MQTT_PORT}');
      await _client?.connect();
      
      if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
        print('MQTT Connected successfully');
      } else {
        print('MQTT Connection failed - status: ${_client?.connectionStatus?.state}');
        _client = null;
      }
    } catch (e) {
      print('MQTT Connection error: $e');
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
      print('MQTT not connected, attempting to reconnect...');
      await init();
      
      // If still not connected, return
      if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
        print('Failed to reconnect to MQTT broker');
        return;
      }
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
        AppConfig.topicSafeTrack, // Use the topic from config
        MqttQos.atLeastOnce,
        builder.payload!,
      );

      print('Location published to ${AppConfig.topicSafeTrack}');
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
          'model': info.model,
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

  static void disconnect() {
    _client?.disconnect();
    _client = null;
  }
}