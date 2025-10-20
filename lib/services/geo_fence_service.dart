import 'package:geolocator/geolocator.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';

class GeoFenceService {
  static final _key = encrypt.Key.fromBase64('your-aes-key-here'); // Replace with actual key
  static final _iv = encrypt.IV.fromLength(16);
  static final _encrypter = encrypt.Encrypter(encrypt.AES(_key));

  static Future<bool> isWithinPolygon(String encryptedPolygon) async {
    try {
      // Decrypt the polygon string
      final decrypted = _encrypter.decrypt64(encryptedPolygon, iv: _iv);
      final coordinates = json.decode(decrypted) as List;
      
      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // Check if point is within polygon
      return _pointInPolygon(
        LatLng(position.latitude, position.longitude),
        coordinates.map((c) => LatLng(c[0], c[1])).toList(),
      );
    } catch (e) {
      print('Polygon check failed: $e');
      return false;
    }
  }

  static bool _pointInPolygon(LatLng point, List<LatLng> polygon) {
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if ((polygon[i].longitude > point.longitude) != (polygon[j].longitude > point.longitude) &&
          point.latitude < (polygon[j].latitude - polygon[i].latitude) * 
          (point.longitude - polygon[i].longitude) / 
          (polygon[j].longitude - polygon[i].longitude) + polygon[i].latitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}