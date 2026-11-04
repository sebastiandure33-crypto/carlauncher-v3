import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/navigation.dart';
import '../../data/settings.dart';
import 'common.dart';
import 'dialogs.dart';

IconData turnIcon(String k) => switch (k) {
      'left' => Icons.turn_left_rounded,
      'right' => Icons.turn_right_rounded,
      'slight_left' => Icons.north_west_rounded,
      'slight_right' => Icons.north_east_rounded,
      'uturn' => Icons.undo_rounded,
      'roundabout' => Icons.rotate_right_rounded,
      'flag' => Icons.flag_rounded,
      _ => Icons.straight_rounded,
    };

/// Ícono para la notificación de Maps / Waze (solo hay texto).
IconData turnIconFromText(String t) {
  final m = t.toLowerCase();
  if (m.contains('izquierda')) return Icons.turn_left_rounded;
  if (m.contains('derecha')) return Icons.turn_right_rounded;
  if (m.contains('rotonda')) return Icons.rotate_right_rounded;
  if (m.contains('destino') || m.contains('llegaste')) return Icons.flag_rounded;
  return Icons.straight_rounded;
}

/// Banner del próximo giro: primero la ruta propia del launcher, si no la de Maps / Waze.
class NavBanner extends StatelessWidget {
  const NavBanner({super.key, this.showStop = false});
  final bool showStop;

  @override
  Widget build(BuildContext context) {
    final app = App.i;
    return ListenableBuilder(
      listenable: Listenable.merge([app.navi.state, app.nav]),
      builder: (_, __) {
        final s = app.navi.state.value;
        final ext = app.nav.value;
        Widget child;
        if (s != null && s.nextStep != null) {
          final st = s.nextStep!;
          child = _Banner(
            key: const ValueKey('own'),
            icon: turnIcon(st.icon),
            big: s.rerouting ? 'Recalculando…' : fmtDist(s.toNextM),
            small: st.text,
            right: '${fmtDist(s.leftM)}\n${fmtTime(s.leftS)}',
            onTap: null,
            onStop: showStop ? app.navi.stop : null,
          );
        } else if (ext != null) {
          child = _Banner(
            key: const ValueKey('ext'),
            icon: turnIconFromText(ext.maneuver),
            big: ext.dist,
            small: [ext.maneuver, ext.street].where((e) => e.isNotEmpty).join(' · '),
            right: ext.eta,
            onTap: () => Native.openNav(),
          );
        } else {
          child = const SizedBox.shrink(key: ValueKey('none'));
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: child);
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.big, required this.small, required this.right, this.onTap, this.onStop});
  final IconData icon;
  final String big, small, right;
  final VoidCallback? onTap, onStop;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: c.accentGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: alpha(c.onAccent, 0.14), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, size: 34, color: c.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(big, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(26, w: FontWeight.w700, c: c.onAccent, h: 1.05)),
              Text(small, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w700, c: alpha(c.onAccent, 0.82))),
            ]),
          ),
          if (right.isNotEmpty)
            Text(right, textAlign: TextAlign.right, style: ts(13, w: FontWeight.w700, c: alpha(c.onAccent, 0.85), h: 1.2)),
          if (onStop != null) ...[
            const SizedBox(width: 8),
            Tap(
              onTap: onStop,
              semantics: 'Terminar ruta',
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: alpha(c.onAccent, 0.14), shape: BoxShape.circle),
                child: Icon(Icons.close_rounded, color: c.onAccent),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Inicia la ruta a un lugar mostrando los errores con un aviso.
Future<void> routeTo(BuildContext context, LatLng p, String name) async {
  try {
    await App.i.navi.start(p, name);
  } catch (_) {
    if (context.mounted) toast(context, 'No se pudo calcular la ruta (¿hay internet?)');
  }
}

/// Casa / Trabajo: si están guardados arma la ruta; si no, ofrece guardar la ubicación actual.
Future<void> goPlace(BuildContext context, String key, String name) async {
  final p = App.i.settings.place(key);
  if (p == null) {
    await savePlace(context, key, name);
    return;
  }
  await routeTo(context, LatLng(p.lat, p.lon), name);
}

Future<void> savePlace(BuildContext context, String key, String name, {LatLng? at}) async {
  final g = App.i.gps.value;
  final p = at ?? (g == null ? null : LatLng(g.lat, g.lon));
  if (p == null) {
    toast(context, 'Para guardar $name hace falta señal de GPS (o mantené apretado un punto del mapa)');
    return;
  }
  final ok = await confirm(context, 'Guardar $name', at == null ? '¿Guardar la ubicación actual como $name?' : '¿Guardar este punto como $name?');
  if (ok) {
    await App.i.settings.setPlace(key, Place(p.latitude, p.longitude));
    if (context.mounted) toast(context, '$name guardada');
  }
}

/// Para el banner del inicio.
NavInfo? currentNav() => App.i.navi.asBanner() ?? App.i.nav.value;
