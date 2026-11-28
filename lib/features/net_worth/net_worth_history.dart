import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/nw_history.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/recurring_providers.dart';

DateTime _dt(CalDate d) => DateTime(d.year, d.month, d.day);

/// Net worth over time with range chips (1M to All). [fallback] is drawn
/// when there is not enough history yet (a brand-new install).
class NetWorthHistorySection extends ConsumerWidget {
  const NetWorthHistorySection({super.key, this.fallback});
  final Widget? fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final history = ref.watch(netWorthHistoryProvider).value;
    final range = ref.watch(nwRangeProvider);
    final today = ref.watch(recurringTodayProvider);
    if (history == null) return fallback ?? const SizedBox.shrink();
    final pts = pointsFor(history, range, today);
    final chips = Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: Wrap(
        key: const Key('nw_ranges'),
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (final r in NwRange.values)
            Pill(
              r.label,
              selected: r == range,
              onTap: () => ref.read(nwRangeProvider.notifier).set(r),
            ),
        ],
      ),
    );
    if (history.length < 2) return fallback ?? const SizedBox.shrink();
    final shown = sample(pts, 90);
    final fmt = DateFormat(
      range.days != null && range.days! <= 91 ? 'd MMM' : "MMM ''yy",
    );
    final labels = [
      for (final (i, p) in shown.indexed)
        (i == 0 ||
                i == shown.length - 1 ||
                i == shown.length ~/ 3 ||
                i == shown.length * 2 ~/ 3)
            ? fmt.format(_dt(p.date))
            : '',
    ];
    final ch = changeOver(pts);
    final estimated = pts.any((p) => p.estimated);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        chips,
        if (shown.length >= 2) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            child: InspectLineChart(
              key: ValueKey('nw_chart_${range.name}'),
              labels: labels,
              title: (i) => DateFormat('d MMM y').format(_dt(shown[i].date)),
              fill: true,
              height: 150,
              format: Money.aedCompact,
              series: [
                ChartSeries('Net worth', [
                  for (final p in shown) p.netMinor / 100,
                ], c.accent),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Text(
              key: const Key('nw_change'),
              '${ch.deltaMinor >= 0 ? '+' : '-'}${Money.aed(ch.deltaMinor.abs() / 100, decimals: false)}'
              '${ch.pct == 0 ? '' : ' (${ch.pct >= 0 ? '+' : ''}${ch.pct.toStringAsFixed(1)}%)'} over ${range == NwRange.all ? 'all time' : range.label}'
              '${estimated ? '. Earlier days are estimated from your payments.' : ''}',
              style: context.tt.bodySmall!.copyWith(
                color: ch.deltaMinor >= 0 ? c.positive : c.negative,
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              0,
            ),
            child: Text(
              'Not enough history in this range yet.',
              style: context.tt.bodyMedium,
            ),
          ),
      ],
    );
  }
}

/// Assets and liabilities as two stacked bars on one scale, so debt reads
/// against what you own.
class AssetsVsLiabilities extends StatelessWidget {
  const AssetsVsLiabilities(this.list, {super.key});
  final List<Asset> list;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final assets = <AssetKind, double>{};
    final debts = <String, double>{};
    for (final a in list) {
      if (a.isLiability) {
        final k = a.id.startsWith('card:') ? 'Cards' : 'Loans and other';
        debts[k] = (debts[k] ?? 0) + a.value;
      } else {
        assets[a.kind] = (assets[a.kind] ?? 0) + a.value;
      }
    }
    final totalA = assets.values.fold(0.0, (a, b) => a + b);
    final totalL = debts.values.fold(0.0, (a, b) => a + b);
    if (totalA <= 0 && totalL <= 0) return const SizedBox.shrink();
    final scale = totalA > totalL ? totalA : totalL;
    Color shade(int i, int n, Color hue) =>
        Color.lerp(hue, c.surfaceElevated, n <= 1 ? 0.0 : i / (n - 1) * 0.8)!;
    final aEntries = assets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final lEntries = debts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    Widget bar(
      String title,
      double total,
      List<(String, double, Color)> parts,
      Key key,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: context.tt.titleSmall)),
            Text(
              Money.aedCompact(total),
              style: PulseTheme.amount(c.textPrimary, size: 15),
            ),
          ],
        ),
        const SizedBox(height: Space.sm),
        LayoutBuilder(
          builder: (context, box) => Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              key: key,
              width: box.maxWidth * (total / scale),
              child: total <= 0
                  ? const SizedBox(height: 12)
                  : StackedBar(
                      height: 12,
                      slices: [
                        for (final p in parts) ChartSlice(p.$1, p.$2, p.$3),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.md,
          runSpacing: 4,
          children: [
            for (final p in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Dot(p.$3, size: 8),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      '${p.$1} ${Money.aedCompact(p.$2)}',
                      style: context.tt.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Assets and liabilities'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            0,
          ),
          child: Column(
            key: const Key('assets_vs_liabilities'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bar('Assets', totalA, [
                for (final (i, e) in aEntries.indexed)
                  (e.key.label, e.value, shade(i, aEntries.length, c.accent)),
              ], const Key('bar_assets')),
              const SizedBox(height: Space.xl),
              bar('Liabilities', totalL, [
                for (final (i, e) in lEntries.indexed)
                  (e.key, e.value, shade(i, lEntries.length, c.warning)),
              ], const Key('bar_liabilities')),
            ],
          ),
        ),
      ],
    );
  }
}
