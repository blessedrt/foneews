// lib/main.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:foneews/config.dart';
import 'app_theme.dart';
import 'features/dashboard/dashboard_page.dart';
import 'services/notifications_service.dart';
import 'services/fcm_service.dart';
import 'services/wifi_service.dart';
import 'services/s3_service.dart';

void main() {
  // Catch any early errors so they don't kill first frame
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint('════════════════════════════════════════');
    debugPrint('🚀 STARTING FOneEWS APP');
    debugPrint('════════════════════════════════════════');
    debugPrint('📅 Start time: ${DateTime.now()}');
    debugPrint('📱 Platform: ${Platform.operatingSystem}');
    debugPrint('🏗️ Debug mode: ${kDebugMode}');

    // Initialize Firebase (using manual config from google-services.json / GoogleService-Info.plist)
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        debugPrint('🔥 Initializing Firebase...');
        final stopwatch = Stopwatch()..start();
        await Firebase.initializeApp();
        stopwatch.stop();
        debugPrint('✅ Firebase initialized successfully (${stopwatch.elapsedMilliseconds}ms)');
      }
    } catch (e, st) {
      debugPrint('❌ Firebase initialization failed: $e');
      debugPrint('📍 Stack trace: $st');
    }

    // Show UI immediately
    runApp(const FOneEWS());

    // Initialize services AFTER first frame with enhanced debugging
    scheduleMicrotask(() async {
      debugPrint('');
      debugPrint('════════════════════════════════════════');
      debugPrint('🔧 INITIALIZING SERVICES');
      debugPrint('════════════════════════════════════════');
      
      try {
        // Initialize notifications
        debugPrint('');
        debugPrint('1️⃣ NOTIFICATION SERVICE');
        debugPrint('─────────────────────────');
        final notiStopwatch = Stopwatch()..start();
        await Noti.init();
        notiStopwatch.stop();
        debugPrint('✅ Notifications initialized (${notiStopwatch.elapsedMilliseconds}ms)');
        
        // Check notification permissions
        try {
          // Note: This assumes you have a hasPermission method in Noti
          // If not, this will be skipped
          debugPrint('🔐 Checking notification permissions...');
          // final hasPermission = await Noti.hasPermission();
          // debugPrint('   Permission status: ${hasPermission ? "✅ Granted" : "❌ Denied"}');
        } catch (e) {
          debugPrint('   Permission check not available');
        }

        // Test S3 connection
        debugPrint('');
        debugPrint('2️⃣ S3 SERVICE TEST');
        debugPrint('─────────────────────────');
        debugPrint('🔌 Testing S3 connection...');
        debugPrint('   Region: ${AwsConfig.region}');
        debugPrint('   Bucket: ${AwsConfig.bucket}');
        debugPrint('   Access Key: ${AwsConfig.accessKey.substring(0, 10)}...');
        
        final s3Stopwatch = Stopwatch()..start();
        try {
          final s3Connected = await S3Service.testConnection()
              .timeout(const Duration(seconds: 10), onTimeout: () {
                debugPrint('   ⏱️ S3 test timeout after 10 seconds');
                return false;
              });
          s3Stopwatch.stop();
          
          if (s3Connected) {
            debugPrint('✅ S3 connection successful (${s3Stopwatch.elapsedMilliseconds}ms)');
            debugPrint('   ✓ AWS credentials are valid');
            debugPrint('   ✓ Bucket is accessible');
            debugPrint('   ✓ Ready to download messages');
          } else {
            debugPrint('❌ S3 connection FAILED (${s3Stopwatch.elapsedMilliseconds}ms)');
            debugPrint('   ⚠️ Check AWS credentials in config.dart');
            debugPrint('   ⚠️ Verify bucket name and region');
            debugPrint('   ⚠️ Messages WILL NOT be downloadable');
          }
        } catch (e) {
          debugPrint('❌ S3 test error: $e');
          debugPrint('   ⚠️ S3 service may not work properly');
        }

        // Initialize FCM with enhanced debugging
        debugPrint('');
        debugPrint('3️⃣ FCM SERVICE (Push Notifications)');
        debugPrint('─────────────────────────');
        final fcmStopwatch = Stopwatch()..start();
        
        // Add temporary debug wrapper for FCM
        try {
          await FcmService.init();
          fcmStopwatch.stop();
          debugPrint('✅ FCM initialized (${fcmStopwatch.elapsedMilliseconds}ms)');
          
          // Log FCM readiness
          debugPrint('   ✓ Push notifications ready');
          debugPrint('   ✓ Background handler registered');
          debugPrint('   ✓ Message listeners active');
          
        } catch (e, st) {
          fcmStopwatch.stop();
          debugPrint('❌ FCM initialization failed (${fcmStopwatch.elapsedMilliseconds}ms)');
          debugPrint('   Error: $e');
          debugPrint('   ⚠️ Push notifications will NOT work');
          debugPrint('   Stack: $st');
        }

        // Initialize WiFi service
        debugPrint('');
        debugPrint('4️⃣ WIFI SERVICE');
        debugPrint('─────────────────────────');
        final wifiStopwatch = Stopwatch()..start();
        await WiFiService.initialize();
        wifiStopwatch.stop();
        debugPrint('✅ WiFi service initialized (${wifiStopwatch.elapsedMilliseconds}ms)');

        // Service initialization complete
        debugPrint('');
        debugPrint('════════════════════════════════════════');
        debugPrint('✅ SERVICE INITIALIZATION COMPLETE');
        debugPrint('════════════════════════════════════════');
        debugPrint('');
        
        // Add message reception test info
        debugPrint('📱 MESSAGE RECEPTION DEBUGGING:');
        debugPrint('────────────────────────────────');
        debugPrint('To test message reception:');
        debugPrint('1. Send a test FCM message with:');
        debugPrint('   {');
        debugPrint('     "messageId": "test123",');
        debugPrint('     "s3key": "your-test-audio.mp3",');
        debugPrint('     "priority": "2",');
        debugPrint('     "polygon": "optional-encrypted-polygon"');
        debugPrint('   }');
        debugPrint('2. Watch console for processing steps');
        debugPrint('3. Look for these key indicators:');
        debugPrint('   🔔 "Foreground/Background message received"');
        debugPrint('   📥 "Downloading audio from S3"');
        debugPrint('   ✅ "Audio downloaded successfully"');
        debugPrint('   🔊 "Alert sound played"');
        debugPrint('');
        
        // Add S3 debugging info
        debugPrint('🪣 S3 DEBUGGING:');
        debugPrint('────────────────────────────────');
        debugPrint('Common S3 issues:');
        debugPrint('1. 403 Forbidden = Invalid credentials or permissions');
        debugPrint('2. 404 Not Found = File doesn\'t exist in bucket');
        debugPrint('3. Timeout = Network or region issue');
        debugPrint('4. Empty response = Bucket policy blocking access');
        debugPrint('');
        debugPrint('Your S3 URL format will be:');
        debugPrint('https://${AwsConfig.bucket}.s3.${AwsConfig.region}.amazonaws.com/[s3key]');
        debugPrint('');
        
        // Clean up old files
        try {
          debugPrint('🗑️ Cleaning up old audio files...');
          await S3Service.cleanupOldFiles();
          debugPrint('✅ Cleanup complete');
        } catch (e) {
          debugPrint('⚠️ Cleanup failed: $e');
        }

      } catch (e, st) {
        debugPrint('');
        debugPrint('════════════════════════════════════════');
        debugPrint('❌ CRITICAL SERVICE ERROR');
        debugPrint('════════════════════════════════════════');
        debugPrint('Error: $e');
        debugPrint('Stack: $st');
      }
    });
    
  }, (e, st) {
    debugPrint('════════════════════════════════════════');
    debugPrint('🔴 UNHANDLED ERROR');
    debugPrint('════════════════════════════════════════');
    debugPrint('Error: $e');
    debugPrint('Stack: $st');
    debugPrint('════════════════════════════════════════');
  });
}

class FOneEWS extends StatelessWidget {
  const FOneEWS({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FOneEWS',
      theme: appThemeDark(),
      debugShowCheckedModeBanner: false,
      home: const DashboardPage(),
    );
  }
}

// Debug helper class for testing
class MessageDebugger {
  static void logMessageReceived(Map<String, dynamic> data) {
    debugPrint('');
    debugPrint('╔══════════════════════════════════════╗');
    debugPrint('║     📨 NEW MESSAGE RECEIVED          ║');
    debugPrint('╚══════════════════════════════════════╝');
    debugPrint('Timestamp: ${DateTime.now()}');
    debugPrint('Message data:');
    data.forEach((key, value) {
      debugPrint('  $key: $value');
    });
    debugPrint('────────────────────────────────────────');
  }
  
  static void logS3Download(String s3key, String status) {
    debugPrint('');
    debugPrint('🪣 S3 DOWNLOAD:');
    debugPrint('  Key: $s3key');
    debugPrint('  Status: $status');
    debugPrint('  Time: ${DateTime.now()}');
    debugPrint('────────────────────────────────────────');
  }
  
  static void logGeofenceCheck(bool? result) {
    debugPrint('');
    debugPrint('🗺️ GEOFENCE CHECK:');
    debugPrint('  Result: ${result == null ? "No polygon" : result ? "Inside" : "Outside"}');
    debugPrint('  Time: ${DateTime.now()}');
    debugPrint('────────────────────────────────────────');
  }
  
  static void logNotificationShown(String title) {
    debugPrint('');
    debugPrint('🔔 NOTIFICATION:');
    debugPrint('  Title: $title');
    debugPrint('  Time: ${DateTime.now()}');
    debugPrint('────────────────────────────────────────');
  }
}