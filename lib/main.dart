// lib/main.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'features/dashboard/dashboard_page.dart';
// Leave Firebase out unless you've configured it:
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
import 'services/notifications_service.dart';
import 'services/fcm_service.dart';

void main() {
  // Catch any early errors so they don't kill first frame
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();

    // ✅ Show UI immediately (do NOT await anything here)
    runApp(const FOneEWS());

    // Initialize services AFTER first frame so splash never blocks
    scheduleMicrotask(() async {
      try {
        await Noti.init();
        // If you haven't run `flutterfire configure`, skip Firebase init:
        // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        await FcmService.safeInit(); // tolerant init (doesn't throw)
      } catch (e, st) {
        debugPrint('Warmup init skipped: $e\n$st');
      }
    });
  }, (e, st) {
    debugPrint('Zoned error: $e\n$st');
  });
}

class FOneEWS extends StatelessWidget {
  const FOneEWS({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: appThemeDark(),
      debugShowCheckedModeBanner: false,
      home: const DashboardPage(),
    );
  }
}
