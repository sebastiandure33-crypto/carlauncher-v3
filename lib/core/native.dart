import 'package:flutter/services.dart';

class AppEntry {
  const AppEntry(this.pkg, this.label);
  final String pkg;
  final String label;
}

/// Llamadas a la parte Android (MainActivity.kt).
class Native {
  static const _m = MethodChannel('cl4/native');
  static const gpsEvents = EventChannel('cl4/gps');
  static const navEvents = EventChannel('cl4/nav');
  static const mediaEvents = EventChannel('cl4/media');
  static const btEvents = EventChannel('cl4/bt');

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _m.invokeMethod<T>(method, args);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _bool(String m, [Map<String, Object?>? a]) async => (await _call<bool>(m, a)) ?? false;

  static Future<bool> hasLocation() => _bool('hasLocation');
  static Future<bool> requestLocation() => _bool('requestLocation');
  static Future<bool> hasNotifAccess() => _bool('hasNotifAccess');
  static Future<bool> canWriteSettings() => _bool('canWriteSettings');
  static Future<bool> canOverlay() => _bool('canOverlay');
  static Future<bool> isDefaultHome() => _bool('isDefaultHome');

  static Future<Map<Object?, Object?>?> trip() => _call<Map<Object?, Object?>>('trip');
  static Future<void> setOdo(double km) => _call('setOdo', {'km': km});
  static Future<void> resetTrip() => _call('resetTrip');

  static Future<List<AppEntry>> apps() async {
    final r = await _call<List<Object?>>('apps') ?? const [];
    return [
      for (final e in r)
        if (e is Map) AppEntry(e['pkg'] as String, e['label'] as String),
    ];
  }

  static Future<Uint8List?> appIcon(String pkg) => _call<Uint8List>('appIcon', {'pkg': pkg});
  static Future<String?> appLabel(String pkg) => _call<String>('appLabel', {'pkg': pkg});
  static Future<bool> launch(String? pkg) => pkg == null ? Future.value(false) : _bool('launch', {'pkg': pkg});

  /// bt, wifi, android, home, notif, write, overlay, location, appInfo, eq
  static Future<bool> open(String what) => _bool('open', {'what': what});
  static Future<bool> navigate(double lat, double lon, String? pkg) =>
      _bool('navigate', {'lat': lat, 'lon': lon, 'pkg': pkg});
  static Future<bool> openNav() => _bool('openNav');

  /// cmd: toggle, play, pause, next, prev, seek
  static Future<void> media(String cmd, {String? pkg, int? pos}) =>
      _call('media', {'cmd': cmd, 'pkg': pkg, 'pos': pos});
  static Future<Uint8List?> mediaArt(String? pkg) => _call<Uint8List>('mediaArt', {'pkg': pkg});
  static Future<void> mediaRefresh() => _call('mediaRefresh');
  static Future<void> setMediaMode(int mode) => _call('setMediaMode', {'mode': mode});

  static Future<(int, int)> volume() async {
    final r = await _call<Map<Object?, Object?>>('volume');
    return ((r?['cur'] as int?) ?? 0, (r?['max'] as int?) ?? 15);
  }

  static Future<void> setVolume(int v) => _call('setVolume', {'v': v});
  static Future<int> brightness() async => (await _call<int>('brightness')) ?? -1;
  static Future<bool> setBrightness(int v) => _bool('setBrightness', {'v': v});
  static Future<Map<Object?, Object?>?> btInfo() => _call<Map<Object?, Object?>>('btInfo');
  static Future<Map<Object?, Object?>?> wifiInfo() => _call<Map<Object?, Object?>>('wifiInfo');
  static Future<String?> filesDir() => _call<String>('filesDir');
  static Future<void> setIgnOpen(bool v) => _call('setIgnOpen', {'v': v});
}
