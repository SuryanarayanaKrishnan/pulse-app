import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

/// Income against spending by month, the savings that fall out of it, and
/// where the balance is heading by month end.
class CashflowSection extends ConsumerWidget {
  const CashflowSection({super.key, this.showHeader = true});

  /// False when the section sits inside a chart card that has its own title.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final cf = ref.watch(cashflowProvider).value;
    if (cf == null || cf.months.isEmpty) return const SizedBox.shrink();
    final m = cf.months;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 1, 0);
    final last = m.length - 1;
    final change = cf.projectedEndBalance - cf.balanceNow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) const SectionHeader('Cashflow'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            0,
          ),
          child: GroupedBarChart(
            labels: [for (final x in m) x.label],
            title: (i) => i == last ? '${m[i].label} so far' : m[i].label,
            series: [
              ChartSeries('In', [for (final x in m) x.income], c.textTertiary),
              ChartSeries('Out', [for (final x in m) x.spend], c.accent),
            ],
            extra: (i) => [
              (
                'Saved',
                '${Money.aed(m[i].saved, decimals: false)} · ${(m[i].savingsRate * 100).round()}%',
                m[i].saved >= 0 ? c.positive : c.negative,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        RowGroup(
          children: [
            ListRow(
              dense: true,
              title: 'Projected on ${DateFormat('d MMM').format(end)}',
              subtitle:
                  'At this pace, after ${Money.aed(cf.committed, decimals: false)} of bills and card dues',
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.aed(cf.projectedEndBalance, decimals: false),
                    style: PulseTheme.amount(
                      cf.projectedEndBalance < 0 ? c.negative : c.textPrimary,
                    ),
                  ),
                  Text(
                    '${change >= 0 ? '+' : '−'}${Money.aed(change.abs(), decimals: false)} from today',
                    style: context.tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Spend in one category over six months. Pick the category; tap a month.
class CategoryTrendSection extends ConsumerStatefulWidget {
  const CategoryTrendSection({super.key, this.showHeader = true});

  /// False when the section sits inside a chart card that has its own title.
  final bool showHeader;
  @override
  ConsumerState<CategoryTrendSection> createState() =>
      _CategoryTrendSectionState();
}

class _CategoryTrendSectionState extends ConsumerState<CategoryTrendSection> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final t = ref.watch(categoryTrendsProvider).value;
    if (t == null || t.series.isEmpty) return const SizedBox.shrink();
    final i = _i.clamp(0, t.series.length - 1);
    final s = t.series[i];
    final last = t.labels.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) const SectionHeader('Spend by category'),
        SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: Space.gutter,
              vertical: Space.md,
            ),
            itemCount: t.series.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (_, j) => Pill(
              t.series[j].category.label,
              selected: j == i,
              onTap: () => setState(() => _i = j),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: InspectLineChart(
            key: ValueKey(s.category.id),
            labels: t.labels,
            title: (k) => k == last ? '${t.labels[k]} so far' : t.labels[k],
            fill: true,
            series: [
              ChartSeries(s.category.label, s.values, c.accent),
              ChartSeries(
                'Average',
                [for (final _ in s.values) s.average],
                c.textTertiary,
                dashed: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
