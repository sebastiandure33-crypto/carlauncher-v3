import 'dart:math' as math;

/// Salida y puesta del sol (cálculo NOAA simplificado, funciona sin internet).
class Sun {
  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
  static double _norm(double v, double m) {
    var x = v % m;
    if (x < 0) x += m;
    return x;
  }

  static double? _utcHours(int dayOfYear, double lat, double lon, bool rising) {
    final lngHour = lon / 15.0;
    final t = dayOfYear + ((rising ? 6.0 : 18.0) - lngHour) / 24.0;
    final m = 0.9856 * t - 3.289;
    final l = _norm(m + 1.916 * math.sin(_rad(m)) + 0.020 * math.sin(_rad(2 * m)) + 282.634, 360);
    var ra = _norm(_deg(math.atan(0.91764 * math.tan(_rad(l)))), 360);
    ra += (l / 90).floor() * 90 - (ra / 90).floor() * 90;
    ra /= 15;
    final sinDec = 0.39782 * math.sin(_rad(l));
    final cosDec = math.cos(math.asin(sinDec));
    final cosH = (math.cos(_rad(90.833)) - sinDec * math.sin(_rad(lat))) / (cosDec * math.cos(_rad(lat)));
    if (cosH > 1 || cosH < -1) return null;
    final h = (rising ? 360 - _deg(math.acos(cosH)) : _deg(math.acos(cosH))) / 15;
    final tt = h + ra - 0.06571 * t - 6.622;
    return _norm(tt - lngHour, 24);
  }

  /// (amanecer, atardecer) en hora local para el día de [day].
  static (DateTime, DateTime)? times(double lat, double lon, DateTime day) {
    final doy = day.difference(DateTime(day.year, 1, 1)).inDays + 1;
    final r = _utcHours(doy, lat, lon, true);
    final s = _utcHours(doy, lat, lon, false);
    if (r == null || s == null) return null;
    final base = DateTime.utc(day.year, day.month, day.day);
    final noon = DateTime(day.year, day.month, day.day, 12);
    DateTime fix(double hours) {
      var x = base.add(Duration(milliseconds: (hours * 3600000).round())).toLocal();
      while (x.difference(noon).inHours > 12) {
        x = x.subtract(const Duration(days: 1));
      }
      while (noon.difference(x).inHours > 12) {
        x = x.add(const Duration(days: 1));
      }
      return x;
    }

    return (fix(r), fix(s));
  }

  static bool isNight(double lat, double lon, DateTime now) {
    final t = times(lat, lon, now);
    if (t == null) return now.hour >= 19 || now.hour < 7;
    return now.isBefore(t.$1) || !now.isBefore(t.$2);
  }
}
