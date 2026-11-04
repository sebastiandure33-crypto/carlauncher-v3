class Gps {
  const Gps({required this.speed, required this.lat, required this.lon, required this.bearing, required this.at});
  final double speed, lat, lon, bearing;
  final DateTime at;

  /// Sin lecturas en 8 s se considera "sin GPS" (túnel, techo, antena).
  bool get fresh => DateTime.now().difference(at).inSeconds < 8;
}

class Trip {
  const Trip({this.km = 0, this.minutes = 0, this.avg = 0});
  final double km;
  final int minutes;
  final double avg;
}

class Session {
  const Session({
    required this.pkg,
    required this.label,
    required this.title,
    required this.artist,
    required this.album,
    required this.playing,
    required this.pos,
    required this.posAt,
    required this.speed,
    required this.dur,
    required this.canSeek,
    required this.artKey,
  });

  final String pkg, label, title, artist, album;
  final bool playing, canSeek;
  final int pos, posAt, dur;
  final double speed;
  final String? artKey;

  factory Session.from(Map m) => Session(
        pkg: m['pkg'] as String? ?? '',
        label: m['label'] as String? ?? '',
        title: m['title'] as String? ?? '',
        artist: m['artist'] as String? ?? '',
        album: m['album'] as String? ?? '',
        playing: m['playing'] as bool? ?? false,
        pos: (m['pos'] as num?)?.toInt() ?? 0,
        posAt: (m['posAt'] as num?)?.toInt() ?? 0,
        speed: (m['speed'] as num?)?.toDouble() ?? 1,
        dur: (m['dur'] as num?)?.toInt() ?? 0,
        canSeek: m['canSeek'] as bool? ?? false,
        artKey: m['artKey'] as String?,
      );

  /// Posición estimada ahora (entre una actualización y otra de la app).
  int positionNow() {
    var p = pos;
    if (playing && posAt > 0) p += ((DateTime.now().millisecondsSinceEpoch - posAt) * speed).round();
    if (dur > 0) return p.clamp(0, dur).toInt();
    return p < 0 ? 0 : p;
  }
}

class MediaState {
  const MediaState({this.permission = true, this.sessions = const [], this.current});
  final bool permission;
  final List<Session> sessions;
  final String? current;

  Session? get now {
    for (final s in sessions) {
      if (s.pkg == current) return s;
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  Session? forPkg(String? pkg) {
    if (pkg == null) return null;
    for (final s in sessions) {
      if (s.pkg == pkg) return s;
    }
    return null;
  }
}

class NavInfo {
  const NavInfo({required this.app, required this.dist, required this.maneuver, required this.street, required this.eta});
  final String app, dist, maneuver, street, eta;
}

class BtInfo {
  const BtInfo({this.available = false, this.on = false, this.name, this.audio = false, this.calls = false, this.battery = -1, this.appText});
  final bool available, on, audio, calls;
  final String? name;
  final int battery;

  /// Aviso de la app Bluetooth propia de la radio (cuando Android no ve el teléfono).
  final String? appText;

  bool get connected => name != null && name!.isNotEmpty;

  /// Hay algo que mostrar sobre la conexión (Android o la app de la radio).
  bool get known => connected || (appText != null && appText!.isNotEmpty);

  String get title => connected ? name! : (appText?.split(' · ').first ?? 'Bluetooth de la radio');

  factory BtInfo.from(Map m) => BtInfo(
        available: m['available'] as bool? ?? false,
        on: m['on'] as bool? ?? false,
        name: m['name'] as String?,
        audio: m['audio'] as bool? ?? false,
        calls: m['calls'] as bool? ?? false,
        battery: (m['battery'] as num?)?.toInt() ?? -1,
        appText: m['appText'] as String?,
      );
}

class Weather {
  const Weather({
    required this.temp,
    required this.code,
    required this.max,
    required this.min,
    required this.humidity,
    required this.wind,
    required this.at,
  });
  final int temp, code, max, min, humidity, wind;
  final DateTime at;

  String get description {
    final c = code;
    if (c == 0) return 'Despejado';
    if (c <= 2) return 'Parcialmente nublado';
    if (c == 3) return 'Nublado';
    if (c == 45 || c == 48) return 'Niebla';
    if (c >= 51 && c <= 67) return 'Lluvia';
    if (c >= 71 && c <= 77) return 'Nieve';
    if (c >= 80 && c <= 82) return 'Chubascos';
    if (c >= 95) return 'Tormenta';
    return 'Variable';
  }

  /// "hace 2 h" cuando viene de la memoria (sin internet).
  String? get ago {
    final m = DateTime.now().difference(at).inMinutes;
    if (m < 30) return null;
    if (m < 60) return 'hace $m min';
    if (m < 48 * 60) return 'hace ${m ~/ 60} h';
    return 'hace ${m ~/ 1440} días';
  }

  Map<String, Object> toJson() =>
      {'temp': temp, 'code': code, 'max': max, 'min': min, 'hum': humidity, 'wind': wind, 'at': at.millisecondsSinceEpoch};

  factory Weather.fromJson(Map m) => Weather(
        temp: (m['temp'] as num).toInt(),
        code: (m['code'] as num).toInt(),
        max: (m['max'] as num).toInt(),
        min: (m['min'] as num).toInt(),
        humidity: (m['hum'] as num).toInt(),
        wind: (m['wind'] as num).toInt(),
        at: DateTime.fromMillisecondsSinceEpoch((m['at'] as num).toInt()),
      );
}
