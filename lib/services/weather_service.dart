import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class WeatherNow {
  final int tempC; final String condition;
  WeatherNow(this.tempC, this.condition);
}

class WeatherService {
  static Future<WeatherNow> current(double lat, double lon) async {
    if (AppConfig.mockMode) return WeatherNow(22, 'Partly Cloudy (Demo)');
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather'
      '?lat=$lat&lon=$lon&units=metric&appid=${AppConfig.openWeatherKey}');
    final resp = await http.get(url);
    if (resp.statusCode != 200) return WeatherNow(21, 'Clear (fallback)');
    final j = json.decode(resp.body);
    return WeatherNow(j['main']['temp'].round(), j['weather'][0]['main']);
  }
}
