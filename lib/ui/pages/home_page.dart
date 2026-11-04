import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';
import '../widgets/holo_car.dart';
import '../widgets/map_view.dart';
import '../widgets/nav_widgets.dart';
import 'map_page.dart' show openMapSearch;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const side = 252.0, pad = 14.0;
    return Stack(fit: StackFit.expand, children: [
      CarMap(
        padding: const EdgeInsets.fromLTRB(side + pad, 80, side + pad, 80),
        onLongPress: (_) => shellTab.value = 4,
      ),
      const Positioned(
        top: pad,
        left: pad,
        bottom: pad,
        width: side,
        child: Column(children: [_SpeedCard(), SizedBox(height: 10), Expanded(child: _WeatherCard())]),
      ),
      const Positioned(
        top: pad,
        right: pad,
        bottom: pad,
        width: side,
        child: Column(children: [_MediaCard(), SizedBox(height: 10), Expanded(child: _CarCard())]),
      ),
      const Positioned(top: pad, left: side + pad * 2, right: side + pad * 2, child: NavBanner()),
      const Positioned(bottom: pad, left: side + pad * 2, right: side + pad * 2, child: _Destinations()),
    ]);
  }
}

/* ------------------------------------------------------------ velocidad */

class _SpeedCard extends StatelessWidget {
  const _SpeedCard();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return Glass(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(children: [
        ListenableBuilder(
          listenable: Listenable.merge([app.gps, app.settings]),
          builder: (_, __) => SpeedGauge(speed: app.gps.value?.speed, limit: app.settings.speedLimit),
        ),
        const SizedBox(height: 8),
        Container(height: 1, color: c.line),
        const SizedBox(height: 8),
        ValueListenableBuilder<Trip>(
          valueListenable: app.trip,
          builder: (_, t, __) => Row(children: [
            _stat(c, dec1(t.km), 'km viaje'),
            Container(width: 1, height: 30, color: c.line),
            _stat(c, '${t.minutes}', 'minutos'),
            Container(width: 1, height: 30, color: c.line),
            _stat(c, '${t.avg.round()}', 'prom km/h'),
          ]),
        ),
      ]),
    );
  }

  Widget _stat(Pal c, String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: ts(18, w: FontWeight.w700, c: c.text)),
          Text(l.toUpperCase(), style: ts(10, w: FontWeight.w600, c: c.muted, ls: 0.8)),
        ]),
      );
}

/* ------------------------------------------------------------ clima */

IconData weatherIcon(int code, bool night) {
  if (code == 0) return night ? Icons.nightlight_round : Icons.wb_sunny_rounded;
  if (code <= 2) return night ? Icons.nights_stay_rounded : Icons.wb_cloudy_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.blur_on_rounded;
  if (code >= 71 && code <= 77) return Icons.ac_unit_rounded;
  if (code >= 95) return Icons.thunderstorm_rounded;
  if (code >= 51) return Icons.water_drop_rounded;
  return Icons.wb_cloudy_rounded;
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return ListenableBuilder(
      listenable: Listenable.merge([app.weather, app.night]),
      builder: (_, __) {
        final w = app.weather.value;
        final sun = app.sunTimes();
        return Glass(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Stack(children: [
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [alpha(c.accent, 0.35), alpha(c.accent, 0)]),
                ),
              ),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [
                Expanded(
                  child: w == null
                      ? Text('Sin datos del clima\n(necesita internet una vez)', style: ts(14, w: FontWeight.w600, c: c.text2))
                      : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${w.temp}°', style: ts(44, w: FontWeight.w400, c: c.text, ls: -1.5, h: 1)),
                          const SizedBox(height: 4),
                          Text('${w.description} · ${w.max}° / ${w.min}°',
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w600, c: c.text2)),
                          if (w.ago != null) Text(w.ago!, style: ts(12, c: c.muted)),
                        ]),
                ),
                if (w != null) Icon(weatherIcon(w.code, app.night.value), size: 46, color: c.accentHi),
              ]),
              Row(children: [
                _chip(c, 'Humedad', w == null ? '--' : '${w.humidity}%'),
                const SizedBox(width: 6),
                _chip(c, 'Viento', w == null ? '--' : '${w.wind} km/h'),
                const SizedBox(width: 6),
                _chip(c, app.night.value ? 'Amanece' : 'Noche', sun == null ? '--' : hhmm(app.night.value ? sun.$1 : sun.$2)),
              ]),
            ]),
          ]),
        );
      },
    );
  }

  Widget _chip(Pal c, String l, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.toUpperCase(), style: ts(10, w: FontWeight.w600, c: c.muted, ls: 0.6)),
            Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w700, c: c.text)),
          ]),
        ),
      );
}

/* ------------------------------------------------------------ música */

/// Reconstruye cada segundo (para la barra de progreso).
class EverySecond extends StatefulWidget {
  const EverySecond({super.key, required this.builder});
  final WidgetBuilder builder;
  @override
  State<EverySecond> createState() => _EverySecondState();
}

class _EverySecondState extends State<EverySecond> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _MediaCard extends StatelessWidget {
  const _MediaCard();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return ValueListenableBuilder<MediaState>(
      valueListenable: App.i.media,
      builder: (_, m, __) {
        final s = m.now;
        return Tap(
          onTap: () => shellTab.value = 1,
          child: Container(
            height: 214,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.panelSolid,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.line),
              boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 14))],
            ),
            child: Stack(children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -1),
                      radius: 1.3,
                      colors: [alpha(const Color(0xFFFF8C46), c.dark ? 0.42 : 0.25), alpha(const Color(0xFFFF8C46), 0)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: !m.permission
                    ? _NoPermission(c)
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          ArtImage(session: s, size: 72),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text((s?.label ?? 'Música').toUpperCase(),
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(11, w: FontWeight.w700, c: c.blue, ls: 1)),
                              const SizedBox(height: 3),
                              Text(s == null || s.title.isEmpty ? 'Sin reproducción' : s.title,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(17, w: FontWeight.w700, c: c.text)),
                              Text(s == null ? 'Poné música en el teléfono o en la radio' : s.artist,
                                  maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, c: c.text2)),
                            ]),
                          ),
                        ]),
                        const Spacer(),
                        EverySecond(
                          builder: (_) => Waveform(
                            seed: s?.title ?? '',
                            bars: 30,
                            height: 24,
                            progress: s == null || s.dur <= 0 ? 0 : s.positionNow() / s.dur,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          RoundBtn(icon: Icons.skip_previous_rounded, label: 'Anterior', bg: Colors.transparent, size: 46,
                              onTap: () => Native.media('prev', pkg: s?.pkg)),
                          RoundBtn(
                            icon: s?.playing == true ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            label: s?.playing == true ? 'Pausa' : 'Reproducir',
                            size: 54,
                            bg: c.text,
                            fg: c.ground,
                            onTap: () async {
                              final msg = await App.i.playSource(Slot.music, session: s);
                              if (msg.isNotEmpty && context.mounted) toast(context, msg);
                            },
                          ),
                          RoundBtn(icon: Icons.skip_next_rounded, label: 'Siguiente', bg: Colors.transparent, size: 46,
                              onTap: () => Native.media('next', pkg: s?.pkg)),
                        ]),
                      ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission(this.c);
  final Pal c;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.music_note_rounded, color: c.accent, size: 34),
        const SizedBox(height: 8),
        Text('Para ver y controlar la música', style: ts(16, w: FontWeight.w700, c: c.text)),
        Text('Activá Car Launcher 4 en "Acceso a notificaciones".', style: ts(13, c: c.text2)),
        const SizedBox(height: 12),
        Pill(text: 'Permitir', icon: Icons.lock_open_rounded, primary: true, onTap: () => Native.open('notif')),
      ]);
}

/* ------------------------------------------------------------ auto */

class _CarCard extends StatefulWidget {
  const _CarCard();
  @override
  State<_CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<_CarCard> {
  late bool intro = App.i.introPending;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final m = App.i.maint;
    return Tap(
      onTap: () => shellTab.value = 2,
      child: Glass(
        padding: const EdgeInsets.all(12),
        child: ListenableBuilder(
          listenable: m,
          builder: (_, __) {
            final alerts = m.alerts;
            final warnParts = <String>{
              for (final r in m.kmRows) if (r.warn) r.id,
              if (m.dateRows.any((r) => r.warn)) 'docs',
            };
            return Row(children: [
              SizedBox(
                width: 84,
                child: HoloCar(
                  compact: true,
                  intro: intro,
                  warn: warnParts,
                  onIntroDone: () => App.i.introPending = false,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Label('Tu auto'),
                  const SizedBox(height: 4),
                  Text(m.odo == null ? 'Cargá los km' : miles(m.odo!), style: ts(24, w: FontWeight.w700, c: c.text, ls: -0.5)),
                  Text(m.odo == null ? 'tocá para empezar' : 'km en el tablero', style: ts(12, c: c.muted)),
                  const SizedBox(height: 8),
                  if (alerts.isEmpty)
                    _line(c, c.green, 'Todo en orden', false)
                  else
                    for (final a in alerts.take(2)) ...[_line(c, c.red, a, true), const SizedBox(height: 6)],
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _line(Pal c, Color dot, String text, bool warn) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: warn ? alpha(c.red, 0.12) : c.chip,
          borderRadius: BorderRadius.circular(12),
          border: warn ? Border.all(color: alpha(c.red, 0.3)) : null,
        ),
        child: Row(children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: dot, boxShadow: [BoxShadow(color: dot, blurRadius: 6)])),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w700, c: warn ? c.redText : c.text2)),
          ),
        ]),
      );
}

/* ------------------------------------------------------------ destinos */

class _Destinations extends StatelessWidget {
  const _Destinations();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    Widget btn(IconData i, String label, String key) => Expanded(
          child: Tap(
            onTap: () => goPlace(context, key, label),
            onLong: () => savePlace(context, key, label),
            child: Container(
              height: 50,
              decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, color: c.accentHi, size: 20),
                const SizedBox(width: 8),
                Text(label, style: ts(15, w: FontWeight.w700, c: c.text)),
              ]),
            ),
          ),
        );
    return Glass(
      padding: const EdgeInsets.all(8),
      radius: 22,
      child: Row(children: [
        btn(Icons.home_rounded, 'Casa', 'home'),
        const SizedBox(width: 8),
        btn(Icons.work_rounded, 'Trabajo', 'work'),
        const SizedBox(width: 8),
        Tap(
          onTap: openMapSearch,
          semantics: 'Buscar destino',
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.search_rounded, color: c.text),
          ),
        ),
      ]),
    );
  }
}
