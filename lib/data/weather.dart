import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Clima de Open-Meteo (gratis, sin clave). Sin internet se muestra el último guardado.
class WeatherRepo {
  WeatherRepo(this.sp);
  final SharedPreferences sp;

  Weather? cached() {
    final s = sp.getString('wx');
    if (s == null) return null;
    try {
      return Weather.fromJson(jsonDecode(s) as Map);
    } catch (_) {
      return null;
    }
  }

  bool get stale {
    final c = cached();
    return c == null || DateTime.now().difference(c.at).inMinutes >= 15;
  }

  Future<Weather?> fetch(double lat, double lon) async {
    try {
      final u = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
          '&daily=temperature_2m_max,temperature_2m_min&timezone=auto');
      final r = await http.get(u).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map;
      final cur = j['current'] as Map;
      final d = j['daily'] as Map;
      final w = Weather(
        temp: (cur['temperature_2m'] as num).round(),
        code: (cur['weather_code'] as num).toInt(),
        max: ((d['temperature_2m_max'] as List).first as num).round(),
        min: ((d['temperature_2m_min'] as List).first as num).round(),
        humidity: (cur['relative_humidity_2m'] as num).round(),
        wind: (cur['wind_speed_10m'] as num).round(),
        at: DateTime.now(),
      );
      await sp.setString('wx', jsonEncode(w.toJson()));
      return w;
    } catch (_) {
      return null;
    }
  }
}
