import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/app_state.dart';
import '../../data/maintenance.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import '../widgets/holo_car.dart';

class MaintPage extends StatefulWidget {
  const MaintPage({super.key});
  @override
  State<MaintPage> createState() => _MaintPageState();
}

class _MaintPageState extends State<MaintPage> {
  final _stackKey = GlobalKey();
  final _keys = <String, GlobalKey>{};
  String _sel = 'oil';
  bool _intro = false;
  bool _introShown = false;

  /// Línea desde la tarjeta elegida hasta la pieza (en coordenadas del área central).
  Rect? _link;

  Maint get m => App.i.maint;

  GlobalKey _key(String id) => _keys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    shellTab.addListener(_onTab);
    final first = m.kmRows.where((r) => r.warn).map((r) => r.id).followedBy(m.dateRows.where((r) => r.warn).map((r) => r.id));
    if (first.isNotEmpty) _sel = first.first;
  }

  @override
  void dispose() {
    shellTab.removeListener(_onTab);
    super.dispose();
  }

  void _onTab() {
    if (shellTab.value == 2 && !_introShown && App.i.settings.intro) {
      _introShown = true;
      setState(() => _intro = true);
    }
    if (shellTab.value == 2) WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _select(String id, VoidCallback edit) {
    if (_sel == id) {
      edit();
    } else {
      setState(() => _sel = id);
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  /// Mide dónde quedó la tarjeta elegida para dibujar la línea hacia el auto.
  void _measure() {
    if (!mounted) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final card = _keys[_sel]?.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || card == null || !stack.hasSize || !card.hasSize) return;
    final topLeft = stack.globalToLocal(card.localToGlobal(Offset.zero));
    final r = topLeft & card.size;
    final s = stack.size;
    final centerArea = Rect.fromLTRB(_side + _gap, 0, s.width - _side - _gap, s.height);
    final anchor = centerArea.topLeft + HoloCar.toLocal(centerArea.size, HoloCar.center(Maint.partOf(_sel)));
    final Offset from;
    if (r.center.dy > s.height - 1) {
      from = r.topCenter;
    } else if (r.center.dx < s.width / 2) {
      from = r.centerRight;
    } else {
      from = r.centerLeft;
    }
    final link = Rect.fromLTRB(from.dx, from.dy, anchor.dx, anchor.dy);
    if (link != _link) setState(() => _link = link);
  }

  static const _side = 252.0, _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Container(
      decoration: BoxDecoration(
        color: c.ground,
        gradient: RadialGradient(
          center: const Alignment(0, 0.1),
          radius: 0.8,
          colors: [alpha(c.blue, c.dark ? 0.14 : 0.10), alpha(c.blue, 0)],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: ListenableBuilder(
        listenable: m,
        builder: (_, __) {
          final km = m.kmRows;
          final dates = m.dateRows;
          if (![...km.map((e) => e.id), ...dates.map((e) => e.id)].contains(_sel)) _sel = km.first.id;
          final half = (km.length / 2).ceil();
          final warnParts = <String>{
            for (final r in km) if (r.warn) Maint.partOf(r.id),
            if (dates.any((r) => r.warn)) 'docs',
          };
          WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
          return Column(children: [
            _header(c, km, dates),
            const SizedBox(height: 12),
            Expanded(
              child: Stack(key: _stackKey, clipBehavior: Clip.none, children: [
                Positioned(
                  left: _side + _gap,
                  right: _side + _gap,
                  top: 0,
                  bottom: 0,
                  child: HoloCar(
                    part: Maint.partOf(_sel),
                    warn: warnParts,
                    intro: _intro,
                    onIntroDone: () {
                      if (mounted) setState(() => _intro = false);
                    },
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: TweenAnimationBuilder<Rect?>(
                      tween: RectTween(end: _link),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOutCubic,
                      builder: (_, r, __) => CustomPaint(
                        painter: _LinkPainter(r, warnParts.contains(Maint.partOf(_sel)) ? c.red : c.accent),
                      ),
                    ),
                  ),
                ),
                Positioned(left: 0, top: 0, bottom: 0, width: _side, child: _column(c, km.take(half).toList())),
                Positioned(right: 0, top: 0, bottom: 0, width: _side, child: _column(c, km.skip(half).toList())),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 66, child: _dates(c, dates)),
          ]);
        },
      ),
    );
  }

  /* ------------------------------------------------ encabezado */

  Widget _header(Pal c, List<KmRow> km, List<DateRow> dates) {
    final w = m.warnings;
    return SizedBox(
      height: 58,
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Estado del vehículo', style: ts(26, w: FontWeight.w700, c: c.text, ls: -0.5)),
            Text(
              m.odo == null
                  ? 'Primero cargá los km del tablero'
                  : w == 0
                      ? 'Todo en orden · aviso a ${Maint.warnKm} km o ${Maint.warnDays} días'
                      : '$w ${w == 1 ? 'ítem requiere' : 'ítems requieren'} atención · tocá dos veces para editar',
              style: ts(14, w: FontWeight.w600, c: w > 0 || m.odo == null ? c.redText : c.text2),
            ),
          ]),
        ),
        Container(
          height: 58,
          padding: const EdgeInsets.fromLTRB(18, 0, 8, 0),
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              const Label('Odómetro'),
              Text(m.odo == null ? '— km' : '${miles(m.odo!)} km', style: ts(22, w: FontWeight.w700, c: c.text)),
            ]),
            const SizedBox(width: 14),
            Pill(text: m.odo == null ? 'Cargar km' : 'Actualizar', primary: true, height: 44, onTap: _editOdo),
          ]),
        ),
      ]),
    );
  }

  Future<void> _editOdo() async {
    final v = await askNumber(context,
        title: 'Km del tablero', subtitle: 'Mirá el cuentakilómetros del auto. Después el GPS los va sumando solo.', initial: m.odo);
    if (v != null) await m.setOdo(v);
  }

  /* ------------------------------------------------ tarjetas por km */

  Widget _column(Pal c, List<KmRow> rows) {
    Widget card(KmRow r) => _KmCard(
          key: _key(r.id),
          row: r,
          selected: _sel == r.id,
          onTap: () => _select(r.id, () => _editKm(r.id)),
          onLong: () => _editKm(r.id),
        );
    if (rows.length <= 3) {
      return Column(children: [
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 10), Expanded(child: card(rows[i]))],
        for (var i = rows.length; i < 3; i++) ...[const SizedBox(height: 10), const Spacer()],
      ]);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        return false;
      },
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => SizedBox(height: 120, child: card(rows[i])),
      ),
    );
  }

  /* ------------------------------------------------ fechas */

  Widget _dates(Pal c, List<DateRow> dates) {
    return Row(children: [
      Expanded(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: dates.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final d = dates[i];
            final sel = _sel == d.id;
            final dot = d.days == null ? c.muted : (d.warn ? c.red : c.green);
            return Tap(
              key: _key(d.id),
              onTap: () => _select(d.id, () => _editDate(d.id)),
              onLong: () => _editDate(d.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 196,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: d.warn ? alpha(c.red, 0.14) : c.chip,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: sel ? (d.warn ? c.red : c.accent) : (d.warn ? alpha(c.red, 0.45) : c.line), width: sel ? 2 : 1),
                ),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: dot, boxShadow: [BoxShadow(color: dot, blurRadius: 8)])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(13, w: FontWeight.w600, c: c.text2)),
                      Text(d.days == null ? 'Sin fecha' : Maint.leftText(d.days!),
                          style: ts(16, w: FontWeight.w700, c: d.warn ? c.redText : c.text)),
                    ]),
                  ),
                  if (sel) Icon(Icons.edit_rounded, size: 18, color: c.accent),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(width: 10),
      Tap(
        onTap: _addItem,
        semantics: 'Agregar ítem propio',
        child: Container(
          width: 66,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: alpha(c.text, 0.25)),
          ),
          child: Icon(Icons.add_rounded, color: c.text2, size: 28),
        ),
      ),
    ]);
  }

  /* ------------------------------------------------ editores */

  Future<void> _editKm(String id) async {
    setState(() => _sel = id);
    await showDialog<void>(context: context, builder: (_) => _KmEditor(id: id));
  }

  Future<void> _editDate(String id) async {
    setState(() => _sel = id);
    await showDialog<void>(context: context, builder: (_) => _DateEditor(id: id));
  }

  Future<void> _addItem() async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => CarDialog(
        title: 'Agregar ítem propio',
        width: 520,
        child: Row(children: [
          Expanded(
            child: _choice(ctx, Icons.speed_rounded, 'Por kilómetros', 'Ej.: filtro de combustible, bujías', 'km'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _choice(ctx, Icons.event_rounded, 'Por fecha', 'Ej.: matafuego, cuota del auto', 'date'),
          ),
        ]),
      ),
    );
    if (type == null || !mounted) return;
    final name = await askText(context, title: type == 'km' ? 'Nombre del ítem' : 'Nombre del vencimiento', hint: 'Escribí el nombre');
    if (name == null || !mounted) return;
    if (type == 'km') {
      final interval = await askNumber(context, title: 'Cada cuántos km', subtitle: name, initial: 10000);
      if (interval == null || interval <= 0) return;
      final id = await m.addKm(name, interval);
      setState(() => _sel = id);
    } else {
      final id = await m.addDate(name);
      if (!mounted) return;
      setState(() => _sel = id);
      _editDate(id);
    }
  }

  Widget _choice(BuildContext ctx, IconData icon, String title, String sub, String value) {
    final c = ctx.pal;
    return Tap(
      onTap: () => Navigator.pop(ctx, value),
      child: Container(
        height: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(icon, color: c.accent, size: 30),
          const Spacer(),
          Text(title, style: ts(17, w: FontWeight.w700, c: c.text)),
          Text(sub, style: ts(13, c: c.muted)),
        ]),
      ),
    );
  }
}

/* ------------------------------------------------------------ tarjeta */

class _KmCard extends StatelessWidget {
  const _KmCard({super.key, required this.row, required this.selected, required this.onTap, required this.onLong});
  final KmRow row;
  final bool selected;
  final VoidCallback onTap, onLong;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final r = row;
    final ring = r.warn ? c.red : (r.fraction < 0.3 ? c.accent : c.blue);
    return Tap(
      onTap: onTap,
      onLong: onLong,
      semantics: r.name,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: r.warn ? alpha(c.red, c.dark ? 0.16 : 0.10) : c.panel,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? (r.warn ? c.red : c.accent) : (r.warn ? alpha(c.red, 0.45) : c.line),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(color: c.shadow, blurRadius: 24, offset: const Offset(0, 12)),
            if (selected) BoxShadow(color: alpha(r.warn ? c.red : c.accent, 0.25), blurRadius: 24),
          ],
        ),
        child: Row(children: [
          Ring(value: r.remaining == null ? 0 : r.fraction, color: ring, size: 58, stroke: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(14, w: FontWeight.w700, c: c.text2)),
              Text(r.remaining == null ? 'Sin cargar' : '${miles(r.remaining!)} km',
                  style: ts(22, w: FontWeight.w700, c: r.warn ? c.redText : c.text, ls: -0.4)),
              Text('cada ${miles(r.interval)} km', style: ts(12, c: c.muted)),
            ]),
          ),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Icon(Icons.edit_rounded, size: 18, color: c.accent),
          ),
        ]),
      ),
    );
  }
}

class _LinkPainter extends CustomPainter {
  _LinkPainter(this.r, this.color);
  final Rect? r;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final l = r;
    if (l == null) return;
    final a = Offset(l.left, l.top), b = Offset(l.right, l.bottom);
    final dir = (b.dx - a.dx).sign;
    final elbow = (b.dy - a.dy).abs() < 1 || a.dy >= size.height - 70
        ? Offset(a.dx, a.dy - 24)
        : Offset(a.dx + dir * 34, a.dy);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(b.dx, b.dy);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = alpha(color, 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = alpha(color, 0.9));
    canvas.drawCircle(a, 4, Paint()..color = color);
    canvas.drawCircle(b, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LinkPainter o) => o.r != r || o.color != color;
}

/* ------------------------------------------------------------ editores */

class _KmEditor extends StatelessWidget {
  const _KmEditor({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final m = App.i.maint;
    return ListenableBuilder(
      listenable: m,
      builder: (ctx, __) {
        final c = ctx.pal;
        final r = m.kmRows.firstWhere((e) => e.id == id, orElse: () => m.kmRows.first);
        final presets = {...r.item.presets, r.interval}.toList()..sort();
        return CarDialog(
          title: r.name,
          subtitle: 'Cambio cada ${miles(r.interval)} km',
          width: 680,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Ring(value: r.remaining == null ? 0 : r.fraction, color: r.warn ? c.red : c.accent, size: 86, stroke: 8),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.remaining == null ? 'Sin cargar' : 'Faltan ${miles(r.remaining!)} km',
                        style: ts(28, w: FontWeight.w700, c: r.warn ? c.redText : c.text)),
                    Text(
                      [
                        if (r.next != null) 'Próximo a los ${miles(r.next!)} km',
                        if (r.last != null) 'último a los ${miles(r.last!)} km',
                        if (m.odo == null) 'cargá los km del tablero',
                      ].join(' · '),
                      style: ts(15, c: c.text2),
                    ),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(
                  child: Pill(
                    text: 'Lo cambié hoy',
                    icon: Icons.check_circle_rounded,
                    primary: true,
                    height: 56,
                    expand: true,
                    onTap: m.odo == null ? null : () => m.changedNow(id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Pill(
                    text: 'Próximo cambio a…',
                    icon: Icons.flag_rounded,
                    height: 56,
                    expand: true,
                    onTap: () async {
                      final v = await askNumber(ctx,
                          title: 'Próximo cambio', subtitle: 'Lo que dice el sticker del taller (km del tablero)', initial: r.next);
                      if (v != null) await m.setNext(id, v);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              const Label('Intervalo'),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in presets)
                  Tap(
                    onTap: () => m.setInterval(id, p),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p == r.interval ? alpha(c.accent, 0.2) : c.chip,
                        border: Border.all(color: p == r.interval ? c.accent : Colors.transparent),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('${miles(p)} km', style: ts(15, w: FontWeight.w700, c: c.text)),
                    ),
                  ),
                Pill(
                  text: 'Otro…',
                  height: 46,
                  onTap: () async {
                    final v = await askNumber(ctx, title: 'Cada cuántos km', subtitle: r.name, initial: r.interval);
                    if (v != null && v > 0) await m.setInterval(id, v);
                  },
                ),
              ]),
              if (r.item.custom) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Pill(
                    text: 'Eliminar ítem',
                    icon: Icons.delete_outline_rounded,
                    danger: true,
                    onTap: () async {
                      if (await confirm(ctx, 'Eliminar', '¿Eliminar "${r.name}"?', ok: 'Eliminar', danger: true)) {
                        await m.remove(id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}

class _DateEditor extends StatelessWidget {
  const _DateEditor({required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final m = App.i.maint;
    return ListenableBuilder(
      listenable: m,
      builder: (ctx, __) {
        final c = ctx.pal;
        final r = m.dateRows.firstWhere((e) => e.id == id, orElse: () => m.dateRows.first);
        return CarDialog(
          title: r.name,
          subtitle: 'Aviso ${Maint.warnDays} días antes del vencimiento',
          width: 560,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(color: r.warn ? alpha(c.red, 0.16) : c.chip, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.event_rounded, size: 34, color: r.warn ? c.red : c.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.date == null ? 'Sin fecha' : fechaLarga(r.date!), style: ts(26, w: FontWeight.w700, c: c.text)),
                  if (r.days != null) Text(Maint.leftText(r.days!), style: ts(16, w: FontWeight.w600, c: r.warn ? c.redText : c.text2)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(
                child: Pill(
                  text: 'Elegir fecha',
                  icon: Icons.edit_calendar_rounded,
                  primary: true,
                  height: 56,
                  expand: true,
                  onTap: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: r.date ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 20),
                      helpText: 'Fecha de vencimiento',
                      cancelText: 'Cancelar',
                      confirmText: 'Guardar',
                    );
                    if (d != null) await m.setDate(id, d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Pill(
                  text: 'Quitar fecha',
                  height: 56,
                  expand: true,
                  onTap: r.date == null ? null : () => m.setDate(id, null),
                ),
              ),
            ]),
            if (r.item.custom) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Pill(
                  text: 'Eliminar',
                  icon: Icons.delete_outline_rounded,
                  danger: true,
                  onTap: () async {
                    if (await confirm(ctx, 'Eliminar', '¿Eliminar "${r.name}"?', ok: 'Eliminar', danger: true)) {
                      await m.remove(id);
                      if (ctx.mounted) Navigator.pop(ctx);
                    }
                  },
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
