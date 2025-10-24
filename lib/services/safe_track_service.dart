import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'mqtt_service.dart';

class SafeTrackService {
  static bool _isTracking = false;
  static Timer? _trackingTimer;
  static Timer? _durationTimer;
  static StreamSubscription<Position>? _positionStream;
  
  static final _trackingDuration = const Duration(minutes: 60);
  static final _updateInterval = const Duration(seconds: 10);
  
  static Function(bool)? onTrackingStateChanged;
  static Function(Position)? onLocationUpdated;

  static Future<void> startTracking() async {
    if (_isTracking) return;

    try {
      // Initialize MQTT
      await MqttService.init();

      // Request permissions
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw 'Location permission denied';
        }
      }

      // Start location updates
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_handleLocationUpdate);

      // Setup timers
      _trackingTimer = Timer.periodic(_updateInterval, _sendLocation);
      _durationTimer = Timer(_trackingDuration, stopTracking);

      _isTracking = true;
      onTrackingStateChanged?.call(true);
    } catch (e) {
      print('Failed to start tracking: $e');
      await stopTracking();
    }
  }

  static Future<void> stopTracking() async {
    _trackingTimer?.cancel();
    _durationTimer?.cancel();
    await _positionStream?.cancel();
    
    _trackingTimer = null;
    _durationTimer = null;
    _positionStream = null;
    
    _isTracking = false;
    onTrackingStateChanged?.call(false);
  }

  static void _handleLocationUpdate(Position position) {
    onLocationUpdated?.call(position);
  }

  static void _sendLocation(Timer timer) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await MqttService.sendLocation(
        position.latitude,
        position.longitude,
        position.speed,
        position.heading,
      );
    } catch (e) {
      print('Failed to send location update: $e');
    }
  }

  static bool get isTracking => _isTracking;
}