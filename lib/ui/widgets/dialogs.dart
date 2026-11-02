import 'package:flutter/material.dart';

import '../../core/native.dart';
import '../../core/theme.dart';
import '../../data/app_state.dart';
import 'common.dart';

/// Marco común de los diálogos (oscuro o claro según el tema).
class CarDialog extends StatelessWidget {
  const CarDialog({super.key, required this.title, required this.child, this.width = 560, this.subtitle, this.actions});
  final String title;
  final String? subtitle;
  final Widget child;
  final double width;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 568),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          decoration: BoxDecoration(
            color: c.panelSolid,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: c.line),
            boxShadow: [BoxShadow(color: c.shadow, blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: ts(22, w: FontWeight.w700, c: c.text)),
                    if (subtitle != null) Text(subtitle!, style: ts(14, c: c.muted)),
                  ]),
                ),
                RoundBtn(icon: Icons.close_rounded, size: 44, label: 'Cerrar', onTap: () => Navigator.pop(context)),
              ]),
              const SizedBox(height: 14),
              Flexible(child: child),
              if (actions != null) ...[
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  for (var i = 0; i < actions!.length; i++) ...[if (i > 0) const SizedBox(width: 10), actions![i]],
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Teclado numérico grande (sin el teclado de Android, que tapa media pantalla).
Future<int?> askNumber(BuildContext context, {required String title, String? subtitle, int? initial, String suffix = 'km', int max = 9999999}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _NumberPad(title: title, subtitle: subtitle, initial: initial, suffix: suffix, max: max),
  );
}

class _NumberPad extends StatefulWidget {
  const _NumberPad({required this.title, this.subtitle, this.initial, required this.suffix, required this.max});
  final String title;
  final String? subtitle;
  final int? initial;
  final String suffix;
  final int max;

  @override
  State<_NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<_NumberPad> {
  late String v = widget.initial?.toString() ?? '';
  bool fresh = true;

  void key(String k) {
    setState(() {
      if (fresh) {
        v = '';
        fresh = false;
      }
      if (k == '<') {
        if (v.isNotEmpty) v = v.substring(0, v.length - 1);
      } else if (k == 'C') {
        v = '';
      } else {
        final n = v + k;
        if ((int.tryParse(n) ?? 0) <= widget.max) v = n.replaceFirst(RegExp(r'^0+(?=\d)'), '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final n = int.tryParse(v);
    Widget k(String t, {IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Tap(
              onTap: () => key(t),
              child: Container(
                height: 60,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(16)),
                child: icon != null ? Icon(icon, color: c.text, size: 26) : Text(t, style: ts(26, w: FontWeight.w600, c: c.text)),
              ),
            ),
          ),
        );
    return CarDialog(
      title: widget.title,
      subtitle: widget.subtitle,
      width: 600,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          flex: 5,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              height: 84,
              width: double.infinity,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: c.field,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: alpha(c.accent, 0.5)),
              ),
              child: Row(children: [
                Flexible(
                  child: Text(n == null ? '—' : miles(n),
                      overflow: TextOverflow.ellipsis,
                      style: ts(40, w: FontWeight.w700, c: fresh ? c.muted : c.text, ls: -1)),
                ),
                const SizedBox(width: 8),
                Text(widget.suffix, style: ts(18, w: FontWeight.w600, c: c.muted)),
              ]),
            ),
            const SizedBox(height: 16),
            Pill(
              text: 'Guardar',
              icon: Icons.check_rounded,
              primary: true,
              expand: true,
              height: 56,
              onTap: n == null ? null : () => Navigator.pop(context, n),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [k('1'), k('2'), k('3')]),
            Row(children: [k('4'), k('5'), k('6')]),
            Row(children: [k('7'), k('8'), k('9')]),
            Row(children: [k('C'), k('0'), k('<', icon: Icons.backspace_outlined)]),
          ]),
        ),
      ]),
    );
  }
}

/// Pide un texto corto (nombre de un ítem propio).
Future<String?> askText(BuildContext context, {required String title, String initial = '', String hint = ''}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final c = ctx.pal;
      return CarDialog(
        title: title,
        actions: [
          Pill(
            text: 'Aceptar',
            primary: true,
            onTap: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
          ),
        ],
        child: TextField(
          controller: ctrl,
          autofocus: true,
          style: ts(20, w: FontWeight.w600, c: c.text),
          cursorColor: c.accent,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: ts(20, c: c.muted),
            filled: true,
            fillColor: c.field,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          onSubmitted: (t) {
            if (t.trim().isNotEmpty) Navigator.pop(ctx, t.trim());
          },
        ),
      );
    },
  );
}

/// Elegir una app instalada. Devuelve el paquete, '' para "ninguna" o null si se cancela.
Future<String?> pickApp(BuildContext context, {required String title, String? current, bool allowNone = true}) {
  return showDialog<String>(context: context, builder: (_) => _AppPicker(title: title, current: current, allowNone: allowNone));
}

class _AppPicker extends StatefulWidget {
  const _AppPicker({required this.title, this.current, required this.allowNone});
  final String title;
  final String? current;
  final bool allowNone;
  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  List<AppEntry> all = const [];
  String q = '';

  @override
  void initState() {
    super.initState();
    App.i.apps().then((v) {
      if (mounted) setState(() => all = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pal;
    final list = q.isEmpty ? all : all.where((a) => a.label.toLowerCase().contains(q.toLowerCase())).toList();
    return CarDialog(
      title: widget.title,
      width: 720,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          style: ts(17, c: c.text),
          cursorColor: c.accent,
          decoration: InputDecoration(
            hintText: 'Buscar app',
            hintStyle: ts(17, c: c.muted),
            prefixIcon: Icon(Icons.search_rounded, color: c.muted),
            filled: true,
            fillColor: c.field,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => q = v),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisExtent: 96, crossAxisSpacing: 8, mainAxisSpacing: 6),
            itemCount: list.length + (widget.allowNone ? 1 : 0),
            itemBuilder: (_, i) {
              if (widget.allowNone && i == 0) {
                return _cell(c, null, 'Ninguna', widget.current == null, () => Navigator.pop(context, ''));
              }
              final a = list[i - (widget.allowNone ? 1 : 0)];
              return _cell(c, a.pkg, a.label, a.pkg == widget.current, () => Navigator.pop(context, a.pkg));
            },
          ),
        ),
      ]),
    );
  }

  Widget _cell(Pal c, String? pkg, String label, bool sel, VoidCallback onTap) => Tap(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: sel ? alpha(c.accent, 0.16) : Colors.transparent,
            border: Border.all(color: sel ? c.accent : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            pkg == null
                ? Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(14)),
                    child: Icon(Icons.block_rounded, color: c.muted),
                  )
                : AppIcon(pkg, size: 48),
            const SizedBox(height: 6),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(12, w: FontWeight.w600, c: c.text2)),
          ]),
        ),
      );
}

/// Pregunta de sí/no.
Future<bool> confirm(BuildContext context, String title, String text, {String ok = 'Aceptar', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => CarDialog(
      title: title,
      width: 480,
      actions: [
        Pill(text: 'Cancelar', onTap: () => Navigator.pop(ctx, false)),
        Pill(text: ok, primary: !danger, danger: danger, onTap: () => Navigator.pop(ctx, true)),
      ],
      child: Text(text, style: ts(16, c: ctx.pal.text2)),
    ),
  );
  return r ?? false;
}
