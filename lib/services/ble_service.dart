import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static Future<void> scanOnce() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    // filter devices; connect & read chunks until "THEEND"
    await FlutterBluePlus.stopScan();
  }
}
