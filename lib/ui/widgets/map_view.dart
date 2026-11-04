import 'dart:async';
import 'dart:io';
import 'dart:math' show Point;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/models.dart';
import '../../data/navigation.dart';

/// Mapa de calles (OpenStreetMap). Las calles se bajan solo con internet y quedan
/// guardadas en la radio, así después se ven sin conexión.
class CarMap extends StatefulWidget {
  const CarMap({super.key, required this.padding, this.onLongPress});

  /// Espacio que tapan los paneles (para centrar el auto en la parte libre).
  final EdgeInsets padding;

  /// Toque largo sobre el mapa (para "ir acá").
  final ValueChanged<LatLng>? onLongPress;

  @override
  State<CarMap> createState() => _CarMapState();
}

class _CarMapState extends State<CarMap> {
  final _ctrl = MapController();
  bool _ready = false;
  bool _follow = true;
  double _zoom = 16;
  late final _tiles = _CachedTiles('${App.i.filesDir ?? Directory.systemTemp.path}/tiles');

  NavState? _lastRoute;
  Timer? _resume;

  @override
  void initState() {
    super.initState();
    App.i.gps.addListener(_onGps);
    App.i.navi.state.addListener(_onRoute);
  }

  @override
  void dispose() {
    App.i.gps.removeListener(_onGps);
    App.i.navi.state.removeListener(_onRoute);
    _resume?.cancel();
    super.dispose();
  }

  /// Ruta nueva: muestra el recorrido completo unos segundos y vuelve a seguir al auto.
  void _onRoute() {
    final r = App.i.navi.state.value;
    final isNew = r != null && (_lastRoute == null || _lastRoute!.line != r.line);
    _lastRoute = r;
    if (!isNew || !_ready || r.line.length < 2) return;
    try {
      _ctrl.fitCamera(CameraFit.coordinates(
        coordinates: [...r.line, _here],
        padding: widget.padding + const EdgeInsets.all(40),
      ));
      if (mounted) setState(() => _follow = false);
      _resume?.cancel();
      _resume = Timer(const Duration(seconds: 6), () {
        if (!mounted) return;
        setState(() => _follow = true);
        _zoom = 16;
        _center();
      });
    } catch (_) {}
  }

  LatLng get _here {
    final g = App.i.gps.value;
    return g == null ? LatLng(App.i.lat, App.i.lon) : LatLng(g.lat, g.lon);
  }

  void _onGps() {
    if (!_ready || !_follow) return;
    _center();
  }

  void _center() {
    try {
      _ctrl.move(_offsetCenter(_here), _zoom);
    } catch (_) {}
  }

  /// Corre el centro para que el auto quede en el medio del espacio libre entre paneles.
  LatLng _offsetCenter(LatLng p) {
    try {
      final cam = _ctrl.camera;
      final dx = (widget.padding.left - widget.padding.right) / 2;
      final dy = (widget.padding.top - widget.padding.bottom) / 2;
      final pt = cam.project(p, _zoom);
      return cam.unproject(Point<double>(pt.x - dx, pt.y - dy), _zoom);
    } catch (_) {
      return p;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Stack(fit: StackFit.expand, children: [
      FlutterMap(
          mapController: _ctrl,
          options: MapOptions(
            initialCenter: _here,
            initialZoom: _zoom,
            minZoom: 4,
            maxZoom: 19,
            backgroundColor: c.ground,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              _ready = true;
              _center();
            },
            onPositionChanged: (cam, gesture) {
              _zoom = cam.zoom;
              if (gesture) _resume?.cancel();
              if (gesture && _follow) setState(() => _follow = false);
            },
            onLongPress: widget.onLongPress == null ? null : (_, p) => widget.onLongPress!(p),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.rgservice.carlauncher4',
              tileProvider: _tiles,
              maxNativeZoom: 19,
              tileBuilder: c.dark ? darkModeTileBuilder : null,
              evictErrorTileStrategy: EvictErrorTileStrategy.notVisibleRespectMargin,
            ),
            ValueListenableBuilder<NavState?>(
              valueListenable: App.i.navi.state,
              builder: (_, r, __) => r == null
                  ? const SizedBox.shrink()
                  : PolylineLayer(polylines: [
                      Polyline(points: r.line, strokeWidth: 12, color: alpha(c.accent, 0.30)),
                      Polyline(
                        points: r.line,
                        strokeWidth: 6,
                        color: c.accent,
                        borderStrokeWidth: 2,
                        borderColor: alpha(c.dark ? Colors.black : Colors.white, 0.6),
                      ),
                    ]),
            ),
            ValueListenableBuilder<NavState?>(
              valueListenable: App.i.navi.state,
              builder: (_, r, __) => r == null
                  ? const SizedBox.shrink()
                  : MarkerLayer(markers: [
                      Marker(
                        point: r.dest,
                        width: 44,
                        height: 44,
                        alignment: Alignment.topCenter,
                        child: Icon(Icons.location_on_rounded, size: 44, color: c.red),
                      ),
                    ]),
            ),
            ValueListenableBuilder<Gps?>(
              valueListenable: App.i.gps,
              builder: (_, g, __) => MarkerLayer(markers: [
                Marker(
                  point: _here,
                  width: 70,
                  height: 70,
                  child: _CarMarker(bearing: g?.bearing ?? 0, ok: g != null, color: c.accent),
                ),
              ]),
            ),
          ],
        ),
      // degradé en los bordes para que los paneles se lean mejor
      IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, 0.1),
              radius: 1.1,
              colors: [alpha(c.ground, 0), alpha(c.ground, 0.85)],
              stops: const [0.55, 1],
            ),
          ),
        ),
      ),
      if (!_follow)
        Positioned(
          right: widget.padding.right + 12,
          bottom: widget.padding.bottom + 12,
          child: GestureDetector(
            onTap: () {
              setState(() => _follow = true);
              _zoom = 16;
              _center();
            },
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: c.panelSolid, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.line)),
              child: Row(children: [
                Icon(Icons.my_location_rounded, color: c.accent, size: 20),
                const SizedBox(width: 8),
                Text('Centrar', style: ts(15, w: FontWeight.w700, c: c.text)),
              ]),
            ),
          ),
        ),
    ]);
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker({required this.bearing, required this.ok, required this.color});
  final double bearing;
  final bool ok;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: alpha(color, 0.10))),
      Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, color: alpha(color, 0.18))),
      Transform.rotate(
        angle: bearing * 3.14159265 / 180,
        child: Icon(Icons.navigation_rounded, size: 30, color: ok ? color : alpha(color, 0.5)),
      ),
    ]);
  }
}

/// Proveedor de calles que guarda cada imagen en la radio.
class _CachedTiles extends TileProvider {
  _CachedTiles(this.dir) : super(headers: {'User-Agent': 'CarLauncher4 (com.rgservice.carlauncher4)'}) {
    try {
      Directory(dir).createSync(recursive: true);
    } catch (_) {}
  }
  final String dir;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) => _TileImage(
        getTileUrl(coordinates, options),
        '$dir/${coordinates.z}_${coordinates.x}_${coordinates.y}.png',
        headers,
      );
}

@immutable
class _TileImage extends ImageProvider<_TileImage> {
  const _TileImage(this.url, this.path, this.headers);
  final String url, path;
  final Map<String, String> headers;

  @override
  Future<_TileImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(_TileImage key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(codec: _load(decode), scale: 1);

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    final f = File(path);
    Uint8List bytes;
    if (await f.exists()) {
      bytes = await f.readAsBytes();
    } else {
      final r = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) throw StateError('tile ${r.statusCode}');
      bytes = r.bodyBytes;
      f.writeAsBytes(bytes).catchError((_) => f);
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) => other is _TileImage && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
