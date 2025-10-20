import 'package:wifi_iot/wifi_iot.dart';
class WifiSvc {
  static Future<bool> connectEws() async => WiFiForIoTPlugin.connect("EWS", joinOnce: true, security: NetworkSecurity.NONE);
}
