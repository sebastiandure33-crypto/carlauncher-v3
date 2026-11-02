import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Velocímetro de arco (270°) con escala. Rojo al pasar el límite.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.speed, required this.limit, this.max = 160, this.size = 210});
  final double? speed; // null = sin GPS
  final int limit;
  final double max;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final v = speed ?? 0;
    final over = limit > 0 && v > limit;
    return SizedBox(
      width: size,
      height: size * 0.93,
      child: Stack(alignment: Alignment.topCenter, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: (v / max).clamp(0.0, 1.0)),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          builder: (_, f, __) => CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(f, over ? c.red : c.accent, over ? c.redText : c.accentHi, c),
          ),
        ),
        Positioned(
          top: size * 0.25,
          left: 0,
          right: 0,
          child: Column(children: [
            Text(speed == null ? '--' : '${v.round()}',
                textAlign: TextAlign.center, style: ts(size * 0.32, w: FontWeight.w700, c: over ? c.redText : c.text, ls: -2, h: 1)),
            Text(speed == null ? 'SIN GPS' : 'KM/H', style: ts(12, w: FontWeight.w600, c: c.muted, ls: 2)),
          ]),
        ),
        if (limit > 0)
          Positioned(
            bottom: 0,
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6F8),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5453A), width: 5),
              ),
              child: Text('$limit', style: ts(16, w: FontWeight.w700, c: const Color(0xFF111111))),
            ),
          ),
      ]),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.col, this.hi, this.c);
  final double f;
  final Color col, hi;
  final Pal c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 212;
    canvas.save();
    canvas.scale(s);
    canvas.translate(6, 6);
    const ctr = Offset(100, 100);
    const start = 135 * math.pi / 180;
    const sweep = 270 * math.pi / 180;
    // escala
    const n = 32;
    for (var i = 0; i <= n; i++) {
      final a = start + sweep * i / n;
      final r1 = i % 4 == 0 ? 89.0 : 93.0;
      final on = i / n <= f;
      canvas.drawLine(
        ctr + Offset(math.cos(a), math.sin(a)) * r1,
        ctr + Offset(math.cos(a), math.sin(a)) * 99,
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = on ? hi : alpha(c.text, 0.16),
      );
    }
    final r = Rect.fromCircle(center: ctr, radius: 80);
    canvas.drawArc(r, start, sweep, false, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = alpha(c.text, 0.07));
    if (f > 0.002) {
      canvas.drawArc(r, start, sweep * f, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = alpha(col, 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawArc(r, start, sweep * f, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = col);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.f != f || o.col != col || o.c != c;
}
