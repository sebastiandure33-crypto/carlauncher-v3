import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/native.dart';

enum ThemeModeX { auto, night, day }

/// Botones que abren una app elegible (mantené apretado para cambiarla).
enum Slot {
  nav('Mapas', 'com.google.android.apps.maps'),
  music('Bluetooth', null),
  radio('Radio FM', null),
  phone('Teléfono', null),
  usb('USB', null),
  eq('Ecualizador', null);

  const Slot(this.label, this.def);
  final String label;
  final String? def;
}

/// Paquetes y nombres típicos de las apps de las radios chinas (FYT/SYU, Microntek, TopWay, etc.).
const autoPackages = <Slot, List<String>>{
  Slot.music: [
    'com.tw.bt', 'com.syu.bt', 'com.microntek.bluetooth', 'com.hct.bt', 'com.nwd.bt.music', 'com.ts.bt',
    'com.autochips.bluetooth', 'com.fyt.bt', 'com.android.bluetooth.music', 'com.wt.bt', 'com.zjinnova.bt',
  ],
  Slot.radio: [
    'com.tw.radio', 'com.syu.radio', 'com.microntek.radio', 'com.hct.radio', 'com.ts.radio', 'com.nwd.radio',
    'com.autochips.radio', 'com.android.fmradio', 'com.mediatek.fmradio', 'com.caf.fmradio', 'com.sprd.fmradio',
  ],
  Slot.usb: ['com.tw.music', 'com.syu.music', 'com.microntek.music', 'com.hct.music', 'com.ts.music', 'com.android.music'],
  Slot.phone: ['com.tw.btphone', 'com.syu.btphone', 'com.microntek.bluetooth', 'com.tw.bt', 'com.syu.bt', 'com.android.dialer'],
  Slot.eq: ['com.tw.eq', 'com.syu.eq', 'com.microntek.eq', 'com.hct.eq', 'com.ts.eq'],
};

final autoLabels = <Slot, RegExp>{
  Slot.music: RegExp(r'(bt|bluetooth|blue ?tooth).*(m[uú]sica|music|audio)|(m[uú]sica|music|audio).*(bt|bluetooth)|^bluetooth$|^bt$|蓝牙', caseSensitive: false),
  Slot.radio: RegExp(r'^(fm|radio|radio fm|fm radio|收音机)$|radio', caseSensitive: false),
  Slot.usb: RegExp(r'^(m[uú]sica|music|usb|reproductor|音乐)$', caseSensitive: false),
  Slot.phone: RegExp(r'tel[eé]fono|phone|llamadas|dialer|bt ?phone|电话', caseSensitive: false),
  Slot.eq: RegExp(r'ecualizador|equalizer|^eq$|audio ?settings|sonido|音效', caseSensitive: false),
};

class Place {
  const Place(this.lat, this.lon);
  final double lat, lon;
}

class Settings extends ChangeNotifier {
  Settings(this.sp);
  final SharedPreferences sp;

  ThemeModeX get theme => ThemeModeX.values[(sp.getInt('theme') ?? 0).clamp(0, 2).toInt()];
  set theme(ThemeModeX v) {
    sp.setInt('theme', v.index);
    notifyListeners();
  }

  /// 0 = aviso desactivado
  int get speedLimit => sp.getInt('limit') ?? 80;
  set speedLimit(int v) {
    sp.setInt('limit', v.clamp(0, 200).toInt());
    notifyListeners();
  }

  /// Apps detectadas solas (Bluetooth y radio del fabricante) cuando el botón no se eligió a mano.
  Map<Slot, String> auto = const {};

  void setAuto(Map<Slot, String> m) {
    auto = m;
    notifyListeners();
  }

  /// '' guardado = el usuario eligió "Ninguna".
  String? slot(Slot s) {
    final v = sp.getString('slot_${s.name}');
    if (v != null) return v.isEmpty ? null : v;
    return auto[s] ?? s.def;
  }

  bool slotIsAuto(Slot s) => sp.getString('slot_${s.name}') == null && auto[s] != null;

  /// null = volver a la detección automática, '' = ninguna.
  Future<void> setSlot(Slot s, String? pkg) async {
    if (pkg == null) {
      await sp.remove('slot_${s.name}');
    } else {
      await sp.setString('slot_${s.name}', pkg);
    }
    notifyListeners();
  }

  Place? place(String key) {
    final la = sp.getDouble('${key}_lat'), lo = sp.getDouble('${key}_lon');
    return la == null || lo == null ? null : Place(la, lo);
  }

  Future<void> setPlace(String key, Place? p) async {
    if (p == null) {
      await sp.remove('${key}_lat');
      await sp.remove('${key}_lon');
    } else {
      await sp.setDouble('${key}_lat', p.lat);
      await sp.setDouble('${key}_lon', p.lon);
    }
    notifyListeners();
  }

  static const mediaModes = [
    'Automático',
    'Sesión · comando',
    'Sesión · tecla',
    'Tecla del sistema',
    'Directo a la app',
    'Todas las sesiones de la app',
    'Orden de música clásica',
  ];

  int get mediaMode => sp.getInt('mediaMode') ?? 0;
  set mediaMode(int v) {
    sp.setInt('mediaMode', v);
    Native.setMediaMode(v);
    notifyListeners();
  }

  bool get ignOpen => sp.getBool('ignOpen') ?? true;
  set ignOpen(bool v) {
    sp.setBool('ignOpen', v);
    Native.setIgnOpen(v);
    notifyListeners();
  }

  /// Brillo guardado para cada modo (0..1). Al pasar de día a noche se aplica solo.
  double brightnessFor(bool night) => sp.getDouble(night ? 'brNight' : 'brDay') ?? (night ? 0.45 : 1.0);
  Future<void> setBrightnessFor(bool night, double v) => sp.setDouble(night ? 'brNight' : 'brDay', v.clamp(0.02, 1.0));

  /// Al tocar play en la radio o en Bluetooth sin que esa app esté abierta: la abre y vuelve.
  bool get returnAfterLaunch => sp.getBool('retLaunch') ?? true;
  set returnAfterLaunch(bool v) {
    sp.setBool('retLaunch', v);
    notifyListeners();
  }

  bool get intro => sp.getBool('intro') ?? true;
  set intro(bool v) {
    sp.setBool('intro', v);
    notifyListeners();
  }
}
