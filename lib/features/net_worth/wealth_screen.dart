import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../wallet/add_sheets.dart';

/// "12 min ago", "3 h ago", "6 days ago".
String ago(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  final days = d.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

class WealthScreen extends ConsumerWidget {
  const WealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final assets = ref.watch(assetsProvider);
    final nw = ref.watch(netWorthProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Wealth',
              subtitle: 'Assets and liabilities',
              trailing: [
                RoundIconButton(
                  icon: Icons.add_rounded,
                  label: 'Add an asset or loan',
                  onTap: () => showPulseSheet<void>(
                    context,
                    builder: (_) => const AddAssetSheet(),
                  ),
                ),
              ],
            ),
            if (nw != null) ...[
              HeroNumber(
                label: 'Net worth',
                value: nw.total,
                caption:
                    '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month',
                captionColor: nw.changePct >= 0 ? c.positive : c.negative,
              ),
              if (nw.updatedAt != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xs,
                    Space.gutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      Dot(c.positive, size: 6),
                      const SizedBox(width: 6),
                      Text(
                        'Live · updated ${ago(nw.updatedAt!)}',
                        style: context.tt.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (nw.labels.length == nw.series.length && nw.series.length > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.xl,
                    Space.gutter,
                    0,
                  ),
                  child: InspectLineChart(
                    labels: [
                      for (final (i, l) in nw.labels.indexed)
                        i.isEven || i == nw.labels.length - 1 ? l : '',
                    ],
                    title: (i) => nw.labels[i],
                    fill: true,
                    height: 140,
                    format: Money.aedCompact,
                    series: [ChartSeries('Net worth', nw.series, c.accent)],
                  ),
                ),
              if (nw.prices.isNotEmpty) ...[
                const SectionHeader('Live values'),
                RowGroup(
                  children: [
                    for (final p in nw.prices)
                      ListRow(
                        dense: true,
                        title: p.name,
                        subtitle: '${p.source} · ${ago(p.updatedAt)}',
                        trailing: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              p.value,
                              style: PulseTheme.amount(c.textPrimary, size: 15),
                            ),
                            if (p.changePct != 0)
                              Text(
                                '${p.changePct > 0 ? '+' : '−'}${p.changePct.abs().toStringAsFixed(1)}%',
                                style: context.tt.bodySmall!.copyWith(
                                  color: p.changePct > 0
                                      ? c.positive
                                      : c.negative,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.sm,
                    Space.gutter,
                    0,
                  ),
                  child: Text(
                    'Gold, property and foreign holdings revalue themselves as these move.',
                    style: context.tt.bodySmall!.copyWith(
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
            AsyncView<List<Asset>>(
              value: assets,
              loading: const SkeletonList(rows: 4),
              onRetry: () => ref.invalidate(assetsProvider),
              builder: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Nothing here yet',
                      message:
                          'Add what you own and owe: accounts, property, gold, '
                          'deposits, loans. Net worth is worked out on this phone.',
                      action: PrimaryButton(
                        label: 'Add an asset',
                        expand: false,
                        onPressed: () => showPulseSheet<void>(
                          context,
                          builder: (_) => const AddAssetSheet(),
                        ),
                      ),
                    )
                  : _Body(list),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.list);
  final List<Asset> list;

  /// Allocation colours: one hue family, stepped in lightness, so the bar
  /// reads as proportion rather than a rainbow.
  static Color _shade(PulseColors c, int i, int n) {
    final t = n <= 1 ? 0.0 : i / (n - 1);
    return Color.lerp(c.accent, c.surfaceElevated, t * 0.85)!;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final byKind = <AssetKind, List<Asset>>{};
    for (final a in list) {
      byKind.putIfAbsent(a.kind, () => []).add(a);
    }
    double sum(AssetKind k) =>
        (byKind[k] ?? []).fold(0.0, (a, e) => a + e.value);
    final kinds =
        AssetKind.values
            .where((k) => k != AssetKind.liability && byKind.containsKey(k))
            .toList()
          ..sort((a, b) => sum(b).compareTo(sum(a)));
    final totalAssets = kinds.fold(0.0, (a, k) => a + sum(k));
    final liabilities = sum(AssetKind.liability);
    TextStyle num([Color? col]) => PulseTheme.amount(col ?? c.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Allocation'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.xs,
          ),
          child: StackedBar(
            slices: [
              for (var i = 0; i < kinds.length; i++)
                ChartSlice(
                  kinds[i].label,
                  sum(kinds[i]),
                  _shade(c, i, kinds.length),
                ),
            ],
          ),
        ),
        RowGroup(
          children: [
            for (var i = 0; i < kinds.length; i++)
              ListRow(
                dense: true,
                leading: Dot(_shade(c, i, kinds.length), size: 10),
                title: kinds[i].label,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(sum(kinds[i]) / totalAssets * 100).round()}%',
                      style: num(c.textSecondary),
                    ),
                    const SizedBox(width: Space.lg),
                    SizedBox(
                      width: 104,
                      child: Text(
                        Money.aedCompact(sum(kinds[i])),
                        style: num(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        for (final k in [
          ...kinds,
          if (byKind.containsKey(AssetKind.liability)) AssetKind.liability,
        ]) ...[
          SectionHeader(k.label),
          RowGroup(
            children: [
              for (final a in byKind[k]!)
                ListRow(
                  title: a.name,
                  subtitle: a.note.isEmpty ? null : a.note,
                  trailing: Text(
                    Money.aed(
                      a.isLiability ? -a.value : a.value,
                      decimals: false,
                    ),
                    style: num(),
                  ),
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            0,
          ),
          child: Text(
            'Assets ${Money.aed(totalAssets, decimals: false)} · '
            'Liabilities ${Money.aed(liabilities, decimals: false)}',
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
  }
}
