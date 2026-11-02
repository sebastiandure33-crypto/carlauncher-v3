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

  String? slot(Slot s) => sp.getString('slot_${s.name}') ?? s.def;
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

  bool get intro => sp.getBool('intro') ?? true;
  set intro(bool v) {
    sp.setBool('intro', v);
    notifyListeners();
  }
}
