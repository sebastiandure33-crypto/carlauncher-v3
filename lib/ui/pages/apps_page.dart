import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/settings.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'settings_page.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});
  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  List<AppEntry> _apps = const [];
  String _q = '';
  bool _askedWrite = false, _warnedVol = false;

  @override
  void initState() {
    super.initState();
    _load();
    shellTab.addListener(_onTab);
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (shellTab.value == 3) _load(refresh: true);
  }

  Future<void> _load({bool refresh = false}) async {
    final a = await App.i.apps(refresh: refresh);
    await App.i.loadVolume();
    if (!mounted) return;
    setState(() => _apps = a);
  }

  /// El brillo se guarda para el modo actual (día o noche) y se aplica solo al cambiar de modo.
  Future<void> _setBright(double f) async {
    final save = App.i.setBrightness(f);
    setState(() {});
    final how = await save;
    if (how != 'system' && !_askedWrite && mounted) {
      _askedWrite = true;
      toast(context, 'Por ahora solo cambia esta pantalla. Permití "Modificar ajustes del sistema" para toda la radio');
      if (!await Native.open('write') && mounted) {
        toast(context, 'La radio no tiene ese permiso: el brillo se aplica solo dentro del launcher');
      }
    }
  }

  Future<void> _setVol(double f) async {
    final app = App.i;
    final ok = await app.setVolume((f * app.volume.value.$2).round());
    if (!ok && !_warnedVol && mounted) {
      _warnedVol = true;
      toast(context, 'La radio no dejó cambiar el volumen desde acá: usá la perilla o los botones del volante');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: c.ground,
        gradient: RadialGradient(center: const Alignment(-1, -1), radius: 1.2, colors: [alpha(c.blue, c.dark ? 0.12 : 0.08), alpha(c.blue, 0)]),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 328, child: _control(c)),
        const SizedBox(width: 14),
        Expanded(child: _launcher(c)),
      ]),
    );
  }

  /* ------------------------------------------------ centro de control */

  Widget _control(Pal c) {
    final app = App.i;
    return Column(children: [
      Row(children: [
        Expanded(
          child: ValueListenableBuilder<BtInfo>(
            valueListenable: app.bt,
            builder: (_, b, __) => _tile(
              c,
              icon: b.connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded,
              title: 'Bluetooth',
              sub: b.known ? b.title : (b.available && !b.on ? 'Apagado' : 'Sin teléfono'),
              on: b.known || b.on,
              color: c.blue,
              onTap: () async {
                // primero la app Bluetooth de la radio; si no hay, los ajustes de Android
                if (!await Native.launch(app.settings.slot(Slot.music))) await Native.open('bt');
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ValueListenableBuilder<Wifi>(
            valueListenable: app.wifi,
            builder: (_, w, __) => _tile(
              c,
              icon: w.on ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              title: 'WiFi',
              sub: w.connected ? (w.ssid ?? 'Conectado') : (w.on ? 'Sin conexión' : 'Apagado'),
              on: w.connected,
              color: c.green,
              onTap: () => Native.open('wifi'),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      Expanded(
        child: Row(children: [
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: App.i.night,
              builder: (_, n, __) => _VSlider(
                value: App.i.settings.brightnessFor(n),
                icon: n ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                label: n ? 'Brillo noche' : 'Brillo día',
                gradient: c.accentGradient,
                onChanged: _setBright,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ValueListenableBuilder<(int, int)>(
              valueListenable: App.i.volume,
              builder: (_, v, __) => _VSlider(
              value: v.$2 == 0 ? 0 : v.$1 / v.$2,
              icon: Icons.volume_up_rounded,
              label: 'Volumen',
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.text, alpha(c.text, 0.8)]),
              dark: true,
              onChanged: _setVol,
            ),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      ListenableBuilder(
        listenable: Listenable.merge([app.settings, app.night]),
        builder: (_, __) {
          final sun = app.sunTimes();
          final mode = app.settings.theme;
          return Glass(
            padding: const EdgeInsets.all(12),
            radius: 22,
            child: Column(children: [
              Row(children: [
                Icon(app.night.value ? Icons.nightlight_round : Icons.wb_sunny_rounded, color: c.accentHi, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Modo de pantalla', style: ts(15, w: FontWeight.w700, c: c.text)),
                    Text(
                      sun == null ? 'Auto: de noche de 19 a 7 h' : 'Auto: noche de ${hhmm(sun.$2)} a ${hhmm(sun.$1)}',
                      style: ts(12, c: c.muted),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: c.field, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  for (final m in ThemeModeX.values)
                    Expanded(
                      child: Tap(
                        onTap: () => app.settings.theme = m,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: m == mode ? c.text : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            switch (m) { ThemeModeX.auto => 'Auto', ThemeModeX.night => 'Noche', ThemeModeX.day => 'Día' },
                            style: ts(14, w: FontWeight.w700, c: m == mode ? c.ground : c.text2),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ]),
          );
        },
      ),
      const SizedBox(height: 10),
      ListenableBuilder(
        listenable: app.settings,
        builder: (_, __) {
          final l = app.settings.speedLimit;
          return Glass(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            radius: 22,
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5453A), width: 4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aviso de velocidad', style: ts(14, w: FontWeight.w700, c: c.text)),
                  Text(l == 0 ? 'Desactivado' : 'Se pone rojo al pasar', style: ts(12, c: c.muted)),
                ]),
              ),
              RoundBtn(icon: Icons.remove_rounded, label: 'Bajar límite', size: 42, onTap: () => app.settings.speedLimit = l - 10),
              SizedBox(width: 40, child: Text(l == 0 ? 'No' : '$l', textAlign: TextAlign.center, style: ts(20, w: FontWeight.w700, c: c.text))),
              RoundBtn(icon: Icons.add_rounded, label: 'Subir límite', size: 42, onTap: () => app.settings.speedLimit = l + 10),
            ]),
          );
        },
      ),
    ]);
  }

  Widget _tile(Pal c, {required IconData icon, required String title, required String sub, required bool on, required Color color, required VoidCallback onTap}) {
    return Tap(
      onTap: onTap,
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? alpha(color, 0.2) : c.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: on ? alpha(color, 0.45) : c.line),
          boxShadow: on ? [BoxShadow(color: alpha(color, 0.18), blurRadius: 26)] : null,
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle, color: on ? color : c.chip),
            child: Icon(icon, size: 20, color: on ? (c.dark ? const Color(0xFF04121C) : Colors.white) : c.text),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(title, style: ts(15, w: FontWeight.w700, c: c.text)),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, c: c.text2)),
            ]),
          ),
        ]),
      ),
    );
  }

  /* ------------------------------------------------ apps */

  Widget _launcher(Pal c) {
    final app = App.i;
    final list = _q.isEmpty ? _apps : _apps.where((a) => a.label.toLowerCase().contains(_q.toLowerCase())).toList();
    const slots = [Slot.nav, Slot.music, Slot.radio, Slot.phone];
    return Glass(
      padding: const EdgeInsets.all(18),
      radius: 28,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: TextField(
                style: ts(16, c: c.text),
                cursorColor: c.accent,
                decoration: InputDecoration(
                  hintText: 'Buscar app',
                  hintStyle: ts(16, c: c.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: c.muted),
                  filled: true,
                  fillColor: c.field,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          ),
          const SizedBox(width: 10),
          RoundBtn(
            icon: Icons.settings_rounded,
            label: 'Ajustes',
            size: 50,
            bg: c.field,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          const Label('Accesos de la barra'),
          const Spacer(),
          Text('Mantené apretado para cambiar', style: ts(12, c: c.muted)),
        ]),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: app.settings,
          builder: (_, __) => Row(children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _slot(c, slots[i])),
            ],
          ]),
        ),
        const SizedBox(height: 14),
        const Label('Todas las apps'),
        const SizedBox(height: 8),
        Expanded(
          child: list.isEmpty
              ? Center(child: Text(_apps.isEmpty ? 'Cargando apps…' : 'No hay apps con ese nombre', style: ts(15, c: c.muted)))
              : GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 6,
                    mainAxisExtent: 98,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return Tap(
                      onTap: () => Native.launch(a.pkg),
                      onLong: () => _slotMenu(a),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AppIcon(a.pkg, size: 58),
                        const SizedBox(height: 6),
                        Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600, c: c.text2)),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _slot(Pal c, Slot s) {
    final pkg = App.i.settings.slot(s);
    return Tap(
      onTap: () async {
        if (!await Native.launch(pkg)) await _chooseSlot(s);
      },
      onLong: () => _chooseSlot(s),
      child: Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line)),
        child: Row(children: [
          AppIcon(pkg, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(s.label.toUpperCase(), style: ts(11, w: FontWeight.w700, c: c.muted, ls: 0.8)),
              Text(pkg == null ? 'Elegir' : App.i.labelOf(pkg), maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w700, c: c.text)),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _chooseSlot(Slot s) async {
    final r = await pickApp(context, title: 'App para "${s.label}"', current: App.i.settings.slot(s));
    if (r != null) await App.i.settings.setSlot(s, r);
  }

  /// Toque largo sobre una app: usarla en uno de los accesos.
  Future<void> _slotMenu(AppEntry a) async {
    final s = await showDialog<Slot>(
      context: context,
      builder: (ctx) {
        final c = ctx.pal;
        return CarDialog(
          title: a.label,
          subtitle: 'Usar esta app para…',
          width: 520,
          child: Wrap(spacing: 10, runSpacing: 10, children: [
            for (final s in Slot.values)
              Tap(
                onTap: () => Navigator.pop(ctx, s),
                child: Container(
                  width: 150,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
                  child: Text(s.label, style: ts(15, w: FontWeight.w700, c: c.text)),
                ),
              ),
          ]),
        );
      },
    );
    if (s != null) {
      await App.i.settings.setSlot(s, a.pkg);
      if (mounted) toast(context, '${a.label} quedó en "${s.label}"');
    }
  }
}

/// Barra vertical (brillo / volumen): se arrastra o se toca.
class _VSlider extends StatelessWidget {
  const _VSlider({required this.value, required this.icon, required this.label, required this.gradient, required this.onChanged, this.dark = false});
  final double value;
  final IconData icon;
  final String label;
  final Gradient gradient;
  final ValueChanged<double> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return LayoutBuilder(builder: (_, b) {
      void set(Offset p) => onChanged((1 - p.dy / b.maxHeight).clamp(0.0, 1.0));
      final onFill = dark ? c.ground : c.onAccent;
      return Semantics(
        slider: true,
        label: label,
        value: '${(value * 100).round()}%',
        child: GestureDetector(
          onTapDown: (d) => set(d.localPosition),
          onVerticalDragUpdate: (d) => set(d.localPosition),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Container(
              decoration: BoxDecoration(color: c.panel, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(26)),
              child: Stack(children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: b.maxHeight * value.clamp(0.0, 1.0),
                  child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
                ),
                Positioned(
                  top: 14,
                  left: 0,
                  right: 0,
                  child: Text('${(value * 100).round()}%', textAlign: TextAlign.center, style: ts(18, w: FontWeight.w700, c: value > 0.85 ? onFill : c.text)),
                ),
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Column(children: [
                    Icon(icon, color: value > 0.12 ? onFill : c.text, size: 24),
                    Text(label, style: ts(12, w: FontWeight.w700, c: value > 0.12 ? onFill : c.text)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    });
  }
}
