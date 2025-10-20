import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import '../config.dart';

class S3Service {
  static String _generateSignedUrl(String objectKey) {
    final now = DateTime.now().toUtc();
    final dateStamp = now.toIso8601String().split('T')[0].replaceAll('-', '');
    final amzDate = '${dateStamp}T${now.toIso8601String().split('T')[1].replaceAll(':', '').split('.')[0]}Z';
    
    final credentialScope = '$dateStamp/${AwsConfig.region}/s3/aws4_request';
    
    // Create canonical request
    final canonicalUri = '/${AwsConfig.bucket}/$objectKey';
    final canonicalQueryString = 'X-Amz-Algorithm=AWS4-HMAC-SHA256' +
        '&X-Amz-Credential=${Uri.encodeComponent('${AwsConfig.accessKey}/$credentialScope')}' +
        '&X-Amz-Date=$amzDate' +
        '&X-Amz-Expires=3600' +
        '&X-Amz-SignedHeaders=host';

    final canonicalHeaders = 'host:${AwsConfig.bucket}.s3.${AwsConfig.region}.amazonaws.com\n';
    const signedHeaders = 'host';
    
    final payloadHash = sha256.convert(utf8.encode('')).toString();
    
    final canonicalRequest = 'GET\n$canonicalUri\n$canonicalQueryString\n$canonicalHeaders\n$signedHeaders\n$payloadHash';

    // Create string to sign
    final stringToSign = 'AWS4-HMAC-SHA256\n$amzDate\n$credentialScope\n${sha256.convert(utf8.encode(canonicalRequest))}';

    // Calculate signature
    final kDate = _hmacSha256(utf8.encode('AWS4${AwsConfig.secretKey}'), dateStamp);
    final kRegion = _hmacSha256(kDate, AwsConfig.region);
    final kService = _hmacSha256(kRegion, 's3');
    final kSigning = _hmacSha256(kService, 'aws4_request');
    final signature = _hmacSha256(kSigning, stringToSign).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

    // Create signed URL
    return 'https://${AwsConfig.bucket}.s3.${AwsConfig.region}.amazonaws.com/$objectKey?$canonicalQueryString&X-Amz-Signature=$signature';
  }

  static List<int> _hmacSha256(List<int> key, String message) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(message)).bytes;
  }

  static Future<String?> downloadAudioFile(String s3key) async {
    try {
      // Add random prefix (0-9)
      final prefix = Random().nextInt(10);
      final filename = 'BROADWICK EWS ${DateTime.now().toIso8601String()}.mp3';
      
      // Get signed URL
      final url = _generateSignedUrl('$prefix$s3key');
      
      // Download with timeout
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode != 200) {
        throw 'Download failed: ${response.statusCode}';
      }
      
      // Save to local storage
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      
      return file.path;
    } catch (e) {
      print('S3 download failed: $e');
      return null;
    }
  }

  // Clean up old files periodically
  static Future<void> cleanupOldFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.contains('BROADWICK EWS'));
          
      for (final file in files) {
        final stat = await file.stat();
        final age = DateTime.now().difference(stat.modified);
        
        // Delete files older than 24 hours
        if (age > const Duration(hours: 24)) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Cleanup failed: $e');
    }
  }
}