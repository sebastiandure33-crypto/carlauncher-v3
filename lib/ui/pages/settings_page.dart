import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/settings.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([app.settings, app.perms]),
          builder: (ctx, __) {
            final p = app.perms.value;
            final s = app.settings;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(children: [
                  RoundBtn(icon: Icons.arrow_back_rounded, label: 'Volver', size: 50, onTap: () => Navigator.pop(ctx)),
                  const SizedBox(width: 14),
                  Text('Ajustes', style: ts(26, w: FontWeight.w700, c: c.text)),
                  const Spacer(),
                  Pill(text: 'Ajustes de Android', icon: Icons.open_in_new_rounded, onTap: () => Native.open('android')),
                ]),
              ),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                  _Section('Permisos y arranque', [
                    _Row(
                      icon: Icons.home_rounded,
                      title: 'Pantalla de inicio de la radio',
                      sub: p.home ? 'Car Launcher 4' : 'Otro launcher: tocá y elegí Car Launcher 4 › Siempre',
                      warn: !p.home,
                      onTap: () => Native.open('home'),
                    ),
                    _Row(
                      icon: Icons.location_on_rounded,
                      title: 'Ubicación (GPS)',
                      sub: p.location ? 'Permitida: velocidad, viaje y km' : 'Sin permiso: tocá para permitir',
                      warn: !p.location,
                      onTap: () async {
                        if (!await Native.requestLocation()) await Native.open('appInfo');
                        app.refreshPerms();
                      },
                    ),
                    _Row(
                      icon: Icons.music_note_rounded,
                      title: 'Ver y controlar la música',
                      sub: p.notif ? 'Activado' : 'Activá Car Launcher 4 en Acceso a notificaciones',
                      warn: !p.notif,
                      onTap: () => Native.open('notif'),
                    ),
                    _Row(
                      icon: Icons.brightness_6_rounded,
                      title: 'Cambiar el brillo',
                      sub: p.write ? 'Permitido' : 'Permití "Modificar ajustes del sistema"',
                      warn: !p.write,
                      onTap: () => Native.open('write'),
                    ),
                    _Row(
                      icon: Icons.layers_rounded,
                      title: 'Permiso para abrirse solo',
                      sub: p.overlay ? 'Permitido' : 'Recomendado: "Mostrar sobre otras apps"',
                      warn: !p.overlay,
                      onTap: () => Native.open('overlay'),
                    ),
                    _Switch(
                      icon: Icons.power_settings_new_rounded,
                      title: 'Abrir al dar contacto',
                      sub: 'Vuelve al inicio cuando se prende la pantalla',
                      value: s.ignOpen,
                      onChanged: (v) => s.ignOpen = v,
                    ),
                    _Switch(
                      icon: Icons.auto_awesome_rounded,
                      title: 'Animación del holograma al iniciar',
                      sub: 'Dibuja el auto y revisa cada pieza',
                      value: s.intro,
                      onChanged: (v) => s.intro = v,
                    ),
                  ]),
                  _Section('Destinos', [
                    for (final d in const [('home', 'Casa', Icons.home_rounded), ('work', 'Trabajo', Icons.work_rounded)])
                      _Row(
                        icon: d.$3,
                        title: d.$2,
                        sub: s.place(d.$1) == null
                            ? 'Sin guardar: tocá para guardar la ubicación actual'
                            : 'Guardada (${s.place(d.$1)!.lat.toStringAsFixed(4)}, ${s.place(d.$1)!.lon.toStringAsFixed(4)})',
                        onTap: () async {
                          final g = app.gps.value;
                          if (g == null) {
                            toast(ctx, 'Hace falta señal de GPS');
                            return;
                          }
                          if (await confirm(ctx, d.$2, '¿Guardar la ubicación actual como ${d.$2}?')) {
                            await s.setPlace(d.$1, Place(g.lat, g.lon));
                          }
                        },
                        trailing: s.place(d.$1) == null
                            ? null
                            : RoundBtn(icon: Icons.delete_outline_rounded, label: 'Borrar', size: 44, onTap: () => s.setPlace(d.$1, null)),
                      ),
                  ]),
                  _Section('Apps de cada botón', [
                    for (final sl in Slot.values)
                      _Row(
                        leading: AppIcon(s.slot(sl), size: 40),
                        title: sl.label,
                        sub: s.slot(sl) == null ? 'Sin elegir' : app.labelOf(s.slot(sl)),
                        onTap: () async {
                          final r = await pickApp(ctx, title: 'App para "${sl.label}"', current: s.slot(sl));
                          if (r != null) await s.setSlot(sl, r.isEmpty ? null : r);
                        },
                      ),
                  ]),
                  _Section('Audio', [
                    _Row(
                      icon: Icons.touch_app_rounded,
                      title: 'Modo de los botones de música',
                      sub: '${Settings.mediaModes[s.mediaMode]} · cambialo si play/siguiente no responden',
                      onTap: () async {
                        final v = await showDialog<int>(
                          context: ctx,
                          builder: (dctx) => CarDialog(
                            title: 'Modo de los botones',
                            subtitle: 'Probá otro si la app Bluetooth de la radio no obedece',
                            child: ListView(shrinkWrap: true, children: [
                              for (var i = 0; i < Settings.mediaModes.length; i++)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Tap(
                                    onTap: () => Navigator.pop(dctx, i),
                                    child: Container(
                                      height: 54,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: i == s.mediaMode ? alpha(c.accent, 0.18) : c.chip,
                                        border: Border.all(color: i == s.mediaMode ? c.accent : Colors.transparent),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text('${i + 1}. ${Settings.mediaModes[i]}', style: ts(16, w: FontWeight.w600, c: c.text)),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        );
                        if (v != null) s.mediaMode = v;
                      },
                    ),
                  ]),
                  _Section('Viaje', [
                    _Row(
                      icon: Icons.restart_alt_rounded,
                      title: 'Reiniciar viaje',
                      sub: 'Pone en cero km, minutos y promedio (empieza solo después de 20 min parado)',
                      onTap: () async {
                        if (await confirm(ctx, 'Reiniciar viaje', '¿Poner el viaje en cero?')) await Native.resetTrip();
                      },
                    ),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(6, 0, 6, 8), child: Label(title)),
          Glass(
            padding: const EdgeInsets.symmetric(vertical: 6),
            radius: 22,
            child: Column(children: children),
          ),
        ]),
      );
}

class _Row extends StatelessWidget {
  const _Row({this.icon, this.leading, required this.title, required this.sub, this.onTap, this.warn = false, this.trailing});
  final IconData? icon;
  final Widget? leading;
  final String title, sub;
  final VoidCallback? onTap;
  final bool warn;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          leading ??
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: warn ? alpha(c.red, 0.15) : c.chip, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: warn ? c.red : c.accent, size: 22),
              ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: ts(16, w: FontWeight.w700, c: c.text)),
              Text(sub, style: ts(13, w: FontWeight.w500, c: warn ? c.redText : c.muted)),
            ]),
          ),
          trailing ?? Icon(Icons.chevron_right_rounded, color: c.muted),
        ]),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.icon, required this.title, required this.sub, required this.value, required this.onChanged});
  final IconData icon;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return _Row(
      icon: icon,
      title: title,
      sub: sub,
      onTap: () => onChanged(!value),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: c.onAccent, activeTrackColor: c.accent),
    );
  }
}
