import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'audio_service.dart';
import 'notifications_service.dart';

class WiFiService {
  static const String TARGET_SSID = "EWS";
  static const String TARGET_PASSWORD = "ewsewsews";
  static const String MESSAGE_SERVER = "https://ews-message-server.local/index.html";
  static String MESSAGE_ID_KEY = Platform.isAndroid 
      ? "LastDownloadedMessageID" 
      : "LastWiFimessageID";

  static bool _isConnected = false;
  static bool _isConnecting = false;
  static bool _activityIsVisible = false;
  static Timer? _reconnectTimer;
  static Timer? _checkMessageTimer;
  static final NetworkInfo _networkInfo = NetworkInfo();
  static final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

  static StreamController<String> statusController = StreamController<String>.broadcast();

  // Store action callbacks for notification handling
  static final Map<String, Function()> _notificationCallbacks = {};

  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      _startPeriodicScan();
    }
    _startMessageChecking();
  }

  static void setActivityVisible(bool visible) {
    _activityIsVisible = visible;
    if (visible && Platform.isAndroid) {
      _attemptConnection();
    }
  }

  static Future<void> _startPeriodicScan() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (_activityIsVisible && !_isConnected && !_isConnecting) {
        _attemptConnection();
      }
    });
  }

  static Future<void> _attemptConnection() async {
    if (!_activityIsVisible || _isConnecting) return;

    _isConnecting = true;
    _updateStatus('Searching for Wi-Fi...');

    try {
      if (Platform.isAndroid) {
        final isEnabled = await WiFiForIoTPlugin.isEnabled();
        if (!isEnabled) {
          _updateStatus('Wi-Fi is turned off');
          return;
        }

        final ssidList = await WiFiForIoTPlugin.loadWifiList();
        final targetNetwork = ssidList.cast<WifiNetwork?>().firstWhere(
          (network) => network?.ssid == TARGET_SSID,
          orElse: () => null,
        );

        if (targetNetwork != null) {
          _updateStatus('EWS Hotspot found. Connecting...');
          
          final connected = await WiFiForIoTPlugin.connect(
            TARGET_SSID,
            password: TARGET_PASSWORD,
            security: NetworkSecurity.WPA,
            joinOnce: true,
            timeoutInSeconds: 15,
          );

          if (connected) {
            _isConnected = true;
            _updateStatus('Ready - EWS system online');
          } else {
            _updateStatus('Connection failed');
          }
        } else {
          _updateStatus('EWS Hotspot not in range');
        }
      } else {
        // iOS: Check if connected to correct network
        final ssid = await _networkInfo.getWifiName();
        _isConnected = ssid?.contains(TARGET_SSID) ?? false;
        _updateStatus(_isConnected 
            ? 'Ready - EWS system online' 
            : 'Please connect to EWS network in Settings');
      }
    } catch (e) {
      _updateStatus('Connection error: ${e.toString()}');
    } finally {
      _isConnecting = false;
    }
  }

  static void _startMessageChecking() {
    _checkMessageTimer?.cancel();
    _checkMessageTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected) {
        _checkForNewMessage();
      }
    });
  }

  static Future<void> _checkForNewMessage() async {
    try {
      final response = await http.get(Uri.parse(MESSAGE_SERVER))
          .timeout(Duration(seconds: Platform.isAndroid ? 15 : 6));

      if (response.statusCode == 200) {
        final messageId = response.headers['x-message-id'];
        if (messageId != null && await _isNewMessage(messageId)) {
          await _handleNewMessage(response.bodyBytes, messageId);
        }
      }
    } catch (e) {
      print('Message check failed: $e');
    }
  }

  static Future<bool> _isNewMessage(String messageId) async {
    final prefs = await _prefs;
    final lastId = prefs.getString(MESSAGE_ID_KEY);
    return lastId != messageId;
  }

  static Future<void> _handleNewMessage(List<int> audioData, String messageId) async {
    try {
      // Save file
      final timestamp = DateTime.now().toString().split('.')[0].replaceAll(':', '-');
      final filename = 'BROADWICK EWS $timestamp.mp3';
      final file = await _saveAudioFile(audioData, filename);

      if (file != null) {
        // Play alert
        await AudioService.playAlert(2); // Using alarm2.mp3

        // Store callback for notification action
        final callbackId = 'listen_$messageId';
        _notificationCallbacks[callbackId] = () => AudioService.playMessage(file.path);

        

        // Save message ID
        final prefs = await _prefs;
        await prefs.setString(MESSAGE_ID_KEY, messageId);
      }
    } catch (e) {
      print('Failed to handle new message: $e');
    }
  }

  static Future<File?> _saveAudioFile(List<int> audioData, String filename) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');
      await file.writeAsBytes(audioData);
      return file;
    } catch (e) {
      print('Failed to save audio file: $e');
      return null;
    }
  }

  // Method to handle notification actions from outside
  static void handleNotificationAction(String actionId) {
    final callback = _notificationCallbacks[actionId];
    if (callback != null) {
      callback();
    }
  }

  static void _updateStatus(String status) {
    if (!statusController.isClosed) {
      statusController.add(status);
    }
  }

  static void dispose() {
    _reconnectTimer?.cancel();
    _checkMessageTimer?.cancel();
    _notificationCallbacks.clear();
    statusController.close();
  }
}