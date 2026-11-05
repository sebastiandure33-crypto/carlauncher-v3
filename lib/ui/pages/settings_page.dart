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
                        sub: s.slot(sl) == null
                            ? 'Sin elegir'
                            : app.labelOf(s.slot(sl)) + (s.slotIsAuto(sl) ? ' · detectada sola' : ''),
                        onTap: () async {
                          final r = await pickApp(ctx, title: 'App para "${sl.label}"', current: s.slot(sl));
                          if (r != null) await s.setSlot(sl, r);
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
                    _Switch(
                      icon: Icons.replay_rounded,
                      title: 'Al tocar play, abrir la app y volver',
                      sub: 'Si la radio o el Bluetooth no están abiertos, los abre para que suenen y vuelve al inicio',
                      value: s.returnAfterLaunch,
                      onChanged: (v) => s.returnAfterLaunch = v,
                    ),
                  ]),
                  _Section('Diagnóstico', [
                    _Row(
                      icon: Icons.troubleshoot_rounded,
                      title: 'Revisar música, Bluetooth, volumen y brillo',
                      sub: 'Muestra qué ve la app y permite probar cada modo de los botones',
                      onTap: () => Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const DiagPage())),
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


/// Diagnóstico: qué sesiones de música ve la app, Bluetooth, volumen y brillo,
/// y botones para probar cada modo de envío de play / siguiente.
class DiagPage extends StatefulWidget {
  const DiagPage({super.key});
  @override
  State<DiagPage> createState() => _DiagPageState();
}

class _DiagPageState extends State<DiagPage> {
  List<String> _lines = const [];
  String _result = '';
  Slot _target = Slot.music;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = App.i.settings;
    final l = await Native.diag([
      for (final sl in const [Slot.music, Slot.radio])
        if (s.slot(sl) != null) s.slot(sl)!,
    ]);
    final extra = [
      '— Apps elegidas —',
      for (final sl in Slot.values) '${sl.label}: ${s.slot(sl) ?? 'sin elegir'}${s.slotIsAuto(sl) ? ' (detectada)' : ''}',
      '— Apps instaladas (nombre — paquete) —',
      for (final a in await App.i.apps(refresh: true)) '${a.label} — ${a.pkg}',
    ];
    if (mounted) setState(() => _lines = [...l, ...extra]);
  }

  Future<void> _test(String cmd, int mode) async {
    final pkg = App.i.settings.slot(_target);
    final r = await Native.mediaTest(cmd, mode, pkg);
    if (!mounted) return;
    setState(() => _result = 'Modo ${mode + 1} · $cmd → $r');
    Future.delayed(const Duration(milliseconds: 800), _refresh);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Scaffold(
      backgroundColor: c.ground,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            RoundBtn(icon: Icons.arrow_back_rounded, label: 'Volver', size: 50, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Text('Diagnóstico', style: ts(26, w: FontWeight.w700, c: c.text)),
            const Spacer(),
            Pill(text: 'Actualizar', icon: Icons.refresh_rounded, onTap: _refresh),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                flex: 6,
                child: Glass(
                  color: c.panelSolid,
                  child: ListView(children: [
                    for (final l in _lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(l, style: ts(l.startsWith('—') ? 15 : 14, w: l.startsWith('—') ? FontWeight.w700 : FontWeight.w500, c: l.startsWith('—') ? c.accent : c.text2)),
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 5,
                child: Glass(
                  color: c.panelSolid,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Label('Probar botones en'),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (final sl in const [Slot.music, Slot.radio, Slot.usb]) ...[
                        Expanded(
                          child: Tap(
                            onTap: () => setState(() => _target = sl),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _target == sl ? c.text : c.chip,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(sl.label, style: ts(14, w: FontWeight.w700, c: _target == sl ? c.ground : c.text2)),
                            ),
                          ),
                        ),
                        if (sl != Slot.usb) const SizedBox(width: 6),
                      ],
                    ]),
                    const SizedBox(height: 10),
                    Text('Poné música y probá: el modo que pausa o cambia de tema es el que hay que elegir.',
                        style: ts(13, c: c.muted)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(children: [
                        for (var m = 0; m < Settings.mediaModes.length; m++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Expanded(
                                child: Text('${m + 1}. ${Settings.mediaModes[m]}',
                                    style: ts(14, w: m == App.i.settings.mediaMode ? FontWeight.w700 : FontWeight.w500, c: m == App.i.settings.mediaMode ? c.accent : c.text)),
                              ),
                              RoundBtn(icon: Icons.play_arrow_rounded, label: 'Play/pausa modo ${m + 1}', size: 42, onTap: () => _test('toggle', m)),
                              const SizedBox(width: 6),
                              RoundBtn(icon: Icons.skip_next_rounded, label: 'Siguiente modo ${m + 1}', size: 42, onTap: () => _test('next', m)),
                              const SizedBox(width: 6),
                              Pill(
                                text: 'Usar',
                                height: 42,
                                onTap: () => setState(() => App.i.settings.mediaMode = m),
                              ),
                            ]),
                          ),
                      ]),
                    ),
                    if (_result.isNotEmpty) Text(_result, style: ts(13, w: FontWeight.w600, c: c.text2)),
                    const SizedBox(height: 8),
                    Pill(
                      text: 'Buscar órdenes en la app ${_target.label}',
                      icon: Icons.manage_search_rounded,
                      primary: true,
                      expand: true,
                      onTap: () {
                        final pkg = App.i.settings.slot(_target);
                        if (pkg == null) {
                          toast(context, 'Primero elegí la app de ${_target.label}');
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProbePage(pkg: pkg, title: _target.label)));
                      },
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


/// Lista las órdenes que aparecen dentro del código de la app del fabricante.
/// Con música sonando se prueba cada una; la que funciona se asigna a ▶, ⏭ o ⏮.
class ProbePage extends StatefulWidget {
  const ProbePage({super.key, required this.pkg, required this.title});
  final String pkg, title;
  @override
  State<ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<ProbePage> {
  List<String>? _list;
  Map<String, String?> _chosen = const {};
  String? _last;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await Native.probe(widget.pkg);
    final ch = await Native.customActions(widget.pkg);
    if (mounted) setState(() {
      _list = l;
      _chosen = ch;
    });
  }

  Future<void> _assign(String cmd, String a) async {
    final already = _chosen[cmd] == a;
    await Native.setCustomAction(widget.pkg, cmd, already ? null : a);
    if (!already) App.i.settings.mediaMode = 7;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final list = _list;
    String label(String cmd) => switch (cmd) { 'toggle' => '▶ Play/pausa', 'next' => '⏭ Siguiente', _ => '⏮ Anterior' };
    return Scaffold(
      backgroundColor: c.ground,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            RoundBtn(icon: Icons.arrow_back_rounded, label: 'Volver', size: 50, onTap: () => Navigator.pop(context)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Órdenes de ${widget.title}', style: ts(24, w: FontWeight.w700, c: c.text)),
                Text('${widget.pkg} · poné música, tocá "Probar" en cada una y asigná la que funcione',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, c: c.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final cmd in const ['toggle', 'next', 'prev'])
              Chip(
                backgroundColor: c.chip,
                side: BorderSide(color: c.line),
                label: Text('${label(cmd)}: ${_chosen[cmd] ?? 'sin elegir'}', style: ts(12, w: FontWeight.w600, c: _chosen[cmd] == null ? c.muted : c.accent)),
              ),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: Glass(
              color: c.panelSolid,
              padding: const EdgeInsets.all(8),
              child: list == null
                  ? Center(child: Text('Buscando dentro de la app…', style: ts(16, c: c.text2)))
                  : list.isEmpty
                      ? Center(child: Text('No se encontraron órdenes en esta app', style: ts(16, c: c.text2)))
                      : ListView.separated(
                          itemCount: list.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: c.line),
                          itemBuilder: (_, i) {
                            final a = list[i];
                            final used = _chosen.entries.where((e) => e.value == a).map((e) => e.key).toList();
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                              child: Row(children: [
                                Expanded(
                                  child: Text(a,
                                      style: ts(14, w: used.isEmpty ? FontWeight.w500 : FontWeight.w700, c: used.isEmpty ? (a == _last ? c.accent : c.text) : c.green)),
                                ),
                                Pill(
                                  text: 'Probar',
                                  height: 40,
                                  onTap: () {
                                    Native.sendAction(a, widget.pkg);
                                    setState(() => _last = a);
                                  },
                                ),
                                const SizedBox(width: 6),
                                for (final cmd in const ['toggle', 'next', 'prev']) ...[
                                  RoundBtn(
                                    icon: switch (cmd) { 'toggle' => Icons.play_arrow_rounded, 'next' => Icons.skip_next_rounded, _ => Icons.skip_previous_rounded },
                                    label: 'Usar para ${label(cmd)}',
                                    size: 40,
                                    bg: used.contains(cmd) ? c.accent : c.chip,
                                    fg: used.contains(cmd) ? c.onAccent : c.text,
                                    onTap: () => _assign(cmd, a),
                                  ),
                                  const SizedBox(width: 4),
                                ],
                              ]),
                            );
                          },
                        ),
            ),
          ),
        ]),
      ),
    );
  }
}
