import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

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
            const ScreenHeader('Wealth', subtitle: 'Assets and liabilities'),
            if (nw != null)
              HeroNumber(
                label: 'Net worth',
                value: nw.total,
                caption:
                    '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month',
                captionColor: nw.changePct >= 0 ? c.positive : c.negative,
                footer: Sparkline(values: nw.series, height: 64),
              ),
            AsyncView<List<Asset>>(
              value: assets,
              loading: const SkeletonList(rows: 4),
              onRetry: () => ref.invalidate(assetsProvider),
              builder: (list) => _Body(list),
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
                ChartSlice(kinds[i].label, sum(kinds[i]), _shade(c, i, kinds.length)),
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
