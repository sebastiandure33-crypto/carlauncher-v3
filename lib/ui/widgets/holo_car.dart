import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Auto visto desde arriba en estilo holograma.
///
/// El auto queda siempre quieto en el mismo lugar: al elegir otra pieza, el visor se desliza
/// en línea recta desde la pieza anterior hasta la nueva, la anterior se apaga y la nueva se
/// enciende al mismo tiempo (sin zoom ni cortes). Si se cambia a mitad de camino, sigue desde
/// donde estaba.
class HoloCar extends StatefulWidget {
  const HoloCar({super.key, this.part, this.warn = const {}, this.intro = false, this.compact = false, this.onIntroDone});

  /// Zona resaltada: oil, air, belt, gear, brakes, tires, docs, custom (o null).
  final String? part;

  /// Zonas con alerta (se ven en rojo).
  final Set<String> warn;

  /// Reproduce la animación de arranque (dibujo del contorno, escaneo y chequeo de cada pieza).
  final bool intro;
  final bool compact;
  final VoidCallback? onIntroDone;

  static const parts = ['oil', 'air', 'belt', 'gear', 'brakes', 'tires', 'docs'];

  /// Puntos de cada zona en el dibujo de 200×400.
  static const anchors = <String, List<Offset>>{
    'oil': [Offset(100, 74)],
    'air': [Offset(62, 58)],
    'belt': [Offset(140, 54)],
    'gear': [Offset(100, 148)],
    'brakes': [Offset(40, 119), Offset(160, 119), Offset(40, 295), Offset(160, 295)],
    'tires': [Offset(26, 119), Offset(174, 119), Offset(26, 295), Offset(174, 295)],
    'docs': [Offset(100, 232)],
    'custom': [Offset(100, 196)],
  };

  static Offset center(String? part) {
    final a = anchors[part];
    if (a == null || a.isEmpty) return const Offset(100, 200);
    var x = 0.0, y = 0.0;
    for (final p in a) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / a.length, y / a.length);
  }

  /// Rectángulo que ocupa el auto dentro de un área (para dibujar líneas hacia una pieza).
  static Rect fit(Size s) {
    final k = math.min(s.width / 220, s.height / 410);
    final w = 200 * k, h = 400 * k;
    return Rect.fromLTWH((s.width - w) / 2, (s.height - h) / 2, w, h);
  }

  static Offset toLocal(Size s, Offset p) {
    final r = fit(s);
    return Offset(r.left + p.dx / 200 * r.width, r.top + p.dy / 400 * r.height);
  }

  @override
  State<HoloCar> createState() => _HoloCarState();
}

class _HoloCarState extends State<HoloCar> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final AnimationController _move = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  late Offset _from = HoloCar.center(widget.part), _to = _from;
  Map<String, double> _lvFrom = {}, _lvTo = {};

  @override
  void initState() {
    super.initState();
    if (widget.part != null) _lvFrom = _lvTo = {widget.part!: 1};
    _move.value = 1;
    if (widget.intro) {
      _intro.forward().whenComplete(() => widget.onIntroDone?.call());
    } else {
      _intro.value = 1;
    }
  }

  double get _k => Curves.easeInOutCubic.transform(_move.value);

  Offset get _focus => Offset.lerp(_from, _to, _k)!;

  Map<String, double> get _levels {
    final k = _k;
    final keys = {..._lvFrom.keys, ..._lvTo.keys};
    return {for (final key in keys) key: ui.lerpDouble(_lvFrom[key] ?? 0, _lvTo[key] ?? 0, k)!};
  }

  @override
  void didUpdateWidget(HoloCar old) {
    super.didUpdateWidget(old);
    if (old.part != widget.part) {
      // sigue desde donde está ahora (aunque esté a mitad de camino)
      _from = _focus;
      _lvFrom = _levels;
      _to = widget.part == null ? _from : HoloCar.center(widget.part);
      _lvTo = widget.part == null ? {} : {widget.part!: 1};
      _move.forward(from: 0);
    }
    if (widget.intro && !old.intro) {
      _intro.forward(from: 0).whenComplete(() => widget.onIntroDone?.call());
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _move.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _intro,
            builder: (_, __) => CustomPaint(painter: _BodyPainter(c, _intro.value, widget.compact)),
          ),
        ),
        AnimatedBuilder(
          animation: Listenable.merge([_idle, _move, _intro]),
          builder: (_, __) => CustomPaint(
            painter: _FxPainter(
              pal: c,
              t: _idle.value,
              intro: _intro.value,
              focus: _focus,
              showFocus: _levels.values.fold(0.0, math.max),
              levels: _levels,
              warn: widget.warn,
              compact: widget.compact,
            ),
          ),
        ),
      ]),
    );
  }
}

/* ------------------------------------------------------------------ dibujo */

Path _body() => Path()
  ..moveTo(100, 14)
  ..cubicTo(148, 14, 164, 40, 168, 84)
  ..lineTo(174, 170)
  ..lineTo(174, 306)
  ..cubicTo(174, 360, 152, 392, 100, 392)
  ..cubicTo(48, 392, 26, 360, 26, 306)
  ..lineTo(26, 170)
  ..lineTo(32, 84)
  ..cubicTo(36, 40, 52, 14, 100, 14)
  ..close();

Path _details() {
  final p = Path()
    // parabrisas
    ..moveTo(52, 132)
    ..cubicTo(72, 110, 128, 110, 148, 132)
    ..lineTo(140, 180)
    ..cubicTo(120, 170, 80, 170, 60, 180)
    ..close()
    // luneta
    ..moveTo(60, 298)
    ..cubicTo(80, 306, 120, 306, 140, 298)
    ..lineTo(148, 332)
    ..cubicTo(130, 350, 70, 350, 52, 332)
    ..close()
    // capó
    ..moveTo(70, 26)
    ..cubicTo(74, 60, 74, 92, 72, 120)
    ..moveTo(130, 26)
    ..cubicTo(126, 60, 126, 92, 128, 120)
    // espejos
    ..moveTo(28, 146)
    ..lineTo(12, 150)
    ..lineTo(14, 160)
    ..lineTo(28, 158)
    ..moveTo(172, 146)
    ..lineTo(188, 150)
    ..lineTo(186, 160)
    ..lineTo(172, 158)
    // puertas
    ..moveTo(26, 236)
    ..lineTo(36, 236)
    ..moveTo(174, 236)
    ..lineTo(164, 236);
  p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(62, 186, 76, 106), const Radius.circular(20)));
  return p;
}

Path _inner() {
  final p = Path()
    // ejes y túnel
    ..moveTo(40, 119)
    ..lineTo(160, 119)
    ..moveTo(40, 295)
    ..lineTo(160, 295)
    ..moveTo(100, 104)
    ..lineTo(100, 290);
  // motor
  p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(72, 44, 56, 52), const Radius.circular(8)));
  // filtro de aire
  p.addOval(Rect.fromCircle(center: const Offset(62, 58), radius: 9));
  // correa
  p.addOval(Rect.fromCircle(center: const Offset(140, 54), radius: 8));
  p.addOval(Rect.fromCircle(center: const Offset(140, 74), radius: 5));
  // caja
  p.addRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(90, 134, 20, 30), const Radius.circular(5)));
  // asientos
  for (final r in const [
    Rect.fromLTWH(70, 200, 26, 30),
    Rect.fromLTWH(104, 200, 26, 30),
    Rect.fromLTWH(70, 250, 60, 28),
  ]) {
    p.addRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)));
  }
  return p;
}

const _wheels = [
  Rect.fromLTWH(14, 86, 24, 66),
  Rect.fromLTWH(162, 86, 24, 66),
  Rect.fromLTWH(14, 262, 24, 66),
  Rect.fromLTWH(162, 262, 24, 66),
];

void _toCar(Canvas canvas, Size size) {
  final r = HoloCar.fit(size);
  canvas.translate(r.left, r.top);
  canvas.scale(r.width / 200, r.height / 400);
}

Path _trim(Path p, double f) {
  if (f >= 1) return p;
  final out = Path();
  for (final m in p.computeMetrics()) {
    out.addPath(m.extractPath(0, m.length * f), Offset.zero);
  }
  return out;
}

class _BodyPainter extends CustomPainter {
  _BodyPainter(this.c, this.intro, this.compact);
  final Pal c;
  final double intro;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _toCar(canvas, size);
    final holo = c.blue;
    final draw = (intro / 0.5).clamp(0.0, 1.0);
    final fill = ((intro - 0.35) / 0.3).clamp(0.0, 1.0);

    // piso: anillos alrededor del auto
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = alpha(holo, 0.12 * draw);
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 203), width: 250, height: 430), ring);
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 203), width: 300, height: 470), ring..color = alpha(holo, 0.06 * draw));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 203), width: 240, height: 420),
      Paint()
        ..shader = RadialGradient(colors: [alpha(holo, 0.16 * fill), alpha(holo, 0)])
            .createShader(Rect.fromCenter(center: const Offset(100, 203), width: 240, height: 420)),
    );

    final body = _body();
    // relleno translúcido
    if (fill > 0) {
      canvas.drawPath(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [alpha(holo, 0.05 * fill), alpha(holo, 0.16 * fill), alpha(holo, 0.05 * fill)],
          ).createShader(const Rect.fromLTWH(26, 14, 148, 378)),
      );
    }
    // ruedas
    final wheel = Paint()..color = alpha(c.dark ? const Color(0xFF020305) : const Color(0xFF8C98A8), 0.9 * fill);
    final wheelLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = alpha(holo, 0.55 * draw);
    for (final w in _wheels) {
      final rr = RRect.fromRectAndRadius(w, const Radius.circular(9));
      canvas.drawRRect(rr, wheel);
      canvas.drawRRect(rr, wheelLine);
    }
    // contorno con brillo
    final outline = _trim(body, draw);
    if (!compact) {
      canvas.drawPath(
        outline,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = alpha(holo, 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawPath(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = alpha(holo, 0.95),
    );
    // detalles
    canvas.drawPath(
      _trim(_details(), draw),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = alpha(holo, 0.6 * draw),
    );
    canvas.drawPath(
      _trim(_inner(), draw),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = alpha(holo, 0.28 * fill),
    );
    // vidrios
    final glass = Path()
      ..moveTo(52, 132)
      ..cubicTo(72, 110, 128, 110, 148, 132)
      ..lineTo(140, 180)
      ..cubicTo(120, 170, 80, 170, 60, 180)
      ..close()
      ..moveTo(60, 298)
      ..cubicTo(80, 306, 120, 306, 140, 298)
      ..lineTo(148, 332)
      ..cubicTo(130, 350, 70, 350, 52, 332)
      ..close();
    canvas.drawPath(glass, Paint()..color = alpha(holo, 0.1 * fill));
    // faros y luces traseras
    final lights = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(42, 32)
        ..cubicTo(54, 22, 70, 20, 82, 20)
        ..moveTo(158, 32)
        ..cubicTo(146, 22, 130, 20, 118, 20),
      lights..color = alpha(const Color(0xFFFFE9C7), fill),
    );
    canvas.drawPath(
      Path()
        ..moveTo(42, 380)
        ..lineTo(76, 388)
        ..moveTo(158, 380)
        ..lineTo(124, 388),
      lights..color = alpha(const Color(0xFFFF4A3D), fill),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter o) => o.c != c || o.intro != intro || o.compact != compact;
}

class _FxPainter extends CustomPainter {
  _FxPainter({
    required this.pal,
    required this.t,
    required this.intro,
    required this.focus,
    required this.showFocus,
    required this.levels,
    required this.warn,
    required this.compact,
  });

  final Pal pal;
  final double t, intro, showFocus;
  final Offset focus;
  final Map<String, double> levels;
  final Set<String> warn;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final holo = pal.blue;
    final rect = HoloCar.fit(size);
    final k = rect.width / 200;

    // líneas guía del visor (cruzan todo el área y siguen a la pieza)
    if (!compact && showFocus > 0.01 && intro >= 1) {
      final f = HoloCar.toLocal(size, focus);
      final guide = Paint()
        ..strokeWidth = 1
        ..color = alpha(pal.accent, 0.22 * showFocus);
      canvas.drawLine(Offset(0, f.dy), Offset(size.width, f.dy), guide);
      canvas.drawLine(Offset(f.dx, 0), Offset(f.dx, size.height), guide);
    }

    canvas.save();
    _toCar(canvas, size);

    // barrido suave permanente (solo dentro del auto)
    if (intro >= 1) {
      final y = -60 + (t * 1.25 % 1.25) * 520;
      canvas.save();
      canvas.clipPath(_body());
      canvas.drawRect(
        Rect.fromLTWH(0, y, 200, 40),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [alpha(holo, 0), alpha(holo, 0.16), alpha(holo, 0)],
          ).createShader(Rect.fromLTWH(0, y, 200, 40)),
      );
      canvas.restore();
    }

    // barrido de la animación de arranque
    if (intro > 0.02 && intro < 0.65) {
      final p = ((intro - 0.02) / 0.6).clamp(0.0, 1.0);
      final y = -20 + p * 440;
      canvas.drawRect(
        Rect.fromLTWH(-20, y - 30, 240, 30),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [alpha(holo, 0), alpha(holo, 0.45)],
          ).createShader(Rect.fromLTWH(-20, y - 30, 240, 30)),
      );
      canvas.drawLine(Offset(-20, y), Offset(220, y), Paint()
        ..strokeWidth = 2
        ..color = alpha(holo, 0.9));
    }

    final pulse = 0.5 + 0.5 * math.sin(t * math.pi * 2 * 2);

    // puntos de todas las piezas (rojo si están en alerta)
    final dots = intro >= 0.5 ? ((intro - 0.5) / 0.15).clamp(0.0, 1.0) : 0.0;
    for (final part in HoloCar.parts) {
      final isWarn = warn.contains(part);
      for (final a in HoloCar.anchors[part]!) {
        if (part == 'tires') continue; // las ruedas se resaltan con su contorno
        final col = isWarn ? pal.red : holo;
        canvas.drawCircle(a, isWarn ? 3.4 + pulse * 1.2 : 2.6, Paint()..color = alpha(col, (isWarn ? 0.95 : 0.55) * dots));
        if (isWarn) {
          canvas.drawCircle(a, 8 + pulse * 6, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = alpha(pal.red, 0.5 * (1 - pulse) * dots));
        }
      }
    }

    // chequeo de cada pieza al arrancar: se encienden una por una (verde bien, rojo alerta)
    if (intro > 0.45 && intro < 1) {
      for (var i = 0; i < HoloCar.parts.length; i++) {
        final start = 0.5 + i * 0.065;
        final p = ((intro - start) / 0.12).clamp(0.0, 1.0);
        if (p <= 0 || p >= 1) continue;
        final part = HoloCar.parts[i];
        final col = warn.contains(part) ? pal.red : pal.green;
        for (final a in HoloCar.anchors[part]!) {
          canvas.drawCircle(a, 6 + p * 24, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = alpha(col, 1 - p));
          canvas.drawCircle(a, 5, Paint()..color = alpha(col, 1 - p * 0.5));
        }
      }
    }

    // piezas resaltadas (la que se va se apaga mientras la nueva se enciende)
    levels.forEach((part, lv) {
      if (lv <= 0.01) return;
      final col = warn.contains(part) ? pal.red : pal.accent;
      final pts = HoloCar.anchors[part] ?? HoloCar.anchors['custom']!;
      for (final a in pts) {
        final r = (part == 'tires' ? 30.0 : 26.0) * (0.6 + 0.4 * lv);
        canvas.drawCircle(
          a,
          r,
          Paint()
            ..shader = RadialGradient(colors: [alpha(col, 0.5 * lv), alpha(col, 0)])
                .createShader(Rect.fromCircle(center: a, radius: r)),
        );
        canvas.drawCircle(a, 3.6 * lv + 1, Paint()..color = alpha(col, lv));
      }
      if (part == 'tires' || part == 'brakes') {
        for (final w in _wheels) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(w.inflate(part == 'tires' ? 3 : 0), const Radius.circular(10)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = part == 'tires' ? 2.4 : 1.6
              ..color = alpha(col, 0.95 * lv),
          );
        }
      }
      if (part == 'docs') {
        final r = RRect.fromRectAndRadius(const Rect.fromLTWH(62, 186, 76, 106), const Radius.circular(20));
        canvas.drawRRect(r, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = alpha(col, 0.9 * lv));
      }
    });

    // visor: anillo que se desliza en línea recta hacia la pieza elegida
    if (showFocus > 0.01 && intro >= 1) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 / k.clamp(0.5, 3)
        ..color = alpha(pal.accent, 0.85 * showFocus);
      canvas.drawCircle(focus, 20, ring);
      final rot = t * math.pi * 2;
      for (var i = 0; i < 4; i++) {
        final a = rot + i * math.pi / 2;
        canvas.drawLine(
          focus + Offset(math.cos(a), math.sin(a)) * 24,
          focus + Offset(math.cos(a), math.sin(a)) * 31,
          ring..strokeWidth = 2.2 / k.clamp(0.5, 3),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FxPainter o) => true;
}
