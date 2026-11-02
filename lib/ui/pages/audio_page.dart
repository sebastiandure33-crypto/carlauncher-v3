import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'home_page.dart' show EverySecond;

class AudioPage extends StatefulWidget {
  const AudioPage({super.key});
  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  String? _appsPkg; // app elegida en la pestaña "Apps de música"

  static const _tabs = [
    (AudioSource.bt, 'Bluetooth', Slot.music),
    (AudioSource.radio, 'Radio FM', Slot.radio),
    (AudioSource.apps, 'Apps de música', null),
    (AudioSource.usb, 'USB', Slot.usb),
  ];

  Slot? _slotOf(AudioSource s) => switch (s) {
        AudioSource.bt => Slot.music,
        AudioSource.radio => Slot.radio,
        AudioSource.usb => Slot.usb,
        AudioSource.apps => null,
      };

  Future<void> _chooseSlot(Slot s) async {
    final r = await pickApp(context, title: 'App para "${s.label}"', current: App.i.settings.slot(s));
    if (r != null) await App.i.settings.setSlot(s, r.isEmpty ? null : r);
  }

  List<Color> _bg(AudioSource s) => switch (s) {
        AudioSource.bt => const [Color(0xFFE86E3C), Color(0xFF7832AA)],
        AudioSource.radio => const [Color(0xFF28AAC8), Color(0xFFFFAA3C)],
        AudioSource.apps => const [Color(0xFF2FBF71), Color(0xFF2A6FB8)],
        AudioSource.usb => const [Color(0xFF4F7BE8), Color(0xFF9A4CC8)],
      };

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return ListenableBuilder(
      listenable: Listenable.merge([audioSource, app.media, app.settings]),
      builder: (_, __) {
        final src = audioSource.value;
        final m = app.media.value;
        final slot = _slotOf(src);
        final pkg = slot == null ? (_appsPkg ?? m.now?.pkg) : app.settings.slot(slot);
        Session? s = m.forPkg(pkg);
        if (s == null && src == AudioSource.bt && pkg == null) s = m.now;
        final bg = _bg(src);
        return Stack(fit: StackFit.expand, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              color: c.ground,
              gradient: RadialGradient(
                center: const Alignment(-0.7, -0.6),
                radius: 1.2,
                colors: [alpha(bg[0], c.dark ? 0.40 : 0.22), alpha(bg[0], 0)],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.6, 0.5),
                radius: 1.0,
                colors: [alpha(bg[1], c.dark ? 0.34 : 0.18), alpha(bg[1], 0)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _header(c, src),
              const SizedBox(height: 14),
              Expanded(
                child: !m.permission
                    ? _permission(c)
                    : src == AudioSource.radio
                        ? _RadioView(session: s, pkg: pkg, onChoose: () => _chooseSlot(Slot.radio))
                        : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Expanded(
                              child: _Player(
                                session: s,
                                pkg: pkg,
                                sourceLabel: slot == null ? null : slot.label,
                                onChoose: slot == null ? null : () => _chooseSlot(slot),
                              ),
                            ),
                            const SizedBox(width: 14),
                            SizedBox(
                              width: 256,
                              child: Column(children: [
                                if (src == AudioSource.bt) ...[const _PhoneCard(), const SizedBox(height: 14)],
                                Expanded(
                                  child: _Sources(
                                    m: m,
                                    exclude: s?.pkg,
                                    onPick: (p) {
                                      final st = app.settings;
                                      if (p == st.slot(Slot.music)) {
                                        audioSource.value = AudioSource.bt;
                                      } else if (p == st.slot(Slot.radio)) {
                                        audioSource.value = AudioSource.radio;
                                      } else if (p == st.slot(Slot.usb)) {
                                        audioSource.value = AudioSource.usb;
                                      } else {
                                        setState(() => _appsPkg = p);
                                        audioSource.value = AudioSource.apps;
                                      }
                                    },
                                  ),
                                ),
                              ]),
                            ),
                          ]),
              ),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _header(Pal c, AudioSource src) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
        child: Row(children: [
          for (final t in _tabs)
            Tap(
              onTap: () => audioSource.value = t.$1,
              onLong: t.$3 == null ? null : () => _chooseSlot(t.$3!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.$1 == src ? c.text : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(t.$2, style: ts(15, w: FontWeight.w700, c: t.$1 == src ? c.ground : c.text2)),
              ),
            ),
        ]),
      ),
      const Spacer(),
      const _VolumeBar(),
      const SizedBox(width: 10),
      RoundBtn(
        icon: Icons.equalizer_rounded,
        label: 'Ecualizador',
        size: 48,
        bg: c.field,
        onTap: () async {
          final eq = App.i.settings.slot(Slot.eq);
          final ok = eq != null ? await Native.launch(eq) : await Native.open('eq');
          if (!ok && mounted) toast(context, 'No hay ecualizador. Elegí una app en Ajustes › Audio');
        },
      ),
    ]);
  }

  Widget _permission(Pal c) => Center(
        child: Glass(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock_open_rounded, color: c.accent, size: 40),
            const SizedBox(height: 10),
            Text('Permitir ver y controlar la música', style: ts(20, w: FontWeight.w700, c: c.text)),
            const SizedBox(height: 4),
            Text('En "Acceso a notificaciones" activá Car Launcher 4.', style: ts(15, c: c.text2)),
            const SizedBox(height: 16),
            Pill(text: 'Abrir permiso', primary: true, onTap: () => Native.open('notif')),
          ]),
        ),
      );
}

/* ------------------------------------------------------------ volumen */

class _VolumeBar extends StatefulWidget {
  const _VolumeBar();
  @override
  State<_VolumeBar> createState() => _VolumeBarState();
}

class _VolumeBarState extends State<_VolumeBar> {
  int cur = 0, max = 15;

  @override
  void initState() {
    super.initState();
    _load();
    shellTab.addListener(_load);
  }

  @override
  void dispose() {
    shellTab.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final v = await Native.volume();
    if (mounted) {
      setState(() {
        cur = v.$1;
        max = v.$2;
      });
    }
  }

  void _set(double f) {
    final v = (f * max).round().clamp(0, max).toInt();
    if (v != cur) {
      setState(() => cur = v);
      Native.setVolume(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
      child: Row(children: [
        Icon(cur == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: c.text2, size: 20),
        const SizedBox(width: 10),
        SizedBox(
          width: 150,
          child: LayoutBuilder(
            builder: (_, b) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _set(d.localPosition.dx / b.maxWidth),
              onHorizontalDragUpdate: (d) => _set((d.localPosition.dx / b.maxWidth).clamp(0.0, 1.0)),
              child: SizedBox(
                height: 40,
                child: Center(
                  child: Stack(children: [
                    Container(height: 6, decoration: BoxDecoration(color: alpha(c.text, 0.14), borderRadius: BorderRadius.circular(3))),
                    FractionallySizedBox(
                      widthFactor: max == 0 ? 0 : cur / max,
                      child: Container(height: 6, decoration: BoxDecoration(color: c.text, borderRadius: BorderRadius.circular(3))),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 22, child: Text('$cur', style: ts(14, w: FontWeight.w700, c: c.text2))),
      ]),
    );
  }
}

/* ------------------------------------------------------------ reproductor */

class _Player extends StatelessWidget {
  const _Player({required this.session, required this.pkg, this.sourceLabel, this.onChoose});
  final Session? session;
  final String? pkg;
  final String? sourceLabel;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final s = session;
    final target = s?.pkg ?? pkg;
    return Glass(
      padding: const EdgeInsets.all(22),
      radius: 28,
      color: alpha(c.panelSolid, c.dark ? 0.55 : 0.8),
      child: Row(children: [
        Stack(children: [
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(0, 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: alpha(const Color(0xFFE0573B), c.dark ? 0.45 : 0.25), blurRadius: 40)],
                ),
              ),
            ),
          ),
          ArtImage(session: s, size: 236, radius: 26),
        ]),
        const SizedBox(width: 26),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Tap(
              onTap: () => Native.launch(target),
              onLong: onChoose,
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: alpha(c.blue, 0.14), borderRadius: BorderRadius.circular(15)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.open_in_new_rounded, size: 14, color: c.blue),
                  const SizedBox(width: 6),
                  Text(target == null ? 'Mantené apretado para elegir la app' : App.i.labelOf(target),
                      style: ts(13, w: FontWeight.w700, c: c.blue)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text(s == null ? 'Sin reproducción' : (s.title.isEmpty ? (s.playing ? 'Reproduciendo' : 'En pausa') : s.title),
                maxLines: 2, overflow: TextOverflow.ellipsis, style: ts(30, w: FontWeight.w700, c: c.text, ls: -0.5, h: 1.1)),
            const SizedBox(height: 6),
            Text(
              s == null
                  ? (target == null ? 'Elegí la app de ${sourceLabel ?? 'música'}' : 'Tocá play o abrí la app')
                  : [s.artist, s.album].where((e) => e.isNotEmpty).join(' — '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(17, c: c.text2),
            ),
            const SizedBox(height: 18),
            EverySecond(builder: (_) {
              final pos = s?.positionNow() ?? 0;
              final dur = s?.dur ?? 0;
              return Column(children: [
                Waveform(
                  seed: s?.title ?? '',
                  bars: 56,
                  height: 40,
                  progress: dur <= 0 ? 0 : pos / dur,
                  onSeek: s != null && s.canSeek && dur > 0 ? (f) => Native.media('seek', pkg: s.pkg, pos: (f * dur).round()) : null,
                ),
                const SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(dur > 0 ? mmss(pos) : '', style: ts(13, w: FontWeight.w600, c: c.muted)),
                  Text(dur > 0 ? mmss(dur) : '', style: ts(13, w: FontWeight.w600, c: c.muted)),
                ]),
              ]);
            }),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              RoundBtn(icon: Icons.skip_previous_rounded, label: 'Anterior', size: 62, onTap: () => Native.media('prev', pkg: target)),
              RoundBtn(
                icon: s?.playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: s?.playing == true ? 'Pausa' : 'Reproducir',
                size: 84,
                bg: c.text,
                fg: c.ground,
                glow: alpha(const Color(0xFFFFC896), c.dark ? 0.35 : 0.2),
                onTap: () => Native.media('toggle', pkg: target),
              ),
              RoundBtn(icon: Icons.skip_next_rounded, label: 'Siguiente', size: 62, onTap: () => Native.media('next', pkg: target)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/* ------------------------------------------------------------ teléfono */

class _PhoneCard extends StatelessWidget {
  const _PhoneCard();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return ValueListenableBuilder<BtInfo>(
      valueListenable: App.i.bt,
      builder: (_, b, __) => Glass(
        padding: const EdgeInsets.all(16),
        color: alpha(c.panelSolid, c.dark ? 0.6 : 0.85),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Ring(
              value: b.battery >= 0 ? b.battery / 100 : (b.connected ? 1 : 0),
              color: b.connected ? c.green : c.muted,
              size: 58,
              stroke: 5,
              child: Icon(Icons.smartphone_rounded, color: c.text, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.connected ? b.name! : 'Bluetooth de la radio',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, w: FontWeight.w700, c: c.text)),
                Text(
                  b.connected
                      ? (b.battery >= 0 ? 'Conectado · batería ${b.battery}%' : 'Conectado')
                      : (b.available && !b.on ? 'Bluetooth apagado' : 'Se maneja desde su app'),
                  style: ts(13, w: FontWeight.w600, c: b.connected ? c.green : c.muted),
                ),
              ]),
            ),
          ]),
          if (b.connected) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              if (b.audio) _chip(c, 'Audio'),
              if (b.calls) _chip(c, 'Llamadas'),
            ]),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Pill(
                text: 'Bluetooth',
                height: 44,
                expand: true,
                onTap: () async {
                  final st = App.i.settings;
                  if (!await Native.launch(st.slot(Slot.music))) await Native.open('bt');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Pill(text: 'Teléfono', height: 44, expand: true, onTap: () => App.i.openSlot(Slot.phone))),
          ]),
        ]),
      ),
    );
  }

  Widget _chip(Pal c, String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: ts(12, w: FontWeight.w700, c: c.text2)),
      );
}

/* ------------------------------------------------------------ otras fuentes */

class _Sources extends StatelessWidget {
  const _Sources({required this.m, required this.exclude, required this.onPick});
  final MediaState m;
  final String? exclude;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final list = m.sessions.where((s) => s.pkg != exclude).toList();
    return Glass(
      padding: const EdgeInsets.all(14),
      color: alpha(c.panelSolid, c.dark ? 0.6 : 0.85),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 8), child: Label('Otras fuentes')),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text('Cuando otra app reproduzca música aparece acá.', style: ts(13, c: c.muted)),
          ),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            for (final s in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Tap(
                  onTap: () => onPick(s.pkg),
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      AppIcon(s.pkg, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w700, c: c.text)),
                          if (s.title.isNotEmpty)
                            Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, c: c.muted)),
                        ]),
                      ),
                      Icon(s.playing ? Icons.graphic_eq_rounded : Icons.chevron_right_rounded, color: s.playing ? c.green : c.muted),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

/* ------------------------------------------------------------ radio FM */

/// La sintonía la hace la app de radio de la pantalla; acá se muestra la frecuencia
/// que informa esa app y se buscan emisoras con sus botones.
class _RadioView extends StatelessWidget {
  const _RadioView({required this.session, required this.pkg, required this.onChoose});
  final Session? session;
  final String? pkg;
  final VoidCallback onChoose;

  static double? freqOf(Session? s) {
    if (s == null) return null;
    for (final t in [s.title, s.artist, s.album]) {
      for (final m in RegExp(r'(\d{2,3})[.,](\d{1,2})').allMatches(t)) {
        final v = double.tryParse('${m.group(1)}.${m.group(2)}');
        if (v != null && v >= 87.5 && v <= 108.0) return v;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final s = session;
    final f = freqOf(s);
    final station = s == null
        ? ''
        : [s.title, s.artist].where((t) => t.isNotEmpty && !t.contains(f?.toStringAsFixed(1) ?? '§')).join(' · ');
    return Glass(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      radius: 28,
      color: alpha(c.panelSolid, c.dark ? 0.55 : 0.8),
      child: Column(children: [
        SizedBox(
          height: 150,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: f ?? 98),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => CustomPaint(size: Size.infinite, painter: _DialPainter(v, f != null, c)),
          ),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RoundBtn(icon: Icons.fast_rewind_rounded, label: 'Buscar emisora anterior', size: 64, onTap: () => Native.media('prev', pkg: pkg)),
          const SizedBox(width: 30),
          Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(f == null ? '--.-' : f.toStringAsFixed(1), style: ts(84, w: FontWeight.w400, c: c.text, ls: -3, h: 1)),
              const SizedBox(width: 6),
              Text('MHz', style: ts(22, w: FontWeight.w600, c: c.muted)),
            ]),
            const SizedBox(height: 4),
            Text(
              s == null ? (pkg == null ? 'Mantené apretado "Radio FM" para elegir la app de radio' : 'Abrí la radio para empezar') : (station.isEmpty ? App.i.labelOf(s.pkg) : station),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ts(16, w: FontWeight.w700, c: c.text2),
            ),
          ]),
          const SizedBox(width: 30),
          RoundBtn(icon: Icons.fast_forward_rounded, label: 'Buscar emisora siguiente', size: 64, onTap: () => Native.media('next', pkg: pkg)),
        ]),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          RoundBtn(
            icon: s?.playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded,
            label: s?.playing == true ? 'Pausa' : 'Reproducir',
            size: 64,
            bg: c.text,
            fg: c.ground,
            onTap: () => Native.media('toggle', pkg: pkg),
          ),
          const SizedBox(width: 16),
          Pill(
            text: pkg == null ? 'Elegir app de radio' : 'Abrir ${App.i.labelOf(pkg)}',
            icon: Icons.radio_rounded,
            height: 56,
            onTap: pkg == null ? onChoose : () => Native.launch(pkg),
          ),
        ]),
      ]),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter(this.f, this.on, this.c);
  final double f;
  final bool on;
  final Pal c;

  @override
  void paint(Canvas canvas, Size size) {
    const lo = 87.5, hi = 108.0;
    final x0 = 20.0, x1 = size.width - 20;
    const base = 128.0, lift = 70.0;
    double fx(double v) => x0 + (v - lo) / (hi - lo) * (x1 - x0);
    double fy(double x) => base - lift * math.sin(math.pi * (x - x0) / (x1 - x0));

    final arc = Path();
    for (var x = x0; x <= x1; x += 8) {
      if (x == x0) {
        arc.moveTo(x, fy(x) + 6);
      } else {
        arc.lineTo(x, fy(x) + 6);
      }
    }
    canvas.drawPath(arc, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(colors: [alpha(c.blue, 0), alpha(c.blue, 0.6), alpha(c.blue, 0)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    for (var k = 0; k <= 41; k++) {
      final v = lo + k * 0.5;
      final x = fx(v), y = fy(x);
      final major = (v * 10).round() % 20 == 0;
      canvas.drawLine(Offset(x, y), Offset(x, y - (major ? 22 : 11)), Paint()
        ..strokeWidth = major ? 2.5 : 2
        ..strokeCap = StrokeCap.round
        ..color = alpha(c.text, major ? 0.6 : 0.22));
      if (major) {
        final tp = TextPainter(
          text: TextSpan(text: v.toStringAsFixed(0), style: ts(12, w: FontWeight.w700, c: c.muted)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y + 10));
      }
    }
    if (on) {
      final nx = fx(f.clamp(lo, hi)), ny = fy(nx);
      final p1 = Offset(nx, ny + 8), p2 = Offset(nx, ny - 46);
      canvas.drawLine(p1, p2, Paint()
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = alpha(c.accent, 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawLine(p1, p2, Paint()
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..color = c.accentHi);
    }
  }

  @override
  bool shouldRepaint(_DialPainter o) => o.f != f || o.on != on || o.c != c;
}
