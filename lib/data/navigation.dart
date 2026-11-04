import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'app_state.dart';
import 'models.dart';

/// Lugar encontrado en la búsqueda.
class PlaceHit {
  const PlaceHit(this.name, this.detail, this.at);
  final String name, detail;
  final LatLng at;
}

/// Un giro de la ruta.
class NavStep {
  const NavStep({required this.at, required this.type, required this.modifier, required this.street, required this.distance, this.exit});
  final LatLng at;
  final String type, modifier, street;
  final double distance; // metros de este tramo
  final int? exit;

  /// Texto del giro en castellano.
  String get text {
    final calle = street.isEmpty ? '' : ' en $street';
    final hacia = street.isEmpty ? '' : ' hacia $street';
    switch (type) {
      case 'depart':
        return 'Salí$hacia';
      case 'arrive':
        return 'Llegaste a destino';
      case 'roundabout':
      case 'rotary':
      case 'exit roundabout':
      case 'exit rotary':
        return exit != null ? 'En la rotonda, tomá la ${exit}ª salida$hacia' : 'Entrá a la rotonda$hacia';
      case 'merge':
        return 'Incorporate$hacia';
      case 'fork':
        return modifier.contains('left') ? 'En la bifurcación, mantenete a la izquierda$hacia' : 'En la bifurcación, mantenete a la derecha$hacia';
      case 'end of road':
        return modifier.contains('left') ? 'Al final, girá a la izquierda$calle' : 'Al final, girá a la derecha$calle';
    }
    switch (modifier) {
      case 'uturn':
        return 'Pegá la vuelta$calle';
      case 'sharp right':
        return 'Girá cerrado a la derecha$calle';
      case 'right':
        return 'Girá a la derecha$calle';
      case 'slight right':
        return 'Mantenete a la derecha$calle';
      case 'sharp left':
        return 'Girá cerrado a la izquierda$calle';
      case 'left':
        return 'Girá a la izquierda$calle';
      case 'slight left':
        return 'Mantenete a la izquierda$calle';
      default:
        return 'Seguí derecho$calle';
    }
  }

  /// Ícono simple: left, right, slight_left, slight_right, uturn, straight, roundabout, flag.
  String get icon {
    if (type == 'arrive') return 'flag';
    if (type.contains('roundabout') || type.contains('rotary')) return 'roundabout';
    if (modifier == 'uturn') return 'uturn';
    if (modifier.contains('slight') && modifier.contains('left')) return 'slight_left';
    if (modifier.contains('slight') && modifier.contains('right')) return 'slight_right';
    if (modifier.contains('left')) return 'left';
    if (modifier.contains('right')) return 'right';
    return 'straight';
  }
}

/// Ruta activa y avance sobre ella.
class NavState {
  const NavState({
    required this.dest,
    required this.destName,
    required this.line,
    required this.steps,
    required this.totalM,
    required this.totalS,
    required this.next,
    required this.toNextM,
    required this.leftM,
    required this.leftS,
    this.rerouting = false,
  });

  final LatLng dest;
  final String destName;
  final List<LatLng> line;
  final List<NavStep> steps;
  final double totalM, totalS;
  final int next; // índice del próximo giro
  final double toNextM, leftM, leftS;
  final bool rerouting;

  NavStep? get nextStep => next < steps.length ? steps[next] : null;

  NavState copy({int? next, double? toNextM, double? leftM, double? leftS, bool? rerouting}) => NavState(
        dest: dest,
        destName: destName,
        line: line,
        steps: steps,
        totalM: totalM,
        totalS: totalS,
        next: next ?? this.next,
        toNextM: toNextM ?? this.toNextM,
        leftM: leftM ?? this.leftM,
        leftS: leftS ?? this.leftS,
        rerouting: rerouting ?? this.rerouting,
      );
}

String fmtDist(double m) {
  if (m >= 10000) return '${(m / 1000).round()} km';
  if (m >= 1000) return '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  if (m >= 100) return '${(m / 50).round() * 50} m';
  return '${(m / 10).round() * 10} m';
}

String fmtTime(double s) {
  final m = (s / 60).round();
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

/// Navegación dentro del launcher: búsqueda (Nominatim / OpenStreetMap) y ruta (OSRM).
/// Necesita internet para buscar y calcular; el avance se sigue con el GPS.
class Navi {
  Navi(this.app) {
    app.gps.addListener(_onGps);
  }
  final App app;

  final state = ValueNotifier<NavState?>(null);
  final busy = ValueNotifier<bool>(false);

  static const _ua = {'User-Agent': 'CarLauncher4/4.0 (radio de auto, uso personal)'};
  static const _distance = Distance();
  static double _dist(LatLng a, LatLng b) => _distance.distance(a, b).toDouble();

  int _offRouteSince = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  LatLng get here {
    final g = app.gps.value;
    return g == null ? LatLng(app.lat, app.lon) : LatLng(g.lat, g.lon);
  }

  Future<List<PlaceHit>> search(String q) async {
    final h = here;
    final box = '${h.longitude - 1.5},${h.latitude + 1.5},${h.longitude + 1.5},${h.latitude - 1.5}';
    final u = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '0',
      'accept-language': 'es',
      'viewbox': box,
    });
    final r = await http.get(u, headers: _ua).timeout(const Duration(seconds: 10));
    if (r.statusCode != 200) throw StateError('búsqueda ${r.statusCode}');
    final list = jsonDecode(r.body) as List;
    final hits = <PlaceHit>[];
    for (final e in list) {
      final m = e as Map;
      final full = (m['display_name'] as String? ?? '').split(', ');
      final name = (m['name'] as String?)?.isNotEmpty == true ? m['name'] as String : full.first;
      final detail = full.where((p) => p != name).take(3).join(', ');
      hits.add(PlaceHit(name, detail, LatLng(double.parse('${m['lat']}'), double.parse('${m['lon']}'))));
    }
    // los más cercanos primero
    hits.sort((a, b) => _dist(h, a.at).compareTo(_dist(h, b.at)));
    return hits;
  }

  /// Calcula la ruta desde la posición actual y la activa.
  Future<void> start(LatLng dest, String name) async {
    busy.value = true;
    try {
      state.value = await _route(here, dest, name);
      _offRouteSince = 0;
      _progress();
    } finally {
      busy.value = false;
    }
  }

  void stop() {
    state.value = null;
    _offRouteSince = 0;
  }

  Future<NavState> _route(LatLng from, LatLng to, String name) async {
    final u = Uri.parse('https://router.project-osrm.org/route/v1/driving/'
        '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson&steps=true');
    final r = await http.get(u, headers: _ua).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw StateError('ruta ${r.statusCode}');
    final j = jsonDecode(r.body) as Map;
    if (j['code'] != 'Ok' || (j['routes'] as List).isEmpty) throw StateError('sin ruta');
    final route = (j['routes'] as List).first as Map;
    final coords = (route['geometry'] as Map)['coordinates'] as List;
    final line = [for (final c in coords) LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble())];
    final steps = <NavStep>[];
    for (final leg in route['legs'] as List) {
      for (final s in (leg as Map)['steps'] as List) {
        final st = s as Map;
        final man = st['maneuver'] as Map;
        final loc = man['location'] as List;
        steps.add(NavStep(
          at: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
          type: man['type'] as String? ?? '',
          modifier: man['modifier'] as String? ?? '',
          street: st['name'] as String? ?? '',
          distance: (st['distance'] as num?)?.toDouble() ?? 0,
          exit: (man['exit'] as num?)?.toInt(),
        ));
      }
    }
    final total = (route['distance'] as num).toDouble();
    final dur = (route['duration'] as num).toDouble();
    return NavState(
      dest: to,
      destName: name,
      line: line,
      steps: steps,
      totalM: total,
      totalS: dur,
      next: steps.length > 1 ? 1 : 0,
      toNextM: steps.length > 1 ? _dist(from, steps[1].at) : total,
      leftM: total,
      leftS: dur,
    );
  }

  void _onGps() => _progress();

  /// Avanza al próximo giro, recalcula lo que falta y, si se salió del camino, recalcula la ruta.
  void _progress() {
    final s = state.value;
    final g = app.gps.value;
    if (s == null || g == null) return;
    final p = LatLng(g.lat, g.lon);

    if (_dist(p, s.dest) < 35) {
      state.value = s.copy(next: s.steps.length - 1, toNextM: 0, leftM: 0, leftS: 0);
      Future.delayed(const Duration(seconds: 8), () {
        if (state.value?.dest == s.dest) stop();
      });
      return;
    }

    var next = s.next;
    while (next < s.steps.length - 1 && _dist(p, s.steps[next].at) < 25) {
      next++;
    }
    final toNext = _dist(p, s.steps[next].at);
    var left = toNext;
    for (var i = next; i < s.steps.length; i++) {
      left += s.steps[i].distance;
    }
    left = math.min(left, s.totalM);
    final leftS = s.totalM <= 0 ? 0.0 : s.totalS * left / s.totalM;
    state.value = s.copy(next: next, toNextM: toNext, leftM: left, leftS: leftS);

    // ¿fuera de la ruta? (más de 70 m durante 8 s)
    final off = _distToLine(p, s.line) > 70;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!off) {
      _offRouteSince = 0;
      return;
    }
    if (_offRouteSince == 0) _offRouteSince = now;
    if (now - _offRouteSince > 8000 && DateTime.now().difference(_lastReroute).inSeconds > 20 && !busy.value) {
      _lastReroute = DateTime.now();
      _reroute(s);
    }
  }

  Future<void> _reroute(NavState s) async {
    state.value = s.copy(rerouting: true);
    try {
      state.value = await _route(here, s.dest, s.destName);
      _offRouteSince = 0;
    } catch (_) {
      state.value = s.copy(rerouting: false);
    }
  }

  double _distToLine(LatLng p, List<LatLng> line) {
    if (line.length < 2) return 0;
    // aproximación plana (alcanza para unos cientos de metros)
    final k = math.cos(p.latitude * math.pi / 180) * 111320.0;
    const ky = 110540.0;
    var best = double.infinity;
    for (var i = 0; i < line.length - 1; i++) {
      final ax = (line[i].longitude - p.longitude) * k, ay = (line[i].latitude - p.latitude) * ky;
      final bx = (line[i + 1].longitude - p.longitude) * k, by = (line[i + 1].latitude - p.latitude) * ky;
      final dx = bx - ax, dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      final d = math.sqrt(x * x + y * y);
      if (d < best) best = d;
    }
    return best;
  }

  /// Para el banner del inicio cuando no hay Maps/Waze andando.
  NavInfo? asBanner() {
    final s = state.value;
    final st = s?.nextStep;
    if (s == null || st == null) return null;
    return NavInfo(
      app: 'Car Launcher',
      dist: s.rerouting ? 'Recalculando…' : fmtDist(s.toNextM),
      maneuver: st.text,
      street: '',
      eta: '${fmtDist(s.leftM)} · ${fmtTime(s.leftS)}',
    );
  }
}
