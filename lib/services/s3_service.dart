// lib/services/s3_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../config.dart';

class S3Service {
  /// ---- Public API ---------------------------------------------------------

  /// Downloads an MP3 from S3 (presigned GET) and saves it under app documents.
  /// Returns the local file path on success, or null on failure.
  static Future<String?> downloadAudioFile(String s3key) async {
    try {
      debugPrint('📥 Starting S3 download.');
      debugPrint('🔑 S3 Key: $s3key');
      debugPrint('🪣 Bucket: ${AwsConfig.bucket}');
      debugPrint('🌍 Region: ${AwsConfig.region}');

      final now = DateTime.now();
      final timestamp =
          '${now.year}${_2(now.month)}${_2(now.day)}_${_2(now.hour)}${_2(now.minute)}${_2(now.second)}';
      final filename = 'BROADWICK_EWS_$timestamp.mp3';

      final url = _generateSignedUrl(s3key);
      debugPrint('🔗 Signed URL host: ${Uri.parse(url).host}');

      final response = await http
          .get(
            Uri.parse(url),
            headers: {
              'Accept': 'audio/mpeg, audio/*, */*',
            },
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏱️ Download timeout after 30 seconds');
              throw TimeoutException('S3 download timeout');
            },
          );

      debugPrint('📊 Response status: ${response.statusCode}');
      debugPrint('📦 Response size: ${response.bodyBytes.length} bytes');

      if (response.statusCode == 403) {
        debugPrint('❌ 403 Forbidden - Check AWS credentials/bucket policy');
        debugPrint('Response headers: ${response.headers}');
        debugPrint(
            'Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
        return null;
      }
      if (response.statusCode == 404) {
        debugPrint('❌ 404 Not Found - File does not exist in S3: $s3key');
        return null;
      }
      if (response.statusCode != 200) {
        debugPrint('❌ Download failed with status ${response.statusCode}');
        debugPrint(
            'Response body preview: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
        return null;
      }

      // Lightweight validity checks for MP3
      final bytes = response.bodyBytes;
      final hasID3 =
          bytes.length >= 3 && bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
      final hasMP3Sync =
          bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
      if (!hasID3 && !hasMP3Sync && bytes.length > 1000) {
        debugPrint('⚠️ File may not be a valid MP3 (no ID3 or sync header)');
      }

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);

      final savedSize = await file.length();
      debugPrint('✅ Audio saved to: ${file.path}');
      debugPrint('📊 Saved file size: $savedSize bytes');

      if (savedSize != bytes.length) {
        debugPrint(
            '⚠️ File size mismatch! Expected ${bytes.length}, got $savedSize');
      }

      return file.path;
    } catch (e, st) {
      debugPrint('❌ S3 download failed: $e');
      debugPrint('Stack trace: $st');
      return null;
    }
  }

  /// Cleans up old audio files (> 24h) from app documents dir.
  static Future<void> cleanupOldFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('BROADWICK_EWS'));

      var deleted = 0;
      for (final file in files) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        if (age > const Duration(hours: 24)) {
          await file.delete();
          deleted++;
        }
      }
      if (deleted > 0) {
        debugPrint('🗑️ Cleaned up $deleted old audio files');
      }
    } catch (e) {
      debugPrint('⚠️ Cleanup failed: $e');
    }
  }

  /// Connectivity test: presign a GET and request a 1-byte range.
  /// Returns true if auth/signing works (200 or 404), false otherwise.
  static Future<bool> testConnection() async {
    try {
      debugPrint('🧪 Testing S3 connection.');
      final testKey = 'test-connection-check.mp3';
      final url = _generateSignedUrl(testKey);

      // Use GET with Range so our method matches the signature and is very light.
      final res = await http
          .get(Uri.parse(url), headers: {'Range': 'bytes=0-0'})
          .timeout(const Duration(seconds: 5));

      debugPrint('📊 Test response: ${res.statusCode}');
      if (res.statusCode != 200 && res.statusCode != 404) {
        // Print S3's XML error for exact diagnosis (SignatureDoesNotMatch, etc.)
        debugPrint('S3 error body: ${res.body}');
      }

      if (res.statusCode == 404) {
        debugPrint(
            '✅ S3 credentials valid (404 = auth OK, object missing is fine for test)');
        return true;
      } else if (res.statusCode == 200) {
        debugPrint('✅ S3 credentials valid (test object exists)');
        return true;
      } else if (res.statusCode == 403) {
        debugPrint('❌ 403 Forbidden – check IAM user/role policy and bucket policy');
        debugPrint('   Need s3:GetObject on arn:aws:s3:::${AwsConfig.bucket}/*');
        return false;
      } else {
        debugPrint('⚠️ Unexpected response: ${res.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ S3 connection test failed: $e');
      return false;
    }
  }

  /// ---- SigV4 Presign (private) -------------------------------------------

  /// Builds a presigned URL for **GET** (valid for 1 hour).
  /// - Uses **path-style** when bucket contains dots to avoid TLS hostname mismatch.
  /// - Uses **UNSIGNED-PAYLOAD** as required by S3 presign.
  /// - Sorts & URL-encodes parameters.
  /// - Adds **X-Amz-Security-Token** when using temporary credentials.
  static String _generateSignedUrl(String objectKey) {
    final now = DateTime.now().toUtc();
    final date = _ymd(now);
    final time = _hms(now);
    final amzDate = '${date}T${time}Z';
    final scope = '$date/${AwsConfig.region}/s3/aws4_request';

    final usePath = AwsConfig.bucket.contains('.');
    final host = usePath
        ? 's3.${AwsConfig.region}.amazonaws.com'
        : '${AwsConfig.bucket}.s3.${AwsConfig.region}.amazonaws.com';

    // Encode each path segment
    String encPath(String s) => s.split('/').map(Uri.encodeComponent).join('/');

    final canonicalUri =
        usePath ? '/${encPath(AwsConfig.bucket)}/${encPath(objectKey)}' : '/${encPath(objectKey)}';

    // Base query params
    final params = <String, String>{
      'X-Amz-Algorithm': 'AWS4-HMAC-SHA256',
      'X-Amz-Credential': '${AwsConfig.accessKey}/$scope',
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': '3600',
      'X-Amz-SignedHeaders': 'host',
    };

    // Add session token if temporary credentials are used
    final sessionToken = (AwsConfig.sessionToken ?? '').trim();
    if (sessionToken.isNotEmpty) {
      params['X-Amz-Security-Token'] = sessionToken;
    }

    // Canonical query string: keys sorted ascending, values URL-encoded
    final keys = params.keys.toList()..sort();
    final canonicalQuery = keys
        .map((k) =>
            '${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(params[k]!.trim())}')
        .join('&');

    final canonicalHeaders = 'host:$host\n';
    const signedHeaders = 'host';
    const payloadHash = 'UNSIGNED-PAYLOAD'; // required for presigned URL

    final canonicalRequest = [
      'GET',
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');

    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');

    // Derive signing key
    final kSecret = Uint8List.fromList(('AWS4${AwsConfig.secretKey}').codeUnits);
    final kDate = _hmacSha256(kSecret, date);
    final kRegion = _hmacSha256(kDate, AwsConfig.region);
    final kService = _hmacSha256(kRegion, 's3');
    final kSigning = _hmacSha256(kService, 'aws4_request');

    // Signature
    final signature = _hmacSha256(kSigning, stringToSign)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final url =
        'https://$host$canonicalUri?$canonicalQuery&X-Amz-Signature=$signature';
    return url;
  }

  /// ---- Helpers -----------------------------------------------------------

  static Uint8List _hmacSha256(List<int> key, String message) {
    final hmacSha = Hmac(sha256, key);
    return Uint8List.fromList(hmacSha.convert(utf8.encode(message)).bytes);
  }

  static String _ymd(DateTime dt) =>
      '${dt.year}${_2(dt.month)}${_2(dt.day)}';

  static String _hms(DateTime dt) =>
      '${_2(dt.hour)}${_2(dt.minute)}${_2(dt.second)}';

  static String _2(int n) => n.toString().padLeft(2, '0');
}
