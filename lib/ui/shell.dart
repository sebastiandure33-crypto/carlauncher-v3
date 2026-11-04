import 'package:flutter/material.dart';

import '../core/native.dart';
import '../core/theme.dart';
import '../data/app_state.dart';
import '../data/models.dart';
import '../data/settings.dart';
import 'pages/apps_page.dart';
import 'pages/audio_page.dart';
import 'pages/home_page.dart';
import 'pages/maint_page.dart';
import 'pages/map_page.dart';
import 'widgets/common.dart';
import 'widgets/dialogs.dart';

/// Pestaña visible (0 inicio, 1 audio, 2 auto, 3 apps, 4 mapa).
final shellTab = ValueNotifier<int>(0);

/// Fuente elegida en la pantalla de audio.
enum AudioSource { bt, radio, apps, usb }

final audioSource = ValueNotifier<AudioSource>(AudioSource.bt);

void goAudio(AudioSource s) {
  audioSource.value = s;
  shellTab.value = 1;
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await Native.hasLocation()) {
        await Native.requestLocation();
        App.i.refreshPerms();
      }
      App.i.apps();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) App.i.refreshPerms();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        if (Navigator.of(context).canPop()) return;
        shellTab.value = 0;
      },
      child: Scaffold(
        backgroundColor: c.ground,
        resizeToAvoidBottomInset: false,
        body: Row(children: [
          const _Rail(),
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: shellTab,
              // Solo anima la pantalla visible (la radio tiene 4 núcleos A53 y poca RAM)
              builder: (_, tab, __) => IndexedStack(
                index: tab,
                sizing: StackFit.expand,
                children: [
                  for (final (i, page) in const [HomePage(), AudioPage(), MaintPage(), AppsPage(), MapPage()].indexed)
                    TickerMode(enabled: i == tab, child: page),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return Container(
      width: 84,
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
      decoration: BoxDecoration(
        color: c.rail,
        border: Border(right: BorderSide(color: c.line)),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30, offset: const Offset(8, 0))],
      ),
      child: Column(children: [
        ValueListenableBuilder<DateTime>(
          valueListenable: app.now,
          builder: (_, d, __) => Column(children: [
            Text(hhmm(d), style: ts(24, w: FontWeight.w700, c: c.text, ls: -0.5)),
            Text(fechaCorta(d).toUpperCase(), style: ts(10, w: FontWeight.w600, c: c.muted, ls: 1)),
          ]),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: shellTab,
            builder: (_, tab, __) => ListenableBuilder(
              listenable: app.maint,
              builder: (_, __) => Column(children: [
                _RailItem(icon: Icons.home_rounded, label: 'Inicio', active: tab == 0, onTap: () => shellTab.value = 0),
                _RailItem(
                  icon: Icons.map_rounded,
                  label: 'Mapa',
                  active: tab == 4,
                  onTap: () => shellTab.value = 4,
                  onLong: () => _choose(context, Slot.nav),
                ),
                _RailItem(icon: Icons.music_note_rounded, label: 'Audio', active: tab == 1, onTap: () => shellTab.value = 1),
                _RailItem(
                  icon: Icons.phone_rounded,
                  label: 'Teléfono',
                  onTap: () async {
                    if (!await app.openSlot(Slot.phone) && context.mounted) toast(context, 'Elegí la app de teléfono (mantené apretado)');
                  },
                  onLong: () => _choose(context, Slot.phone),
                ),
                _RailItem(
                  icon: Icons.directions_car_filled_rounded,
                  label: 'Auto',
                  active: tab == 2,
                  badge: app.maint.warnings,
                  onTap: () => shellTab.value = 2,
                ),
                _RailItem(icon: Icons.apps_rounded, label: 'Apps', active: tab == 3, onTap: () => shellTab.value = 3),
              ]),
            ),
          ),
        ),
        const _ThemeButton(),
        const SizedBox(height: 6),
        ValueListenableBuilder<BtInfo>(
          valueListenable: app.bt,
          builder: (_, b, __) => Tap(
            onTap: () => goAudio(AudioSource.bt),
            semantics: b.connected ? 'Bluetooth conectado' : 'Bluetooth',
            child: Container(
              width: 64,
              height: 48,
              decoration: BoxDecoration(
                color: alpha(c.blue, 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: alpha(c.blue, 0.22)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(b.known ? Icons.bluetooth_connected_rounded : Icons.bluetooth_rounded, color: c.blue, size: 20),
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: b.known ? c.green : c.muted,
                    boxShadow: b.known ? [BoxShadow(color: c.green, blurRadius: 8)] : null,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  static Future<void> _choose(BuildContext context, Slot s) async {
    final r = await pickApp(context, title: 'App para "${s.label}"', current: App.i.settings.slot(s));
    if (r != null) await App.i.settings.setSlot(s, r);
  }
}

/// Botón Día / Noche / Auto (como el de la barra del Car Launcher 3).
class _ThemeButton extends StatelessWidget {
  const _ThemeButton();

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.night]),
      builder: (_, __) {
        final m = app.settings.theme;
        final label = switch (m) { ThemeModeX.auto => 'Auto', ThemeModeX.night => 'Noche', ThemeModeX.day => 'Día' };
        return Tap(
          onTap: () {
            app.settings.theme = ThemeModeX.values[(m.index + 1) % ThemeModeX.values.length];
          },
          semantics: 'Modo $label',
          child: Container(
            width: 64,
            height: 48,
            decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(app.night.value ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 18, color: c.accentHi),
              const SizedBox(height: 1),
              Text(label, style: ts(11, w: FontWeight.w700, c: c.text2)),
            ]),
          ),
        );
      },
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({required this.icon, required this.label, this.active = false, this.onTap, this.onLong, this.badge = 0});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap, onLong;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Tap(
        onTap: onTap,
        onLong: onLong,
        semantics: badge > 0 ? '$label, $badge alertas' : label,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 64,
          height: 62,
          decoration: BoxDecoration(
            gradient: active ? c.accentGradient : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active ? [BoxShadow(color: alpha(c.accent, 0.35), blurRadius: 24, offset: const Offset(0, 8))] : null,
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 25, color: active ? c.onAccent : c.text2),
                const SizedBox(height: 3),
                Text(label, style: ts(11, w: FontWeight.w700, c: active ? c.onAccent : c.text2)),
              ]),
            ),
            if (badge > 0)
              Positioned(
                top: 5,
                right: 10,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 17),
                  height: 17,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.red,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: c.rail, width: 2),
                    boxShadow: [BoxShadow(color: alpha(c.red, 0.7), blurRadius: 10)],
                  ),
                  child: Text('$badge', style: ts(10, w: FontWeight.w700, c: const Color(0xFF1A0805))),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
