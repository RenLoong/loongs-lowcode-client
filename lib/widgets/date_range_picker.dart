import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../core/i18n.dart';

/// App date-range picker: dual single-month calendars in a [Row] on wide
/// screens (avoids ShadCalendar internal [Wrap] stacking); manual inputs +
/// quick ranges + confirm.
Future<DateTimeRange?> showAppDateRangePicker({
  required BuildContext context,
  DateTimeRange? initialDateRange,
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  final first = firstDate ?? DateTime(1970);
  final last = lastDate ?? DateTime(2100);
  return showShadDialog<DateTimeRange>(
    context: context,
    builder: (ctx) => _DateRangeDialog(
      initial: initialDateRange,
      firstDate: first,
      lastDate: last,
    ),
  );
}

class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({
    required this.initial,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late ShadDateTimeRange? _range = widget.initial == null
      ? null
      : ShadDateTimeRange(start: widget.initial!.start, end: widget.initial!.end);

  late final TextEditingController _startCtl =
      TextEditingController(text: _fmt(_range?.start));
  late final TextEditingController _endCtl =
      TextEditingController(text: _fmt(_range?.end));

  late DateTime _viewMonth = () {
    final s = widget.initial?.start ?? DateTime.now();
    return DateTime(s.year, s.month);
  }();

  String? _startError;
  String? _endError;

  DateTime get _fromMonth =>
      DateTime(widget.firstDate.year, widget.firstDate.month);
  DateTime get _toMonth =>
      DateTime(widget.lastDate.year, widget.lastDate.month);

  DateTime get _rightMonth =>
      DateTime(_viewMonth.year, _viewMonth.month + 1);

  bool get _canGoBack =>
      DateTime(_viewMonth.year, _viewMonth.month)
          .isAfter(DateTime(_fromMonth.year, _fromMonth.month));

  bool get _canGoForward =>
      DateTime(_rightMonth.year, _rightMonth.month)
          .isBefore(DateTime(_toMonth.year, _toMonth.month));

  bool get _canSave {
    final s = _range?.start;
    final e = _range?.end;
    return s != null &&
        e != null &&
        !e.isBefore(s) &&
        _startError == null &&
        _endError == null;
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime? _parseYmd(String raw) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
    if (m == null) return null;
    final y = int.parse(m[1]!);
    final mo = int.parse(m[2]!);
    final d = int.parse(m[3]!);
    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }

  bool _inBounds(DateTime d) {
    final a = DateTime(
        widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    final b = DateTime(
        widget.lastDate.year, widget.lastDate.month, widget.lastDate.day);
    return !d.isBefore(a) && !d.isAfter(b);
  }

  void _syncInputsFromRange() {
    final s = _fmt(_range?.start);
    final e = _fmt(_range?.end);
    if (_startCtl.text != s) _startCtl.text = s;
    if (_endCtl.text != e) _endCtl.text = e;
    _startError = null;
    _endError = null;
  }

  void _applyRange(ShadDateTimeRange? r, {bool syncInputs = true}) {
    setState(() {
      _range = r;
      if (syncInputs) _syncInputsFromRange();
    });
  }

  void _quick(DateTime start, DateTime end) {
    _applyRange(ShadDateTimeRange(start: start, end: end));
    setState(() => _viewMonth = DateTime(start.year, start.month));
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_viewMonth.year, _viewMonth.month + delta);
    final right = DateTime(next.year, next.month + 1);
    if (delta < 0 &&
        next.isBefore(DateTime(_fromMonth.year, _fromMonth.month))) {
      return;
    }
    if (delta > 0 &&
        right.isAfter(DateTime(_toMonth.year, _toMonth.month))) {
      return;
    }
    setState(() => _viewMonth = next);
  }

  void _onStartChanged(String v) {
    final t = v.trim();
    if (t.isEmpty) {
      setState(() {
        _startError = null;
        _range = ShadDateTimeRange(start: null, end: _range?.end);
      });
      return;
    }
    final d = _parseYmd(t);
    if (d == null) {
      setState(() => _startError = tr('格式 yyyy-MM-dd'));
      return;
    }
    if (!_inBounds(d)) {
      setState(() => _startError = tr('超出可选范围'));
      return;
    }
    final end = _range?.end;
    if (end != null && end.isBefore(d)) {
      setState(() => _startError = tr('开始不能晚于结束'));
      return;
    }
    setState(() {
      _startError = null;
      _endError = null;
      _range = ShadDateTimeRange(start: d, end: end);
      _viewMonth = DateTime(d.year, d.month);
    });
  }

  void _onEndChanged(String v) {
    final t = v.trim();
    if (t.isEmpty) {
      setState(() {
        _endError = null;
        _range = ShadDateTimeRange(start: _range?.start, end: null);
      });
      return;
    }
    final d = _parseYmd(t);
    if (d == null) {
      setState(() => _endError = tr('格式 yyyy-MM-dd'));
      return;
    }
    if (!_inBounds(d)) {
      setState(() => _endError = tr('超出可选范围'));
      return;
    }
    final start = _range?.start;
    if (start != null && d.isBefore(start)) {
      setState(() => _endError = tr('结束不能早于开始'));
      return;
    }
    setState(() {
      _endError = null;
      _startError = null;
      _range = ShadDateTimeRange(start: start, end: d);
    });
  }

  @override
  void dispose() {
    _startCtl.dispose();
    _endCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return ShadDialog(
      title: Text(tr('选择范围')),
      constraints: BoxConstraints(
        minWidth: wide ? 720 : 360,
        maxWidth: wide ? 820 : 420,
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      scrollable: false,
      actions: [
        ShadButton.outline(
          child: Text(tr('取消')),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ShadButton(
          enabled: _canSave,
          child: Text(tr('保存')),
          onPressed: () {
            final s = _range?.start;
            final e = _range?.end;
            if (s == null || e == null) return;
            Navigator.of(context).pop(DateTimeRange(start: s, end: e));
          },
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ShadButton.outline(
                size: ShadButtonSize.sm,
                child: Text(tr('今天')),
                onPressed: () => _quick(today, today),
              ),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                child: Text(tr('近7天')),
                onPressed: () =>
                    _quick(today.subtract(const Duration(days: 6)), today),
              ),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                child: Text(tr('本月')),
                onPressed: () =>
                    _quick(DateTime(today.year, today.month, 1), DateTime(today.year, today.month + 1, 0)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (wide)
            _wideDateInputs()
          else ...[
            _dateField(tr('开始日期'), _startCtl, _startError, _onStartChanged),
            const SizedBox(height: 8),
            _dateField(tr('结束日期'), _endCtl, _endError, _onEndChanged),
          ],
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ShadIconButton.outline(
                    width: 32,
                    height: 32,
                    enabled: _canGoBack,
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _monthCalendar(_viewMonth, isLeft: true)),
                const SizedBox(width: 28),
                Expanded(child: _monthCalendar(_rightMonth, isLeft: false)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: ShadIconButton.outline(
                    width: 32,
                    height: 32,
                    enabled: _canGoForward,
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                ShadIconButton.outline(
                  width: 32,
                  height: 32,
                  enabled: _canGoBack,
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left, size: 18),
                ),
                const Spacer(),
                ShadIconButton.outline(
                  width: 32,
                  height: 32,
                  enabled: _canGoForward,
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _monthCalendar(_viewMonth, isLeft: true),
          ],
        ],
      ),
    );
  }



  Widget _monthCalendar(DateTime month, {required bool isLeft}) {
    return ShadCalendar.range(
      key: ValueKey('cal-${month.year}-${month.month}-$isLeft'),
      selected: _range,
      numberOfMonths: 1,
      initialMonth: month,
      fromMonth: _fromMonth,
      toMonth: _toMonth,
      showOutsideDays: false,
      hideNavigation: true,
      captionLayout: ShadCalendarCaptionLayout.dropdownYears,
      decoration: ShadDecoration.none,
      dayButtonSize: 40,
      gridMainAxisSpacing: 4,
      gridCrossAxisSpacing: 4,
      weekdaysPadding: const EdgeInsets.symmetric(vertical: 6),
      onChanged: (r) => _applyRange(r),
      onMonthChanged: (m) {
        var next = isLeft
            ? DateTime(m.year, m.month)
            : DateTime(m.year, m.month - 1);
        if (next.isBefore(_fromMonth)) {
          next = _fromMonth;
        }
        final right = DateTime(next.year, next.month + 1);
        if (right.isAfter(_toMonth)) {
          next = DateTime(_toMonth.year, _toMonth.month - 1);
          if (next.isBefore(_fromMonth)) next = _fromMonth;
        }
        setState(() => _viewMonth = next);
      },
    );
  }

  /// Labels on one row; inputs + em-dash on the next (dash centers to inputs).
  Widget _wideDateInputs() {
    final muted = ShadTheme.of(context).textTheme.muted;
    final destructive = ShadTheme.of(context).colorScheme.destructive;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(tr('开始日期'), style: muted)),
            const SizedBox(width: 36),
            Expanded(child: Text(tr('结束日期'), style: muted)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ShadInput(
                controller: _startCtl,
                placeholder: const Text('yyyy-MM-dd'),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: _onStartChanged,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('—'),
            ),
            Expanded(
              child: ShadInput(
                controller: _endCtl,
                placeholder: const Text('yyyy-MM-dd'),
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: _onEndChanged,
              ),
            ),
          ],
        ),
        if (_startError != null || _endError != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _startError == null
                    ? const SizedBox.shrink()
                    : Text(_startError!,
                        style: TextStyle(color: destructive, fontSize: 12)),
              ),
              const SizedBox(width: 36),
              Expanded(
                child: _endError == null
                    ? const SizedBox.shrink()
                    : Text(_endError!,
                        style: TextStyle(color: destructive, fontSize: 12)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dateField(
    String label,
    TextEditingController ctl,
    String? error,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: ShadTheme.of(context).textTheme.muted),
        const SizedBox(height: 4),
        ShadInput(
          controller: ctl,
          placeholder: const Text('yyyy-MM-dd'),
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d-]')),
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: onChanged,
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error,
              style: TextStyle(
                  color: ShadTheme.of(context).colorScheme.destructive,
                  fontSize: 12)),
        ],
      ],
    );
  }
}
