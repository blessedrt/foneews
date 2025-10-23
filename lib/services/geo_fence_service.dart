import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import '../config.dart';
import 'crypto_service.dart';

class GeoFenceService {
  static const double pi = math.pi;
  
  /// Check if current location is within the encrypted polygon
  /// Uses your proprietary AES-ECB encryption with POLYGON_KEY
  static Future<bool> isWithinPolygon(String encryptedPolygon) async {
    try {
      debugPrint('📍 Starting geodesic geofence check...');
      debugPrint('🔐 Encrypted polygon length: ${encryptedPolygon.length} chars');
      
      // Decrypt using your proprietary CryptoService
      final decrypted = CryptoService.decryptAesEcbBase64(
        encryptedPolygon,
        SecurityConfig.polygonKeyBase64,
      );
      debugPrint('✅ Polygon decrypted successfully');
      debugPrint('📄 Decrypted data: ${decrypted.substring(0, math.min(100, decrypted.length))}...');
      
      // Parse coordinates (format: "lat1,lon1;lat2,lon2;...")
      final points = <LatLng>[];
      for (final point in decrypted.split(';')) {
        final trimmed = point.trim();
        if (trimmed.isEmpty) continue;
        
        final parts = trimmed.split(',');
        if (parts.length >= 2) {
          try {
            points.add(LatLng(
              double.parse(parts[0].trim()),
              double.parse(parts[1].trim()),
            ));
          } catch (e) {
            debugPrint('⚠️ Failed to parse point: $trimmed');
          }
        }
      }
      
      if (points.isEmpty) {
        debugPrint('❌ No valid polygon points parsed from decrypted data');
        debugPrint('📄 Decrypted string: $decrypted');
        return true; // Allow through if polygon is invalid
      }
      
      debugPrint('📐 Polygon has ${points.length} points');
      for (int i = 0; i < math.min(points.length, 5); i++) {
        debugPrint('   Point $i: ${points[i]}');
      }
      
      // Get current location
      debugPrint('📍 Getting current location...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      debugPrint('📍 Current location: ${position.latitude}, ${position.longitude}');

      // Check if point is inside polygon using geodesic algorithm
      final polygon = GeodesicPolygon(points);
      final isInside = polygon.isInside(
        position.latitude, 
        position.longitude, 
        geodesic: true, // Use accurate great circle calculations
      );
      
      debugPrint(isInside ? '✅ Inside geofence' : '❌ Outside geofence');
      return isInside;
      
    } catch (e, st) {
      debugPrint('❌ Geofence check failed: $e');
      debugPrint('Stack trace: $st');
      // Return true to allow message through if geofence check fails
      // This ensures emergency messages aren't blocked by technical issues
      return true;
    }
  }
  
  /// Test geofence with manual coordinates (for debugging)
  static Future<bool> testGeofence(String encryptedPolygon, double lat, double lon) async {
    try {
      final decrypted = CryptoService.decryptAesEcbBase64(
        encryptedPolygon,
        SecurityConfig.polygonKeyBase64,
      );
      
      final points = <LatLng>[];
      for (final point in decrypted.split(';')) {
        final trimmed = point.trim();
        if (trimmed.isEmpty) continue;
        final parts = trimmed.split(',');
        if (parts.length >= 2) {
          points.add(LatLng(
            double.parse(parts[0].trim()),
            double.parse(parts[1].trim()),
          ));
        }
      }
      
      if (points.isEmpty) return true;
      
      final polygon = GeodesicPolygon(points);
      return polygon.isInside(lat, lon, geodesic: true);
    } catch (e) {
      debugPrint('❌ Test geofence failed: $e');
      return true;
    }
  }
}

/// Geodesic polygon implementation using spherical geometry
/// This matches the algorithm used in your B4A server console
class GeodesicPolygon {
  final List<LatLng> points;
  
  GeodesicPolygon(this.points);
  
  /// Check if a point is inside the polygon
  /// geodesic: true for great circle segments (accurate for real-world coords)
  ///          false for rhumb line segments (constant bearing, less accurate)
  bool isInside(double latitude, double longitude, {bool geodesic = true}) {
    final size = points.length;
    if (size == 0) return false;
    
    final lat3 = _toRadians(latitude);
    final lng3 = _toRadians(longitude);
    
    var lat1 = _toRadians(points[size - 1].latitude);
    var lng1 = _toRadians(points[size - 1].longitude);
    
    var nIntersect = 0;
    
    for (final point2 in points) {
      final dLng3 = _wrap(lng3 - lng1, - math.pi, math.pi);
      
      // Check if point is exactly on a vertex
      if (lat3 == lat1 && dLng3 == 0) return true;
      
      final lat2 = _toRadians(point2.latitude);
      final lng2 = _toRadians(point2.longitude);
      
      if (_intersects(lat1, lat2, _wrap(lng2 - lng1, -math.pi, math.pi), lat3, dLng3, geodesic)) {
        nIntersect++;
      }
      
      lat1 = lat2;
      lng1 = lng2;
    }
    
    // Odd number of intersections means inside
    return (nIntersect & 1) != 0;
  }
  
  /// Convert degrees to radians
  double _toRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
  
  /// Wrap value to range [min, max)
  double _wrap(double n, double min, double max) {
    if (n >= min && n < max) {
      return n;
    }
    return (_mod(n - min, max - min) + min);
  }
  
  /// Modulo operation that handles negative numbers correctly
  double _mod(double x, double m) {
    return ((x % m) + m) % m;
  }
  
  /// Check if a ray from the point intersects the edge
  bool _intersects(double lat1, double lat2, double lng2, double lat3, double lng3, bool geodesic) {
    // Quick rejection tests
    if ((lng3 >= 0 && lng3 >= lng2) || (lng3 < 0 && lng3 < lng2)) return false;
    if (lat3 <= -math.pi / 2) return false;
    if (lat1 <= -math.pi / 2 || lat2 <= -math.pi / 2 || lat1 >= math.pi / 2 || lat2 >= math.pi / 2) return false;
    if (lng2 <= -math.pi) return false;
    
    final linearLat = (lat1 * (lng2 - lng3) + lat2 * lng3) / lng2;
    
    // Additional quick rejection tests
    if (lat1 >= 0 && lat2 >= 0 && lat3 < linearLat) return false;
    if (lat1 <= 0 && lat2 <= 0 && lat3 >= linearLat) return true;
    if (lat3 >= math.pi / 2) return true;
    
    // Use geodesic or rhumb line calculation
    if (geodesic) {
      return math.tan(lat3) >= _tanLatGC(lat1, lat2, lng2, lng3);
    } else {
      return _mercator(lat3) >= _mercatorLatRhumb(lat1, lat2, lng2, lng3);
    }
  }
  
  /// Calculate tangent of latitude for great circle
  double _tanLatGC(double lat1, double lat2, double lng2, double lng3) {
    return (math.tan(lat1) * math.sin(lng2 - lng3) + math.tan(lat2) * math.sin(lng3)) / math.sin(lng2);
  }
  
  /// Calculate mercator latitude for rhumb line
  double _mercatorLatRhumb(double lat1, double lat2, double lng2, double lng3) {
    return (_mercator(lat1) * (lng2 - lng3) + _mercator(lat2) * lng3) / lng2;
  }
  
  /// Mercator projection
  double _mercator(double lat) {
    return math.log(math.tan(lat * 0.5 + math.pi / 4));
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  
  const LatLng(this.latitude, this.longitude);
  
  @override
  String toString() => 'LatLng($latitude, $longitude)';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }
  
  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

// ============================================
// TESTING UTILITIES
// ============================================

/// Test utilities for debugging geofence
class GeoFenceTest {
  /// Run basic geofence tests
  static void runTests() {
    debugPrint('🧪 Running geofence tests...');
    
    // Test polygon: Rectangle around Melbourne, Australia
    final polygon = GeodesicPolygon([
      const LatLng(-37.7, 144.8),  // NW corner
      const LatLng(-37.7, 145.1),  // NE corner
      const LatLng(-37.9, 145.1),  // SE corner
      const LatLng(-37.9, 144.8),  // SW corner
    ]);
    
    // Test points
    final testCases = [
      {'point': const LatLng(-37.8136, 144.9631), 'expected': true, 'name': 'Melbourne CBD (center)'},
      {'point': const LatLng(-37.8, 145.0), 'expected': true, 'name': 'Inside polygon'},
      {'point': const LatLng(-37.6, 144.9), 'expected': false, 'name': 'North of polygon'},
      {'point': const LatLng(-38.0, 144.9), 'expected': false, 'name': 'South of polygon'},
      {'point': const LatLng(-37.8, 144.7), 'expected': false, 'name': 'West of polygon'},
      {'point': const LatLng(-37.8, 145.2), 'expected': false, 'name': 'East of polygon'},
      {'point': const LatLng(-37.7, 144.8), 'expected': true, 'name': 'On NW vertex'},
      {'point': const LatLng(-37.75, 144.95), 'expected': true, 'name': 'On north edge'},
    ];
    
    var passed = 0;
    var failed = 0;
    
    for (final testCase in testCases) {
      final point = testCase['point'] as LatLng;
      final expected = testCase['expected'] as bool;
      final name = testCase['name'] as String;
      
      final result = polygon.isInside(point.latitude, point.longitude);
      
      if (result == expected) {
        debugPrint('✅ PASS: $name - $point = $result');
        passed++;
      } else {
        debugPrint('❌ FAIL: $name - $point = $result (expected $expected)');
        failed++;
      }
    }
    
    debugPrint('');
    debugPrint('🧪 Test Results: $passed passed, $failed failed');
  }
  
  /// Create a polygon string in the format your server expects
  static String createPolygonString(List<LatLng> points) {
    return points.map((p) => '${p.latitude},${p.longitude}').join(';');
  }
  
  /// Test encryption/decryption with your crypto service
  static void testEncryption() {
    debugPrint('🧪 Testing encryption...');
    
    try {
      // Create test polygon string
      final testPolygon = createPolygonString([
        const LatLng(-37.7, 144.8),
        const LatLng(-37.7, 145.1),
        const LatLng(-37.9, 145.1),
        const LatLng(-37.9, 144.8),
      ]);
      
      debugPrint('Original: $testPolygon');
      
      // Note: You'll need to encrypt this on your server and test decryption
      debugPrint('⚠️ Encryption test requires server-encrypted data');
      debugPrint('Send this polygon to your server to encrypt:');
      debugPrint(testPolygon);
      
    } catch (e) {
      debugPrint('❌ Encryption test failed: $e');
    }
  }
}