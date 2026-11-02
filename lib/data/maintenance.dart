import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/native.dart';

class KmItem {
  const KmItem(this.id, this.name, this.defInterval, this.presets, {this.custom = false});
  final String id, name;
  final int defInterval;
  final List<int> presets;
  final bool custom;
}

class DateItem {
  const DateItem(this.id, this.name, {this.custom = false});
  final String id, name;
  final bool custom;
}

class KmRow {
  const KmRow(this.item, this.remaining, this.interval, this.next, this.last);
  final KmItem item;
  final int? remaining; // null = sin cargar
  final int interval;
  final int? next, last;
  String get id => item.id;
  String get name => item.name;
  bool get warn => remaining != null && remaining! <= Maint.warnKm;
  double get fraction => remaining == null || interval <= 0 ? 0 : (remaining! / interval).clamp(0.0, 1.0);
}

class DateRow {
  const DateRow(this.item, this.date, this.days);
  final DateItem item;
  final DateTime? date;
  final int? days; // negativo = vencido
  String get id => item.id;
  String get name => item.name;
  bool get warn => days != null && days! <= Maint.warnDays;
}

/// Mantenimiento por km del tablero y por fecha. Misma lógica que Car Launcher 3:
/// "próximo cambio" son km fijos del tablero; el tablero lo suma el GPS.
class Maint extends ChangeNotifier {
  Maint(this.sp);
  final SharedPreferences sp;

  static const warnKm = 500;
  static const warnDays = 30;

  static const items = [
    KmItem('oil', 'Aceite motor', 5000, [3000, 5000, 7500, 10000]),
    KmItem('gear', 'Aceite caja', 40000, [20000, 30000, 40000, 60000]),
    KmItem('air', 'Filtro de aire', 15000, [10000, 15000, 20000, 30000]),
    KmItem('tires', 'Rotación de neumáticos', 10000, [5000, 8000, 10000, 15000]),
    KmItem('brakes', 'Pastillas de freno', 20000, [15000, 20000, 30000, 40000]),
    KmItem('belt', 'Correa de distribución', 60000, [40000, 50000, 60000, 100000]),
  ];
  static const dates = [
    DateItem('ins', 'Seguro del auto'),
    DateItem('hab', 'Habilitación'),
    DateItem('rev', 'Revisión técnica'),
    DateItem('lic', 'Licencia de conducir'),
  ];

  /// Zona del auto que se resalta en el holograma.
  static String partOf(String id) {
    switch (id) {
      case 'oil':
      case 'gear':
      case 'air':
      case 'tires':
      case 'brakes':
      case 'belt':
        return id;
    }
    for (final d in dates) {
      if (d.id == id) return 'docs';
    }
    return id.startsWith('d') ? 'docs' : 'custom';
  }

  double? _odo;
  double? get odoExact => _odo;
  int? get odo => _odo == null ? null : _odo!.round();

  /// Lo llama el estado general con el km que suma el GPS.
  void updateOdo(double? km) {
    final v = (km == null || km < 0) ? null : km;
    if (v?.round() != _odo?.round()) {
      _odo = v;
      notifyListeners();
    } else {
      _odo = v;
    }
  }

  Future<void> setOdo(int km) async {
    await Native.setOdo(km.toDouble());
    _odo = km.toDouble();
    notifyListeners();
  }

  List<Map<String, dynamic>> _arr(String key) {
    try {
      return (jsonDecode(sp.getString(key) ?? '[]') as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  List<KmItem> get kmItems => [
        ...items,
        for (final o in _arr('customKm'))
          KmItem(o['id'] as String, o['name'] as String, (o['def'] as num).toInt(),
              [(o['def'] as num).toInt() ~/ 2, (o['def'] as num).toInt(), (o['def'] as num).toInt() * 2],
              custom: true),
      ];

  List<DateItem> get dateItems => [
        ...dates,
        for (final o in _arr('customDates')) DateItem(o['id'] as String, o['name'] as String, custom: true),
      ];

  int? next(String id) => sp.getInt('next_$id');
  int? last(String id) => sp.getInt('last_$id');
  int interval(String id) =>
      sp.getInt('int_$id') ?? kmItems.firstWhere((e) => e.id == id, orElse: () => items.first).defInterval;

  int? remaining(String id) {
    final o = odo, n = next(id);
    if (o == null || n == null) return null;
    final r = n - o;
    return r < 0 ? 0 : r;
  }

  List<KmRow> get kmRows =>
      [for (final i in kmItems) KmRow(i, remaining(i.id), interval(i.id), next(i.id), last(i.id))];

  DateTime? date(String id) {
    final ms = sp.getInt('d_$id');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static int daysUntil(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(d.year, d.month, d.day);
    return (b.difference(a).inHours / 24).round();
  }

  static String leftText(int days) {
    if (days < 0) return 'Vencido';
    if (days == 0) return 'Hoy';
    if (days == 1) return 'Mañana';
    if (days < 60) return 'en $days días';
    if (days < 365) return 'en ${days ~/ 30} meses';
    if (days < 730) return 'en 1 año';
    return 'en ${days ~/ 365} años';
  }

  List<DateRow> get dateRows => [
        for (final d in dateItems)
          () {
            final dt = date(d.id);
            return DateRow(d, dt, dt == null ? null : daysUntil(dt));
          }()
      ];

  int get warnings => kmRows.where((r) => r.warn).length + dateRows.where((r) => r.warn).length;

  /// Ítems en alerta ordenados por urgencia (para el inicio).
  List<String> get alerts {
    final out = <(int, String)>[];
    for (final r in kmRows) {
      if (r.warn) out.add((r.remaining! ~/ 10, '${r.name} · ${_km(r.remaining!)}'));
    }
    for (final r in dateRows) {
      if (r.warn) out.add((r.days!, '${r.name} · ${r.days! < 0 ? 'vencido' : leftText(r.days!)}'));
    }
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return [for (final e in out) e.$2];
  }

  static String _km(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return '$b km';
  }

  /* ------------------------------------------------ acciones */

  /// "Lo cambié hoy": próximo = tablero + intervalo.
  Future<void> changedNow(String id) async {
    final o = odo;
    if (o == null) return;
    await sp.setInt('last_$id', o);
    await sp.setInt('next_$id', o + interval(id));
    notifyListeners();
  }

  /// "El próximo cambio es a los X km" (lo que dice el sticker del taller).
  Future<void> setNext(String id, int km) async {
    await sp.setInt('next_$id', km);
    await sp.remove('last_$id');
    notifyListeners();
  }

  /// Cambia el intervalo. Si se sabe cuándo fue el último cambio, recalcula el próximo.
  Future<void> setInterval(String id, int km) async {
    await sp.setInt('int_$id', km);
    final l = last(id);
    if (l != null) await sp.setInt('next_$id', l + km);
    notifyListeners();
  }

  Future<void> setDate(String id, DateTime? d) async {
    if (d == null) {
      await sp.remove('d_$id');
    } else {
      await sp.setInt('d_$id', d.millisecondsSinceEpoch);
    }
    notifyListeners();
  }

  Future<String> addKm(String name, int interval) async {
    final id = 'c${DateTime.now().millisecondsSinceEpoch}';
    final a = _arr('customKm')..add({'id': id, 'name': name, 'def': interval});
    await sp.setString('customKm', jsonEncode(a));
    await sp.setInt('int_$id', interval);
    final o = odo;
    if (o != null) {
      await sp.setInt('next_$id', o + interval);
      await sp.setInt('last_$id', o);
    }
    notifyListeners();
    return id;
  }

  Future<String> addDate(String name) async {
    final id = 'd${DateTime.now().millisecondsSinceEpoch}';
    final a = _arr('customDates')..add({'id': id, 'name': name});
    await sp.setString('customDates', jsonEncode(a));
    notifyListeners();
    return id;
  }

  Future<void> remove(String id) async {
    for (final key in ['customKm', 'customDates']) {
      final a = _arr(key)..removeWhere((o) => o['id'] == id);
      await sp.setString(key, jsonEncode(a));
    }
    for (final k in ['int_', 'next_', 'last_', 'd_']) {
      await sp.remove('$k$id');
    }
    notifyListeners();
  }
}
