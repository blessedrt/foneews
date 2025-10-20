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
