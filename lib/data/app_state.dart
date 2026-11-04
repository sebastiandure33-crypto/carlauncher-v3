import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/native.dart';
import 'maintenance.dart';
import 'models.dart';
import 'navigation.dart';
import 'settings.dart';
import 'sun.dart';
import 'weather.dart';

class Perms {
  const Perms({this.location = true, this.notif = true, this.write = true, this.home = true, this.overlay = true});
  final bool location, notif, write, home, overlay;
}

class Wifi {
  const Wifi({this.on = false, this.connected = false, this.ssid});
  final bool on, connected;
  final String? ssid;
}

/// Todo el estado de la app. La interfaz solo escucha estos valores.
class App {
  App._();
  static final App i = App._();

  // Ubicación por defecto (zona de Asunción) hasta que el GPS dé la primera posición
  static const defLat = -25.35, defLon = -57.45;

  late final SharedPreferences sp;
  late final Settings settings;
  late final Maint maint;
  late final WeatherRepo _wx;
  late final Navi navi;

  final gps = ValueNotifier<Gps?>(null);
  final trip = ValueNotifier<Trip>(const Trip());
  final media = ValueNotifier<MediaState>(const MediaState());
  final nav = ValueNotifier<NavInfo?>(null);
  final bt = ValueNotifier<BtInfo>(const BtInfo());
  final wifi = ValueNotifier<Wifi>(const Wifi());
  final weather = ValueNotifier<Weather?>(null);
  final now = ValueNotifier<DateTime>(DateTime.now());
  final night = ValueNotifier<bool>(true);
  final perms = ValueNotifier<Perms>(const Perms());

  /// Volumen de la música (actual, máximo).
  final volume = ValueNotifier<(int, int)>((0, 15));

  /// La animación del holograma al abrir el launcher (se consume una vez).
  bool introPending = true;

  double lat = defLat, lon = defLon;
  String? filesDir;

  final _subs = <StreamSubscription<dynamic>>[];
  final _timers = <Timer>[];

  Future<void> init() async {
    sp = await SharedPreferences.getInstance();
    settings = Settings(sp);
    settings.addListener(() {
      if (_apps != null) _watchApps();
    });
    maint = Maint(sp);
    _wx = WeatherRepo(sp);
    navi = Navi(this);
    weather.value = _wx.cached();
    introPending = settings.intro;
    lat = sp.getDouble('lastLat') ?? defLat;
    lon = sp.getDouble('lastLon') ?? defLon;
    filesDir = await Native.filesDir();
    Native.setMediaMode(settings.mediaMode);
    Native.setIgnOpen(settings.ignOpen);

    _subs.add(Native.gpsEvents.receiveBroadcastStream().listen((e) {
      if (e is! Map || e['off'] == true) {
        gps.value = null;
        return;
      }
      gps.value = Gps(
        speed: (e['speed'] as num).toDouble(),
        lat: (e['lat'] as num).toDouble(),
        lon: (e['lon'] as num).toDouble(),
        bearing: (e['bearing'] as num).toDouble(),
        at: DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()),
      );
      lat = gps.value!.lat;
      lon = gps.value!.lon;
    }, onError: (_) {}));

    _subs.add(Native.navEvents.receiveBroadcastStream().listen((e) {
      if (e is! Map || e['none'] == true) {
        nav.value = null;
        return;
      }
      nav.value = NavInfo(
        app: e['app'] as String? ?? '',
        dist: e['dist'] as String? ?? '',
        maneuver: e['maneuver'] as String? ?? '',
        street: e['street'] as String? ?? '',
        eta: e['eta'] as String? ?? '',
      );
    }, onError: (_) {}));

    _subs.add(Native.mediaEvents.receiveBroadcastStream().listen((e) {
      if (e is! Map) return;
      final list = (e['sessions'] as List?) ?? const [];
      media.value = MediaState(
        permission: e['perm'] as bool? ?? false,
        sessions: [for (final s in list) if (s is Map) Session.from(s)],
        current: e['current'] as String?,
      );
    }, onError: (_) {}));

    _subs.add(Native.btEvents.receiveBroadcastStream().listen((e) {
      if (e is Map) bt.value = BtInfo.from(e);
    }, onError: (_) {}));

    settings.addListener(_updateNight);
    night.addListener(() => applyBrightness());

    _timers.add(Timer.periodic(const Duration(seconds: 5), (_) => _tick()));
    _timers.add(Timer.periodic(const Duration(minutes: 1), (_) => _slowTick()));
    await _tick();
    _slowTick();
    refreshPerms();
  }

  Future<void> _tick() async {
    now.value = DateTime.now();
    loadVolume();
    _updateNight();
    final g = gps.value;
    if (g != null && !g.fresh) gps.value = null;
    final t = await Native.trip();
    if (t != null) {
      trip.value = Trip(
        km: (t['tripKm'] as num?)?.toDouble() ?? 0,
        minutes: (t['tripMin'] as num?)?.toInt() ?? 0,
        avg: (t['avgKmh'] as num?)?.toDouble() ?? 0,
      );
      maint.updateOdo((t['odoKm'] as num?)?.toDouble());
      final la = (t['lat'] as num?)?.toDouble(), lo = (t['lon'] as num?)?.toDouble();
      if (la != null && lo != null && gps.value == null) {
        lat = la;
        lon = lo;
      }
    }
  }

  Future<void> _slowTick() async {
    await sp.setDouble('lastLat', lat);
    await sp.setDouble('lastLon', lon);
    if (_wx.stale) {
      final w = await _wx.fetch(lat, lon);
      if (w != null) weather.value = w;
    }
    final w = await Native.wifiInfo();
    if (w != null) wifi.value = Wifi(on: w['on'] == true, connected: w['connected'] == true, ssid: w['ssid'] as String?);
  }

  void _updateNight() {
    final mode = settings.theme;
    final n = switch (mode) {
      ThemeModeX.night => true,
      ThemeModeX.day => false,
      ThemeModeX.auto => Sun.isNight(lat, lon, DateTime.now()),
    };
    if (n != night.value) night.value = n;
  }

  (DateTime, DateTime)? sunTimes() => Sun.times(lat, lon, DateTime.now());

  Future<void> refreshPerms() async {
    perms.value = Perms(
      location: await Native.hasLocation(),
      notif: await Native.hasNotifAccess(),
      write: await Native.canWriteSettings(),
      home: await Native.isDefaultHome(),
      overlay: await Native.canOverlay(),
    );
    final b = await Native.btInfo();
    if (b != null) bt.value = BtInfo.from(b);
    Native.mediaRefresh();
  }

  /* ------------------------------------------------ apps e íconos */

  List<AppEntry>? _apps;
  final _icons = <String, Uint8List?>{};
  final _iconWait = <String, Future<Uint8List?>>{};

  Future<List<AppEntry>> apps({bool refresh = false}) async {
    if (_apps == null || refresh) {
      _apps = await Native.apps();
      _autodetect(_apps!);
    }
    return _apps!;
  }

  /// Busca solas las apps de Bluetooth, radio, USB, teléfono y ecualizador de la radio.
  void _autodetect(List<AppEntry> list) {
    if (list.isEmpty) return;
    final pkgs = {for (final a in list) a.pkg};
    final found = <Slot, String>{};
    for (final s in Slot.values) {
      final known = autoPackages[s] ?? const <String>[];
      final byPkg = known.where(pkgs.contains);
      if (byPkg.isNotEmpty) {
        found[s] = byPkg.first;
        continue;
      }
      final re = autoLabels[s];
      if (re == null) continue;
      for (final a in list) {
        if (re.hasMatch(a.label.trim())) {
          found[s] = a.pkg;
          break;
        }
      }
    }
    settings.setAuto(found);
    _watchApps();
  }

  void _watchApps() {
    final w = <String>{...autoPackages[Slot.music]!};
    for (final s in [Slot.music, Slot.phone, Slot.radio]) {
      final p = settings.slot(s);
      if (p != null) w.add(p);
    }
    Native.watch(w.toList());
  }

  /* ------------------------------------------------ brillo por modo */

  String lastBrightness = '';

  Future<String> applyBrightness() async {
    final v = settings.brightnessFor(night.value);
    lastBrightness = await Native.setBrightness((v * 255).round());
    return lastBrightness;
  }

  Future<String> setBrightness(double v) async {
    settings.setBrightnessFor(night.value, v); // el valor queda en memoria al instante
    lastBrightness = await Native.setBrightness((v * 255).round());
    return lastBrightness;
  }

  /* ------------------------------------------------ volumen */

  Future<void> loadVolume() async {
    final v = await Native.volume();
    if (v.$2 > 0) volume.value = v;
  }

  /// Cambia el volumen. Devuelve false si la radio no lo aceptó (lo maneja su perilla).
  Future<bool> setVolume(int v) async {
    final max = volume.value.$2;
    final want = v.clamp(0, max).toInt();
    volume.value = (want, max);
    final got = await Native.setVolume(want);
    if (got == null) return false;
    volume.value = (got, max);
    return got == want;
  }

  Future<bool> stepVolume(int dir) async {
    final before = volume.value.$1;
    final r = await Native.volumeStep(dir);
    if (r == null) return false;
    volume.value = r;
    return r.$1 != before || (dir > 0 ? r.$1 == r.$2 : r.$1 == 0);
  }

  /* ------------------------------------------------ reproducir */

  /// Play/pausa de una fuente. Si esa app no tiene sesión (no está abierta), la abre
  /// para que empiece a sonar y vuelve al launcher.
  Future<String> playSource(Slot s, {Session? session}) async {
    final pkg = session?.pkg ?? settings.slot(s);
    final has = session != null || media.value.forPkg(pkg) != null;
    if (has || pkg == null) {
      await Native.media('toggle', pkg: pkg);
      return pkg == null ? 'Elegí la app de ${s.label} (mantené apretada su pestaña)' : '';
    }
    final ok = settings.returnAfterLaunch ? await Native.launchReturn(pkg) : await Native.launch(pkg);
    if (!ok) return 'No se pudo abrir ${labelOf(pkg)}';
    // por si la app abre en pausa: después de volver le manda play
    Future.delayed(const Duration(milliseconds: 3500), () {
      final ses = media.value.forPkg(pkg);
      if (ses != null && !ses.playing) Native.media('play', pkg: pkg);
    });
    return '';
  }

  String labelOf(String? pkg) {
    if (pkg == null) return 'Sin elegir';
    for (final a in _apps ?? const <AppEntry>[]) {
      if (a.pkg == pkg) return a.label;
    }
    return pkg.split('.').last;
  }

  Uint8List? iconNow(String pkg) => _icons[pkg];

  Future<Uint8List?> icon(String pkg) {
    if (_icons.containsKey(pkg)) return Future.value(_icons[pkg]);
    return _iconWait[pkg] ??= Native.appIcon(pkg).then((v) {
      _icons[pkg] = v;
      _iconWait.remove(pkg);
      return v;
    });
  }

  /* ------------------------------------------------ carátulas */

  final _art = <String, Uint8List?>{};

  Uint8List? artNow(Session s) => s.artKey == null ? null : _art[s.artKey!];

  Future<Uint8List?> art(Session s) async {
    final k = s.artKey;
    if (k == null) return null;
    if (_art.containsKey(k)) return _art[k];
    final v = await Native.mediaArt(s.pkg);
    if (_art.length > 30) _art.clear();
    _art[k] = v;
    return v;
  }

  /* ------------------------------------------------ acciones comunes */

  Future<bool> openSlot(Slot s) => Native.launch(settings.slot(s));

  Future<bool> goTo(String key) async {
    final p = settings.place(key);
    if (p == null) return false;
    return Native.navigate(p.lat, p.lon, settings.slot(Slot.nav));
  }
}
