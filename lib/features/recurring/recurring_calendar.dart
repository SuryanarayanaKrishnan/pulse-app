import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/recurring_plan.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/recurring_providers.dart';
import 'recurring_screen.dart';

/// A calm month grid: a dot under each day something is due or was paid,
/// and the day's items below when you tap it.
class RecurringCalendar extends ConsumerStatefulWidget {
  const RecurringCalendar(this.month, {super.key});
  final RecurringMonth month;

  @override
  ConsumerState<RecurringCalendar> createState() => _RecurringCalendarState();
}

class _RecurringCalendarState extends ConsumerState<RecurringCalendar> {
  int? _day;

  int _initialDay(CalDate today) {
    final m = widget.month;
    final byDay = m.byDay;
    if (today.year == m.month.year && today.month == m.month.month) return today.day;
    return byDay.keys.isEmpty ? 1 : (byDay.keys.toList()..sort()).first;
  }

  @override
  void didUpdateWidget(RecurringCalendar old) {
    super.didUpdateWidget(old);
    if (old.month.month != widget.month.month) _day = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final m = widget.month;
    final today = ref.watch(recurringTodayProvider);
    final days = daysInMonthOf(m.month);
    // Monday-first grid.
    final lead = DateTime(m.month.year, m.month.month, 1).weekday - 1;
    final byDay = m.byDay;
    final selected = _day ?? _initialDay(today);
    final isToday = today.year == m.month.year && today.month == m.month.month;
    Color dotColor(RecState s) => switch (s) {
      RecState.paid => c.textTertiary,
      RecState.upcoming => c.accent,
      RecState.overdue => c.warning,
    };
    final cells = <Widget>[
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++)
        Semantics(
          button: true,
          selected: d == selected,
          label: '${DateFormat('d MMMM').format(DateTime(m.month.year, m.month.month, d))}'
              '${byDay[d] == null ? '' : ', ${byDay[d]!.length} due'}',
          child: Pressable(
            onTap: () => setState(() => _day = d),
            child: Container(
              key: Key('cal_day_$d'),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: d == selected ? c.surfaceElevated : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.md),
                border: isToday && d == today.day ? Border.all(color: c.accent, width: 1.2) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$d',
                    style: context.tt.bodyMedium!.copyWith(
                      color: byDay[d] == null ? c.textSecondary : c.textPrimary,
                      fontWeight: byDay[d] == null ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final s in _dotStates(byDay[d] ?? const [])) ...[
                          Container(
                            key: const Key('cal_dot'),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(color: dotColor(s), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    final items = byDay[selected] ?? const <RecItem>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, Space.xs),
          child: Row(
            children: [
              for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(child: Text(w, style: context.tt.bodySmall!.copyWith(color: c.textTertiary))),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter - 2),
          child: GridView.count(
            key: const Key('recurring_calendar'),
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1,
            children: cells,
          ),
        ),
        SectionHeader(DateFormat('EEEE d MMMM').format(DateTime(m.month.year, m.month.month, selected)), top: Space.lg),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
            child: Text('Nothing due.', style: context.tt.bodyMedium),
          )
        else
          RowGroup(
            indent: ListRow.leadingInset,
            children: [for (final i in items) RecRow(i)],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.md, Space.gutter, 0),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: Space.md,
                  runSpacing: 4,
                  children: [_Key(c.accent, 'Upcoming'), _Key(c.textTertiary, 'Paid'), _Key(c.warning, 'Overdue')],
                ),
              ),
              Text(
                Money.aed(items.fold<int>(0, (a, i) => a + i.amountMinor) / 100, decimals: false),
                style: PulseTheme.amount(c.textSecondary, size: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// At most three dots, one per distinct state present (worst first).
  List<RecState> _dotStates(List<RecItem> items) => [
    for (final s in const [RecState.overdue, RecState.upcoming, RecState.paid])
      if (items.any((i) => i.state == s)) s,
  ];
}

int daysInMonthOf(CalDate m) => DateTime(m.year, m.month + 1, 0).day;

class _Key extends StatelessWidget {
  const _Key(this.color, this.label);
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label, style: context.tt.bodySmall),
    ],
  );
}
