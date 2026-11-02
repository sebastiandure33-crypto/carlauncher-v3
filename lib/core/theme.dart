import 'package:flutter/material.dart';

/// Colores de la interfaz. Hay una paleta de noche (la principal) y una de día.
class Pal {
  const Pal({
    required this.dark,
    required this.ground,
    required this.rail,
    required this.panel,
    required this.panelSolid,
    required this.field,
    required this.line,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.accentHi,
    required this.accentLo,
    required this.onAccent,
    required this.blue,
    required this.green,
    required this.red,
    required this.redText,
    required this.chip,
    required this.shadow,
  });

  final bool dark;
  final Color ground, rail, panel, panelSolid, field, line, text, text2, muted;
  final Color accent, accentHi, accentLo, onAccent, blue, green, red, redText, chip, shadow;

  static const night = Pal(
    dark: true,
    ground: Color(0xFF07090D),
    rail: Color(0xFF0B0E13),
    panel: Color(0xD10D1016),
    panelSolid: Color(0xFF12151B),
    field: Color(0x66000000),
    line: Color(0x12FFFFFF),
    text: Color(0xFFEEF1F5),
    text2: Color(0xFFC9CFD8),
    muted: Color(0xFF8D96A5),
    accent: Color(0xFFFFB547),
    accentHi: Color(0xFFFFD08A),
    accentLo: Color(0xFFF09A1E),
    onAccent: Color(0xFF1A1206),
    blue: Color(0xFF6CC8FF),
    green: Color(0xFF6BE39A),
    red: Color(0xFFFF6B5B),
    redText: Color(0xFFFFB2A8),
    chip: Color(0x12FFFFFF),
    shadow: Color(0x80000000),
  );

  static const day = Pal(
    dark: false,
    ground: Color(0xFFE9EEF4),
    rail: Color(0xFFFFFFFF),
    panel: Color(0xEBFFFFFF),
    panelSolid: Color(0xFFFFFFFF),
    field: Color(0x0F0E1A2B),
    line: Color(0x140E1A2B),
    text: Color(0xFF0E1A2B),
    text2: Color(0xFF34414F),
    muted: Color(0xFF5B6878),
    accent: Color(0xFFF2A230),
    accentHi: Color(0xFFFFC56E),
    accentLo: Color(0xFFD98410),
    onAccent: Color(0xFF1A1206),
    blue: Color(0xFF1B6FC0),
    green: Color(0xFF1E9150),
    red: Color(0xFFD63B2C),
    redText: Color(0xFFB02A1E),
    chip: Color(0x0F0E1A2B),
    shadow: Color(0x26283C5A),
  );

  Gradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accentHi, accent, accentLo],
        stops: const [0, 0.55, 1],
      );
}

/// Da la paleta actual a toda la interfaz.
class PalScope extends InheritedWidget {
  const PalScope({super.key, required this.pal, required super.child});
  final Pal pal;

  static Pal of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<PalScope>()?.pal ?? Pal.night;

  @override
  bool updateShouldNotify(PalScope old) => old.pal != pal;
}

extension PalX on BuildContext {
  Pal get pal => PalScope.of(this);
}

/// Estilo de texto con la fuente Barlow.
TextStyle ts(double size, {FontWeight w = FontWeight.w500, Color? c, double? ls, double? h}) =>
    TextStyle(fontFamily: 'Barlow', fontSize: size, fontWeight: w, color: c, letterSpacing: ls, height: h);

Color alpha(Color c, double o) => c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

/// Formato 12.345
String miles(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

String dec1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String mmss(int ms) {
  final s = (ms / 1000).floor();
  return '${s ~/ 60}:${two(s % 60)}';
}

const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

String fechaCorta(DateTime d) => '${dias[d.weekday - 1]} ${d.day} ${meses[d.month - 1]}';
String fechaLarga(DateTime d) => '${d.day} ${meses[d.month - 1]} ${d.year}';
