import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';

/// Panel de vidrio (fondo semitransparente, borde fino y sombra).
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 24, this.color, this.border});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border ?? c.line),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 14))],
      ),
      child: child,
    );
  }
}

/// Botón táctil grande con efecto de presión (sirve para manejar sin mirar mucho).
class Tap extends StatefulWidget {
  const Tap({super.key, required this.child, this.onTap, this.onLong, this.radius = 16, this.semantics});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLong;
  final double radius;
  final String? semantics;

  @override
  State<Tap> createState() => _TapState();
}

class _TapState extends State<Tap> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLong,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 90),
          child: AnimatedOpacity(
            opacity: _down ? 0.8 : 1,
            duration: const Duration(milliseconds: 90),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Botón redondo con ícono.
class RoundBtn extends StatelessWidget {
  const RoundBtn({super.key, required this.icon, this.onTap, this.size = 52, this.bg, this.fg, this.iconSize, this.label, this.glow});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? bg, fg;
  final double? iconSize;
  final String? label;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      onTap: onTap,
      semantics: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg ?? c.chip,
          shape: BoxShape.circle,
          boxShadow: glow == null ? null : [BoxShadow(color: glow!, blurRadius: 30)],
        ),
        child: Icon(icon, size: iconSize ?? size * 0.46, color: fg ?? c.text),
      ),
    );
  }
}

/// Píldora: botón con texto e ícono opcional.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.text, this.icon, this.onTap, this.primary = false, this.height = 48, this.expand = false, this.danger = false});
  final String text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary, expand, danger;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final fg = primary ? c.onAccent : (danger ? c.redText : c.text);
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: primary ? c.onAccent : (danger ? c.redText : c.accent)), const SizedBox(width: 8)],
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis, style: ts(15, w: FontWeight.w700, c: fg))),
      ],
    );
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Tap(
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: primary ? c.accentGradient : null,
            color: primary ? null : (danger ? alpha(c.red, 0.12) : c.chip),
            borderRadius: BorderRadius.circular(16),
            boxShadow: primary ? [BoxShadow(color: alpha(c.accent, 0.3), blurRadius: 20, offset: const Offset(0, 8))] : null,
          ),
          child: row,
        ),
      ),
    );
  }
}

class Label extends StatelessWidget {
  const Label(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: ts(11, w: FontWeight.w700, c: context.pal.muted, ls: 1.3));
}

/// Ícono de una app instalada (se carga una vez y queda en memoria).
class AppIcon extends StatelessWidget {
  const AppIcon(this.pkg, {super.key, this.size = 56, this.radius});
  final String? pkg;
  final double size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final p = pkg;
    final r = BorderRadius.circular(radius ?? size * 0.3);
    Widget fallback() => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: c.chip, borderRadius: r),
          child: Icon(Icons.add_rounded, color: c.muted, size: size * 0.5),
        );
    if (p == null) return fallback();
    final now = App.i.iconNow(p);
    Widget img(Uint8List b) => ClipRRect(
          borderRadius: r,
          child: Image.memory(b, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
        );
    if (now != null) return img(now);
    return FutureBuilder<Uint8List?>(
      future: App.i.icon(p),
      builder: (_, s) => s.data == null ? SizedBox(width: size, height: size) : img(s.data!),
    );
  }
}

/// Carátula de lo que suena; si no hay, un degradado.
class ArtImage extends StatelessWidget {
  const ArtImage({super.key, required this.session, required this.size, this.radius = 16, this.colors});
  final Session? session;
  final double size;
  final double radius;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.4),
          radius: 1.2,
          colors: colors ?? const [Color(0xFFFFD08A), Color(0xFFE0573B), Color(0xFF5B1F6B)],
        ),
      ),
      child: Icon(Icons.music_note_rounded, color: Colors.white.withAlpha(150), size: size * 0.36),
    );
    if (s == null || s.artKey == null) return placeholder;
    Widget img(Uint8List b) => ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.memory(b, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true),
        );
    final now = App.i.artNow(s);
    if (now != null) return img(now);
    return FutureBuilder<Uint8List?>(
      key: ValueKey(s.artKey),
      future: App.i.art(s),
      builder: (_, snap) => snap.data == null ? placeholder : img(snap.data!),
    );
  }
}

/// Barra de progreso con forma de onda (se puede tocar para adelantar si la app lo permite).
class Waveform extends StatelessWidget {
  const Waveform({super.key, required this.seed, required this.progress, this.height = 36, this.bars = 48, this.onSeek, this.active});
  final String seed;
  final double progress;
  final double height;
  final int bars;
  final ValueChanged<double>? onSeek;
  final Color? active;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final rnd = math.Random(seed.hashCode);
    final hs = List.generate(bars, (i) {
      final v = (math.sin(i * 0.55 + rnd.nextDouble()) * math.cos(i * 0.19)).abs() * 0.8 + rnd.nextDouble() * 0.25;
      return (0.18 + v).clamp(0.15, 1.0);
    });
    return LayoutBuilder(builder: (ctx, box) {
      void seek(Offset p) => onSeek?.call((p.dx / box.maxWidth).clamp(0.0, 1.0));
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onSeek == null ? null : (d) => seek(d.localPosition),
        onHorizontalDragUpdate: onSeek == null ? null : (d) => seek(d.localPosition),
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < bars; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.2),
                    height: height * hs[i],
                    decoration: BoxDecoration(
                      color: i / bars <= progress ? (active ?? c.accentHi) : alpha(c.text, 0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// Anillo de progreso (mantenimiento, batería).
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.color, this.size = 60, this.stroke = 6, this.child});
  final double value;
  final Color color;
  final double size, stroke;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(value.clamp(0.0, 1.0), color, alpha(context.pal.text, 0.08), stroke),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color, this.track, this.stroke);
  final double v, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(r, 0, math.pi * 2, false, p..color = track);
    if (v > 0) canvas.drawArc(r, -math.pi / 2, math.pi * 2 * math.max(v, 0.03), false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.v != v || o.color != color || o.track != track;
}

/// Aviso corto abajo.
void toast(BuildContext context, String text) {
  final c = context.pal;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.panelSolid,
      width: 520,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text(text, style: ts(15, w: FontWeight.w600, c: c.text)),
      duration: const Duration(seconds: 3),
    ));
}
