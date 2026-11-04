import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/navigation.dart';
import '../../data/settings.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/map_view.dart';
import '../widgets/nav_widgets.dart';

/// Pide a la pantalla de mapa que abra el buscador (desde el botón de buscar del inicio).
final mapSearchRequest = ValueNotifier<int>(0);

/// Mapa a pantalla completa con buscador y ruta, sin salir del launcher.
class MapPage extends StatefulWidget {
  const MapPage({super.key});
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  List<PlaceHit> _hits = const [];
  bool _searching = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    mapSearchRequest.addListener(_openSearch);
  }

  @override
  void dispose() {
    mapSearchRequest.removeListener(_openSearch);
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });

  void _changed(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() {
        _hits = const [];
        _error = null;
      });
      return;
    }
    // Nominatim pide como mucho una búsqueda por segundo
    _debounce = Timer(const Duration(milliseconds: 900), () => _search(v.trim()));
  }

  Future<void> _search(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final h = await App.i.navi.search(q);
      if (!mounted) return;
      setState(() {
        _hits = h;
        _error = h.isEmpty ? 'No se encontró "$q"' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Sin conexión: no se puede buscar');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pick(PlaceHit h) async {
    _focus.unfocus();
    setState(() => _hits = const []);
    _q.text = h.name;
    await routeTo(context, h.at, h.name);
  }

  Future<void> _longPress(LatLng p) async {
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => CarDialog(
        title: 'Este punto',
        subtitle: '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
        width: 520,
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          Pill(text: 'Ir acá', icon: Icons.navigation_rounded, primary: true, onTap: () => Navigator.pop(ctx, 'go')),
          Pill(text: 'Guardar como Casa', icon: Icons.home_rounded, onTap: () => Navigator.pop(ctx, 'home')),
          Pill(text: 'Guardar como Trabajo', icon: Icons.work_rounded, onTap: () => Navigator.pop(ctx, 'work')),
        ]),
      ),
    );
    if (!mounted || r == null) return;
    if (r == 'go') await routeTo(context, p, 'Punto elegido');
    if (r == 'home') await savePlace(context, 'home', 'Casa', at: p);
    if (r == 'work') await savePlace(context, 'work', 'Trabajo', at: p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final app = App.i;
    return Stack(fit: StackFit.expand, children: [
      CarMap(padding: const EdgeInsets.fromLTRB(16, 90, 16, 120), onLongPress: _longPress),
      // buscador
      Positioned(
        top: 14,
        left: 16,
        width: 470,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Glass(
            padding: const EdgeInsets.all(6),
            radius: 20,
            color: c.panelSolid,
            child: Row(children: [
              const SizedBox(width: 8),
              Icon(Icons.search_rounded, color: c.muted),
              Expanded(
                child: TextField(
                  controller: _q,
                  focusNode: _focus,
                  style: ts(17, w: FontWeight.w600, c: c.text),
                  cursorColor: c.accent,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '¿A dónde vamos?',
                    hintStyle: ts(17, c: c.muted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  ),
                  onChanged: _changed,
                  onSubmitted: (v) {
                    if (v.trim().isNotEmpty) _search(v.trim());
                  },
                ),
              ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent)),
                )
              else if (_q.text.isNotEmpty)
                RoundBtn(
                  icon: Icons.close_rounded,
                  label: 'Borrar',
                  size: 44,
                  bg: Colors.transparent,
                  onTap: () {
                    _q.clear();
                    setState(() {
                      _hits = const [];
                      _error = null;
                    });
                  },
                ),
            ]),
          ),
          if (_hits.isNotEmpty || _error != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 330),
              decoration: BoxDecoration(
                color: c.panelSolid,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.line),
                boxShadow: [BoxShadow(color: c.shadow, blurRadius: 30)],
              ),
              child: _error != null
                  ? Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: ts(15, c: c.text2)))
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: c.line, indent: 56),
                      itemBuilder: (_, i) {
                        final h = _hits[i];
                        final d = const Distance().distance(app.navi.here, h.at);
                        return Tap(
                          onTap: () => _pick(h),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              Icon(Icons.place_rounded, color: c.accent),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(h.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, w: FontWeight.w700, c: c.text)),
                                  if (h.detail.isNotEmpty)
                                    Text(h.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, c: c.muted)),
                                ]),
                              ),
                              const SizedBox(width: 8),
                              Text(fmtDist(d.toDouble()), style: ts(13, w: FontWeight.w700, c: c.text2)),
                            ]),
                          ),
                        );
                      },
                    ),
            ),
        ]),
      ),
      // accesos rápidos
      Positioned(
        top: 14,
        right: 16,
        child: Row(children: [
          _quick(c, Icons.home_rounded, 'Casa', () => goPlace(context, 'home', 'Casa'), () => savePlace(context, 'home', 'Casa')),
          const SizedBox(width: 8),
          _quick(c, Icons.work_rounded, 'Trabajo', () => goPlace(context, 'work', 'Trabajo'), () => savePlace(context, 'work', 'Trabajo')),
        ]),
      ),
      // ruta activa
      Positioned(
        left: 16,
        right: 16,
        bottom: 14,
        child: ValueListenableBuilder<NavState?>(
          valueListenable: app.navi.state,
          builder: (_, s, __) => s == null ? _hint(c) : _routeCard(c, s),
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: app.navi.busy,
        builder: (_, b, __) => b
            ? Center(
                child: Glass(
                  color: c.panelSolid,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: c.accent)),
                    const SizedBox(width: 14),
                    Text('Calculando ruta…', style: ts(17, w: FontWeight.w700, c: c.text)),
                  ]),
                ),
              )
            : const SizedBox.shrink(),
      ),
    ]);
  }

  Widget _quick(Pal c, IconData icon, String label, VoidCallback onTap, VoidCallback onLong) => Tap(
        onTap: onTap,
        onLong: onLong,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.panelSolid,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.line),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 20)],
          ),
          child: Row(children: [
            Icon(icon, color: c.accentHi, size: 22),
            const SizedBox(width: 8),
            Text(label, style: ts(16, w: FontWeight.w700, c: c.text)),
          ]),
        ),
      );

  Widget _hint(Pal c) => Align(
        alignment: Alignment.bottomLeft,
        child: Glass(
          color: c.panelSolid,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          radius: 18,
          child: Text('Buscá un lugar o mantené apretado un punto del mapa', style: ts(14, w: FontWeight.w600, c: c.text2)),
        ),
      );

  Widget _routeCard(Pal c, NavState s) {
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const NavBanner(showStop: true),
      const SizedBox(height: 8),
      Glass(
        color: c.panelSolid,
        padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
        radius: 20,
        child: Row(children: [
          Icon(Icons.place_rounded, color: c.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.destName, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(16, w: FontWeight.w700, c: c.text)),
              Text('Faltan ${fmtDist(s.leftM)} · ${fmtTime(s.leftS)} · llegada ${hhmm(DateTime.now().add(Duration(seconds: s.leftS.round())))}',
                  style: ts(13, c: c.muted)),
            ]),
          ),
          Pill(
            text: 'Abrir en ${App.i.labelOf(App.i.settings.slot(Slot.nav))}',
            icon: Icons.open_in_new_rounded,
            height: 46,
            onTap: () => Native.navigate(s.dest.latitude, s.dest.longitude, App.i.settings.slot(Slot.nav)),
          ),
          const SizedBox(width: 8),
          Pill(text: 'Terminar', danger: true, height: 46, onTap: App.i.navi.stop),
        ]),
      ),
    ]);
  }
}

/// Va a la pantalla de mapa con el buscador abierto.
void openMapSearch() {
  shellTab.value = 4;
  mapSearchRequest.value++;
}
