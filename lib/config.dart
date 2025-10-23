class AppConfig {
  static const mockMode = false; // turn false for live
  // Keys (replace in live)
  static const openWeatherKey = 'f283ad89a196df89ddfe3d1db95b5125';
  static const mapsApiKey = 'AIzaSyCsXYUkTuzzVYPmmKABRC34jbtwnio3ct8';
  static const mapsApiKeyDev = 'AIzaSyCsXYUkTuzzVYPmmKABRC34jbtwnio3ct8';
  // MQTT
  static const mqttUrl = 'ssl://j928e843.ala.asia-southeast1.emqxsl.com:8883';
  static const topicSOS = 'EWS-SOS';
  static const topicSafeTrack = 'EWS-1';
  // Broadwick AES-256-ECB key
  static const aesKey = 'n>dbe-%.sv#unhkI9fS%Zp+eKbkCG{4#';
}

class SecurityConfig {
  // These values should be configured in your CI/CD pipeline
  static const String polygonKeyBase64 = 'n>dbe-%.sv#unhkI9fS%Zp+eKbkCG{4#';
  
  static const String MQTT_USERNAME = 'EWS-1';
  static const String MQTT_PASSWORD = 'sdvfesr8xcnvfx';
  
  static const String MQTT_BROKER = 'j928e843.ala.asia-southeast1.emqxsl.com';
  
  static const int MQTT_PORT = 8883;
}

class AwsConfig {
  // These values should be configured in your CI/CD pipeline
  static const String region = 'ap-southeast-1';
    
  static const String bucket = 'ews.receiver';
    
  // AWS Credentials - DO NOT commit actual values
  static const String accessKey = 'AKIA3BEODKBESQFVTO5U';
  static const String secretKey = '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';

  static get sessionToken => null;
}
