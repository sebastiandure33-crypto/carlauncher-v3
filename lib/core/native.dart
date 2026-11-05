import 'package:flutter/foundation.dart';
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

  /// Nunca deja la pantalla esperando: si Android no contesta a tiempo devuelve null.
  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    final slow = method == 'probe' || method == 'diag' || method == 'apps' || method == 'appIcon' || method == 'mediaArt' || method == 'requestLocation';
    try {
      final f = _m.invokeMethod<T>(method, args);
      return slow && method == 'requestLocation' ? await f : await f.timeout(Duration(seconds: slow ? 20 : 4));
    } catch (e) {
      debugPrint('CL4 native $method: $e');
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

  /// Devuelve el volumen que quedó realmente (la radio puede ignorar el cambio).
  static Future<int?> setVolume(int v) => _call<int>('setVolume', {'v': v});

  /// Sube (+1) o baja (-1) un paso, como las teclas de volumen.
  static Future<(int, int)?> volumeStep(int dir) async {
    final r = await _call<Map<Object?, Object?>>('volumeStep', {'dir': dir});
    if (r == null) return null;
    return ((r['cur'] as int?) ?? 0, (r['max'] as int?) ?? 15);
  }

  static Future<int> brightness() async => (await _call<int>('brightness')) ?? -1;

  /// "system" (toda la radio), "window" (solo el launcher, falta permiso) o "none".
  static Future<String> setBrightness(int v) async => (await _call<String>('setBrightness', {'v': v})) ?? 'none';

  /// Abre la app y a los [delayMs] vuelve al launcher (el audio sigue de fondo).
  static Future<bool> launchReturn(String? pkg, {int delayMs = 2000}) =>
      pkg == null ? Future.value(false) : _bool('launchReturn', {'pkg': pkg, 'delay': delayMs});

  static Future<List<String>> diag(List<String> pkgs) async =>
      [for (final e in (await _call<List<Object?>>('diag', {'pkgs': pkgs})) ?? const []) '$e'];

  /// Prueba un botón de música con un modo puntual. Devuelve por dónde salió.
  static Future<String> mediaTest(String cmd, int mode, String? pkg) async =>
      (await _call<String>('mediaTest', {'cmd': cmd, 'mode': mode, 'pkg': pkg})) ?? '—';

  /// Textos del código de la app que parecen órdenes (para probarlas una por una).
  static Future<List<String>> probe(String pkg) async =>
      [for (final e in (await _call<List<Object?>>('probe', {'pkg': pkg})) ?? const []) '$e'];
  static Future<void> sendAction(String action, String? pkg) => _call('sendAction', {'action': action, 'pkg': pkg});
  static Future<Map<String, String?>> customActions(String pkg) async {
    final r = await _call<Map<Object?, Object?>>('customActions', {'pkg': pkg}) ?? const {};
    return {for (final e in r.entries) '${e.key}': e.value as String?};
  }

  static Future<void> setCustomAction(String pkg, String cmd, String? action) =>
      _call('setCustomAction', {'pkg': pkg, 'cmd': cmd, 'action': action});

  /// Apps cuyo aviso se lee (para saber a qué teléfono se conectó la radio).
  static Future<void> watch(List<String> pkgs, {String? music}) => _call('watch', {'pkgs': pkgs, 'music': music});
  static Future<Map<Object?, Object?>?> btInfo() => _call<Map<Object?, Object?>>('btInfo');
  static Future<Map<Object?, Object?>?> wifiInfo() => _call<Map<Object?, Object?>>('wifiInfo');
  static Future<String?> filesDir() => _call<String>('filesDir');
  static Future<void> setIgnOpen(bool v) => _call('setIgnOpen', {'v': v});
}
