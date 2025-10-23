import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static Future<Position?> getLast() async {
    try {
      debugPrint('📍 Requesting location permission...');
      
      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('📍 Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('📍 Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        debugPrint('📍 Permission after request: $permission');
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied');
        return null;
      }
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('❌ Location services are disabled');
        return null;
      }
      
      debugPrint('📍 Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      debugPrint('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
      
    } catch (e, st) {
      debugPrint('❌ Failed to get location: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }
  
  // Get last known position (faster but might be stale)
  static Future<Position?> getLastKnown() async {
    try {
      final position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        debugPrint('📍 Last known location: ${position.latitude}, ${position.longitude}');
      }
      return position;
    } catch (e) {
      debugPrint('⚠️ Failed to get last known location: $e');
      return null;
    }
  }
}