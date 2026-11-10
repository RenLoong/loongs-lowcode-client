import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/i18n.dart';
import '../page_desc.dart';
import 'fields.dart';
import '../../widgets/date_range_picker.dart';

Color? _parseColor(Object? raw) {
  if (raw == null) return null;
  var s = '$raw'.trim();
  if (s.contains('|')) s = s.split('|').first.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 3) s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  if (s.length != 6 && s.length != 8) return null;
  final v = int.tryParse(s, radix: 16);
  if (v == null) return null;
  return s.length == 8 ? Color(v) : Color(0xFF000000 | v);
}

String _hex(Color c) {
  final v = c.toARGB32() & 0xFFFFFF;
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

const _palette = <Color>[
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFEF4444),
  Color(0xFFA855F7),
  Color(0xFF06B6D4),
  Color(0xFFF97316),
  Color(0xFF64748B),
  Color(0xFF000000),
  Color(0xFFFFFFFF),
];

class ColorField extends StatelessWidget {
  const ColorField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    final current = _parseColor(form[name] ?? f['default']) ?? const Color(0xFF3B82F6);
    return Row(children: [
      InkWell(
        onTap: ro
            ? null
            : () async {
                final picked = await showDialog<Color>(
                  context: context,
                  builder: (c) => _ColorDialog(initial: current),
                );
                if (picked != null) form.set(name, _hex(picked));
              },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: current,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ShadTheme.of(context).colorScheme.border),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ShadInput(
          key: ValueKey('color-$name-${form[name]}'),
          initialValue: '${form[name] ?? f['default'] ?? _hex(current)}',
          readOnly: ro,
          enabled: !ro,
          placeholder: const Text('#RRGGBB'),
          onChanged: (v) => form.set(name, v.trim()),
        ),
      ),
    ]);
  }
}

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({required this.initial});
  final Color initial;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late Color selected = widget.initial;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('选择颜色')),
      content: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _palette)
          InkWell(
            onTap: () => setState(() => selected = c),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected.toARGB32() == c.toARGB32()
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black26,
                  width: selected.toARGB32() == c.toARGB32() ? 2 : 1,
                ),
              ),
            ),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('取消'))),
        FilledButton(onPressed: () => Navigator.pop(context, selected), child: Text(tr('确定'))),
      ],
    );
  }
}

class AutocompleteField extends StatelessWidget {
  const AutocompleteField(this.f, this.form, this.env, {super.key});
  final Json f;
  final FormController form;
  final FieldEnv env;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    return FutureBuilder<List<OptionItem>>(
      future: env.options(f),
      builder: (context, snap) {
        final opts = snap.data ?? const <OptionItem>[];
        return Autocomplete<OptionItem>(
          key: ValueKey('ac-$name-${opts.length}'),
          initialValue: TextEditingValue(text: _labelOf(opts, form[name]) ?? '${form[name] ?? ''}'),
          displayStringForOption: (o) => o.label,
          optionsBuilder: (te) {
            final q = te.text.trim().toLowerCase();
            if (q.isEmpty) return opts;
            return opts.where((o) => o.label.toLowerCase().contains(q) || '${o.value}'.toLowerCase().contains(q));
          },
          onSelected: (o) => form.set(name, o.value),
          fieldViewBuilder: (context, controller, focus, onSubmit) {
            return ShadInput(
              controller: controller,
              focusNode: focus,
              readOnly: ro,
              enabled: !ro,
              placeholder: Text('${f['placeholder'] ?? tr('请输入')}'),
              onChanged: (v) => form.set(name, v),
              onSubmitted: (_) => onSubmit(),
            );
          },
        );
      },
    );
  }

  static String? _labelOf(List<OptionItem> opts, Object? v) {
    for (final o in opts) {
      if (sameValue(o.value, v)) return o.label;
    }
    return null;
  }
}

class RateField extends StatelessWidget {
  const RateField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    final max = ((asJson(f['props'])['max'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final cur = ((form[name] ?? f['default'] ?? 0) as num?)?.toInt() ?? 0;
    return Row(children: [
      for (var i = 1; i <= max; i++)
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: ro ? null : () => form.set(name, i),
          icon: Icon(i <= cur ? Icons.star : Icons.star_border, color: Colors.amber.shade700),
        ),
      Text('$cur / $max', style: ShadTheme.of(context).textTheme.muted),
    ]);
  }
}

class SliderField extends StatelessWidget {
  const SliderField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    final props = asJson(f['props']);
    final min = (props['min'] as num?)?.toDouble() ?? 0;
    final max = (props['max'] as num?)?.toDouble() ?? 100;
    final step = (props['step'] as num?)?.toDouble() ?? 1;
    final cur = ((form[name] ?? f['default'] ?? min) as num?)?.toDouble() ?? min;
    return Row(children: [
      Expanded(
        child: Slider(
          value: cur.clamp(min, max),
          min: min,
          max: max,
          divisions: step > 0 ? ((max - min) / step).round().clamp(1, 1000) : null,
          label: '${cur.round()}',
          onChanged: ro ? null : (v) => form.set(name, step >= 1 ? v.round() : v),
        ),
      ),
      SizedBox(width: 48, child: Text('${cur.round()}', textAlign: TextAlign.end)),
    ]);
  }
}

class InputTagField extends StatefulWidget {
  const InputTagField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;
  @override
  State<InputTagField> createState() => _InputTagFieldState();
}

class _InputTagFieldState extends State<InputTagField> {
  final _ctl = TextEditingController();

  List<String> get _tags {
    final v = widget.form['${widget.f['name']}'] ?? widget.f['default'];
    if (v is List) return [for (final e in v) '$e'];
    if (v is String && v.trim().isNotEmpty) {
      return v.split(RegExp(r'[,，\s]+')).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  void _set(List<String> next) => widget.form.set('${widget.f['name']}', next);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ro = fieldReadonly(widget.f);
    final tags = _tags;
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final t in tags)
        InputChip(label: Text(t), onDeleted: ro ? null : () => _set([...tags]..remove(t))),
      if (!ro)
        SizedBox(
          width: 140,
          child: ShadInput(
            controller: _ctl,
            placeholder: Text(tr('回车添加')),
            onSubmitted: (v) {
              final s = v.trim();
              if (s.isEmpty) return;
              if (!tags.contains(s)) _set([...tags, s]);
              _ctl.clear();
            },
          ),
        ),
    ]);
  }
}

class OtpField extends StatefulWidget {
  const OtpField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;
  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final int length = ((asJson(widget.f['props'])['length'] as num?)?.toInt() ?? 6).clamp(4, 8);
  late final List<TextEditingController> _ctls;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    final raw = '${widget.form['${widget.f['name']}'] ?? ''}';
    final initial = (raw + (' ' * length)).substring(0, length);
    _ctls = [for (var i = 0; i < length; i++) TextEditingController(text: initial[i].trim())];
    _nodes = [for (var i = 0; i < length; i++) FocusNode()];
  }

  @override
  void dispose() {
    for (final c in _ctls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _sync() => widget.form.set('${widget.f['name']}', _ctls.map((c) => c.text).join());

  @override
  Widget build(BuildContext context) {
    final ro = fieldReadonly(widget.f);
    return Row(children: [
      for (var i = 0; i < length; i++) ...[
        if (i > 0) const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: ShadInput(
            controller: _ctls[i],
            focusNode: _nodes[i],
            readOnly: ro,
            enabled: !ro,
            textAlign: TextAlign.center,
            maxLength: 1,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]'))],
            onChanged: (v) {
              if (v.isNotEmpty && i + 1 < length) _nodes[i + 1].requestFocus();
              if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
              _sync();
            },
          ),
        ),
      ],
    ]);
  }
}

class MentionField extends StatelessWidget {
  const MentionField(this.f, this.form, this.env, {super.key});
  final Json f;
  final FormController form;
  final FieldEnv env;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    return FutureBuilder<List<OptionItem>>(
      future: env.options(f),
      builder: (context, snap) {
        final opts = snap.data ?? const <OptionItem>[];
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShadInput(
            controller: form.text(name),
            readOnly: ro,
            enabled: !ro,
            maxLines: 4,
            minLines: 2,
            placeholder: Text('${f['placeholder'] ?? tr('输入 @ 提及')}'),
            onChanged: (v) => form.set(name, v),
          ),
          if (!ro && opts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final o in opts.take(8))
                ActionChip(
                  label: Text('@${o.label}'),
                  onPressed: () {
                    final cur = form.text(name).text;
                    final next = cur.endsWith(' ') || cur.isEmpty ? '$cur@${o.label} ' : '$cur @${o.label} ';
                    form.text(name).text = next;
                    form.text(name).selection = TextSelection.collapsed(offset: next.length);
                    form.set(name, next);
                  },
                ),
            ]),
          ],
        ]);
      },
    );
  }
}

class TransferField extends StatelessWidget {
  const TransferField(this.f, this.form, this.env, {super.key});
  final Json f;
  final FormController form;
  final FieldEnv env;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    return FutureBuilder<List<OptionItem>>(
      future: env.options(f),
      builder: (context, snap) {
        final opts = snap.data ?? const <OptionItem>[];
        final selected = [for (final v in ((form[name] as List?) ?? const [])) v];
        bool isOn(OptionItem o) => selected.any((v) => sameValue(v, o.value));
        final left = opts.where((o) => !isOn(o)).toList();
        final right = opts.where(isOn).toList();
        Widget pane(String title, List<OptionItem> items, void Function(OptionItem) onTap) {
          return Expanded(
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: ShadTheme.of(context).colorScheme.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title, style: ShadTheme.of(context).textTheme.small),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(children: [
                    for (final o in items)
                      ListTile(
                        dense: true,
                        title: Text(o.label),
                        enabled: !ro,
                        onTap: ro ? null : () => onTap(o),
                      ),
                  ]),
                ),
              ]),
            ),
          );
        }

        return Row(children: [
          pane(tr('可选'), left, (o) => form.set(name, [...selected, o.value])),
          const SizedBox(width: 8),
          pane(tr('已选'), right, (o) {
            final next = [...selected]..removeWhere((v) => sameValue(v, o.value));
            form.set(name, next);
          }),
        ]);
      },
    );
  }
}

class UploadField extends StatelessWidget {
  const UploadField(this.f, this.form, {super.key, this.imageOnly = false});
  final Json f;
  final FormController form;
  final bool imageOnly;

  List<Map<String, dynamic>> _files() {
    final v = form['${f['name']}'] ?? f['default'];
    if (v is List) {
      return [
        for (final e in v)
          if (e is Map)
            e.cast<String, dynamic>()
          else if (e != null)
            {'name': '$e', 'url': '$e'},
      ];
    }
    if (v is String && v.isNotEmpty) return [{'name': v, 'url': v}];
    if (v is Map) return [v.cast<String, dynamic>()];
    return [];
  }

  Future<void> _add(BuildContext context) async {
    final nameCtl = TextEditingController();
    final urlCtl = TextEditingController(text: imageOnly ? 'https://' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(imageOnly ? tr('添加图片') : tr('添加附件')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtl, decoration: InputDecoration(labelText: tr('文件名'))),
          TextField(controller: urlCtl, decoration: InputDecoration(labelText: tr('URL（可选）'))),
          const SizedBox(height: 8),
          Text(tr('未接文件服务时仅保存元数据，不实际上传'), style: Theme.of(c).textTheme.bodySmall),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('取消'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('确定'))),
        ],
      ),
    );
    if (ok != true) return;
    final nm = nameCtl.text.trim();
    final url = urlCtl.text.trim();
    if (nm.isEmpty && url.isEmpty) return;
    final entry = {
      'name': nm.isEmpty ? url.split('/').last : nm,
      'url': url.isEmpty ? 'local://$nm' : url,
    };
    final nameKey = '${f['name']}';
    if (imageOnly) {
      form.set(nameKey, entry);
    } else {
      form.set(nameKey, [..._files(), entry]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ro = fieldReadonly(f);
    final files = _files();
    if (imageOnly) {
      final one = files.isEmpty ? null : files.first;
      final url = one?['url'] as String?;
      final net = url != null && (url.startsWith('http://') || url.startsWith('https://'));
      return Row(children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: net ? NetworkImage(url as String) : null,
          child: net ? null : const Icon(Icons.person),
        ),
        const SizedBox(width: 12),
        if (!ro) ShadButton.outline(onPressed: () => _add(context), child: Text(tr('选择头像'))),
        if (one != null) ...[
          const SizedBox(width: 8),
          Flexible(child: Text('${one['name']}', overflow: TextOverflow.ellipsis)),
          if (!ro)
            IconButton(
              onPressed: () => form.set('${f['name']}', null),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final file in files)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.attach_file, size: 18),
          title: Text('${file['name']}', overflow: TextOverflow.ellipsis),
          subtitle: Text('${file['url']}', overflow: TextOverflow.ellipsis),
          trailing: ro
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    final next = [...files]..removeWhere((e) => e['url'] == file['url'] && e['name'] == file['name']);
                    form.set('${f['name']}', next);
                  },
                ),
        ),
      if (!ro) ShadButton.outline(size: ShadButtonSize.sm, onPressed: () => _add(context), child: Text(tr('添加附件'))),
    ]);
  }
}

class RichTextField extends StatelessWidget {
  const RichTextField(this.f, this.form, {super.key});
  final Json f;
  final FormController form;

  @override
  Widget build(BuildContext context) {
    final name = '${f['name']}';
    final ro = fieldReadonly(f);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!ro)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(spacing: 4, children: [
            for (final item in <(String, String, String)>[('**B**', '**', '**'), ('_I_', '_', '_'), ('`code`', '`', '`')])
              ActionChip(
                label: Text(item.$1, style: const TextStyle(fontSize: 12)),
                onPressed: () {
                  final c = form.text(name);
                  final t = c.text;
                  final sel = c.selection;
                  final start = sel.start >= 0 ? sel.start : t.length;
                  final end = sel.end >= 0 ? sel.end : t.length;
                  final inner = start <= end && end <= t.length ? t.substring(start, end) : '';
                  final next = t.replaceRange(start, end, '${item.$2}$inner${item.$3}');
                  c.value = TextEditingValue(
                    text: next,
                    selection: TextSelection.collapsed(offset: start + item.$2.length + inner.length + item.$3.length),
                  );
                  form.set(name, next);
                },
              ),
            Text(tr('Markdown'), style: ShadTheme.of(context).textTheme.muted),
          ]),
        ),
      ShadInput(
        controller: form.text(name),
        readOnly: ro,
        enabled: !ro,
        maxLines: 8,
        minLines: 4,
        placeholder: Text('${f['placeholder'] ?? ''}'),
        onChanged: (v) => form.set(name, v),
      ),
    ]);
  }
}

class DateTimeFields {
  static Widget build(BuildContext context, Json f, FormController form, {bool dense = false}) {
    final name = '${f['name']}';
    final comp = '${f['component']}';
    final ro = fieldReadonly(f);
    Future<void> pick() async {
      if (ro) return;
      final now = DateTime.now();
      if (comp == 'time') {
        final initial = _parseTime('${form[name] ?? ''}') ?? TimeOfDay.fromDateTime(now);
        final t = await showTimePicker(context: context, initialTime: initial);
        if (t != null) {
          final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          form.set(name, v);
          form.text(name).text = v;
        }
        return;
      }
      if (comp == 'dateRange') {
        final range = await showAppDateRangePicker(
          context: context,
          firstDate: DateTime(1970),
          lastDate: DateTime(2100),
          initialDateRange: _parseRange('${form[name] ?? ''}'),
        );
        if (range != null) {
          final v = '${_ymd(range.start)} ~ ${_ymd(range.end)}';
          form.set(name, v);
          form.text(name).text = v;
        }
        return;
      }
      final initial = _parseDate('${form[name] ?? ''}') ?? now;
      final d = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(1970),
        lastDate: DateTime(2100),
      );
      if (d == null) return;
      if (comp == 'datetime') {
        if (!context.mounted) return;
        final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
        final dt = DateTime(d.year, d.month, d.day, t?.hour ?? 0, t?.minute ?? 0);
        final v =
            '${_ymd(dt)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
        form.set(name, v);
        form.text(name).text = v;
      } else {
        final v = _ymd(d);
        form.set(name, v);
        form.text(name).text = v;
      }
    }

    return Row(children: [
      Expanded(
        child: ShadInput(
          controller: form.text(name),
          readOnly: true,
          enabled: !ro,
          placeholder: Text(dense ? '${f['label'] ?? name}' : '${f['placeholder'] ?? ''}'),
        ),
      ),
      if (!ro)
        IconButton(
          onPressed: pick,
          icon: Icon(comp == 'time' ? Icons.schedule : Icons.calendar_today, size: 18),
        ),
    ]);
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s.trim());
    if (m == null) return null;
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static TimeOfDay? _parseTime(String s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s.trim());
    if (m == null) return null;
    return TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
  }

  static DateTimeRange? _parseRange(String s) {
    final parts = s.split('~');
    if (parts.length != 2) return null;
    final a = _parseDate(parts[0]);
    final b = _parseDate(parts[1]);
    if (a == null || b == null) return null;
    return DateTimeRange(start: a, end: b);
  }
}
