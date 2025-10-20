class AppConfig {
  static const mockMode = false; // turn false for live
  // Keys (replace in live)
  static const openWeatherKey = 'f283ad89a196df89ddfe3d1db95b5125';
  static const mapsApiKey = 'AIzaSyCsXYUkTuzzVYPmmKABRC34jbtwnio3ct8';
  // MQTT
  static const mqttUrl = 'ssl://test.mosquitto.org:8883';
  static const topicSOS = 'EWS-SOS';
  static const topicSafeTrack = 'EWS-1';
  // Broadwick AES-256-ECB key
  static const aesKey = 'n>dbe-%.sv#unhkI9fS%Zp+eKbkCG{4#';
}

class SecurityConfig {
  // These values should be configured in your CI/CD pipeline
  static const String POLYGON_KEY = String.fromEnvironment('POLYGON_KEY', 
    defaultValue: 'n>dbe-%.sv#unhkI9fS%Zp+eKbkCG{4#');
  
  static const String REGISTRATION_KEY = String.fromEnvironment('REGISTRATION_KEY',
    defaultValue: 'test_registration_key_32chars_here__');
  
  static const String MQTT_BROKER = String.fromEnvironment('MQTT_BROKER',
    defaultValue: 'test.mosquitto.org');
  
  static const int MQTT_PORT = int.fromEnvironment('MQTT_PORT',
    defaultValue: 8883);
}

class AwsConfig {
  // These values should be configured in your CI/CD pipeline
  static const String region = 'ap-southeast-1';
    
  static const String bucket = 'ews.receiver';
    
  // AWS Credentials - DO NOT commit actual values
  static const String accessKey = 'AAKIA3BEODKBESQFVTO5U';
  static const String secretKey = '7B4bvnlTjM/Tw9me3w0HcqNtDXERv/zrGVJIODfq';
}
