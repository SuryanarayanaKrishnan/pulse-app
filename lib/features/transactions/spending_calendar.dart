import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import 'tx_detail_sheet.dart';
import 'tx_tile.dart';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// What was spent on each calendar day (income and excluded payments left out).
/// Keys are midnight-local dates.
Map<DateTime, double> dailySpend(Iterable<Transaction> txs) {
  final out = <DateTime, double>{};
  for (final t in txs) {
    if (t.isIncome || t.excluded) continue;
    final k = _day(t.date);
    out[k] = (out[k] ?? 0) + t.amount;
  }
  return out;
}

/// Month grid of spending: each day shows what was spent, tap a day to see
/// its transactions underneath. Weeks start on Monday.
class SpendingCalendar extends StatefulWidget {
  const SpendingCalendar({super.key, required this.transactions, this.today});
  final List<Transaction> transactions;

  /// Test hook; defaults to now.
  final DateTime? today;

  @override
  State<SpendingCalendar> createState() => _SpendingCalendarState();
}

class _SpendingCalendarState extends State<SpendingCalendar> {
  late final DateTime _today = _day(widget.today ?? DateTime.now());
  late DateTime _month = _initialMonth();
  late DateTime _selected = _today;

  DateTime _initialMonth() {
    // Open on the current month, or the latest one with data if that is empty.
    final cur = DateTime(_today.year, _today.month);
    final has = widget.transactions.any(
      (t) => t.date.year == cur.year && t.date.month == cur.month,
    );
    if (has || widget.transactions.isEmpty) return cur;
    final latest = widget.transactions
        .map((t) => t.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime(latest.year, latest.month);
  }

  void _shift(int by) => setState(() {
    _month = DateTime(_month.year, _month.month + by);
    final inMonth =
        _selected.year == _month.year && _selected.month == _month.month;
    if (!inMonth) _selected = _month;
  });

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tt = context.tt;
    final spend = dailySpend(widget.transactions);
    final first = _month;
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = (first.weekday + 6) % 7; // Monday = 0
    final rows = ((lead + daysIn) / 7).ceil();
    var monthTotal = 0.0;
    for (var d = 1; d <= daysIn; d++) {
      monthTotal += spend[DateTime(_month.year, _month.month, d)] ?? 0;
    }
    final dayTxs =
        widget.transactions.where((t) => _day(t.date) == _selected).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final daySpendTotal = spend[_selected] ?? 0;

    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Row(
            children: [
              IconButton(
                key: const Key('cal_prev'),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _shift(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(_month),
                      key: const Key('cal_title'),
                      style: tt.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Money.aed(monthTotal, decimals: false)} spent',
                      key: const Key('cal_month_total'),
                      style: tt.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('cal_next'),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _shift(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Row(
            children: [
              for (final w in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: tt.bodySmall!.copyWith(color: c.textTertiary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Space.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              for (var r = 0; r < rows; r++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: _cell(
                          context,
                          r * 7 + col - lead + 1,
                          daysIn,
                          spend,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE d MMMM').format(_selected),
                  key: const Key('cal_day_title'),
                  style: tt.bodySmall,
                ),
              ),
              if (daySpendTotal > 0)
                Text(
                  Money.aed(daySpendTotal),
                  key: const Key('cal_day_total'),
                  style: PulseTheme.amount(c.textPrimary, size: 15),
                ),
            ],
          ),
        ),
        if (dayTxs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(Space.gutter),
            child: Text(
              'Nothing on this day.',
              key: const Key('cal_day_empty'),
              style: tt.bodyMedium!.copyWith(color: c.textTertiary),
            ),
          )
        else
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final t in dayTxs)
                TxTile(
                  t,
                  onTap: () => showPulseSheet<void>(
                    context,
                    builder: (_) => TxDetailSheet(tx: t),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _cell(
    BuildContext context,
    int dayNum,
    int daysIn,
    Map<DateTime, double> spend,
  ) {
    const h = 56.0;
    if (dayNum < 1 || dayNum > daysIn) return const SizedBox(height: h);
    final c = context.pc;
    final date = DateTime(_month.year, _month.month, dayNum);
    final amt = spend[date] ?? 0;
    final selected = date == _selected;
    final isToday = date == _today;
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${DateFormat('d MMMM').format(date)}, '
          '${amt > 0 ? Money.aed(amt, decimals: false) : 'no spending'}',
      child: InkWell(
        key: Key('cal_day_$dayNum'),
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: () => setState(() => _selected = date),
        child: Container(
          height: h,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? c.accent.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(Radii.sm),
            border: isToday && !selected
                ? Border.all(color: c.accent.withValues(alpha: 0.6))
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNum',
                style: context.tt.bodyMedium!.copyWith(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              if (amt > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    Money.compact(amt),
                    style: context.tt.labelSmall!.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
