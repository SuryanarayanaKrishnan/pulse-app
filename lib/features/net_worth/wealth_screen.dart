import 'package:material_ui/material_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final assets = ref.watch(assetsProvider);
    final nw = ref.watch(netWorthProvider).value;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const ScreenHeader('Wealth', subtitle: 'Assets & liabilities'),
            if (nw != null)
              Padding(
                padding: screenPad,
                child: GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NET WORTH', style: context.tt.labelSmall),
                      const SizedBox(height: 6),
                      AmountText(nw.total, size: 34),
                      const SizedBox(height: Space.md),
                      Sparkline(values: nw.series, height: 90),
                    ],
                  ),
                ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.06),
              ),
            AsyncView<List<Asset>>(
              value: assets,
              loading: const Padding(
                padding: EdgeInsets.only(top: 20),
                child: SkeletonList(rows: 4),
              ),
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

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final byKind = <AssetKind, List<Asset>>{};
    for (final a in list) {
      byKind.putIfAbsent(a.kind, () => []).add(a);
    }
    double sum(AssetKind k) =>
        (byKind[k] ?? []).fold(0.0, (a, e) => a + e.value);
    final assetKinds = AssetKind.values
        .where((k) => k != AssetKind.liability && byKind.containsKey(k))
        .toList();
    final totalAssets = assetKinds.fold(0.0, (a, k) => a + sum(k));
    final liabilities = sum(AssetKind.liability);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Allocation'),
        Padding(
          padding: screenPad,
          child: GlassCard(
            child: Row(
              children: [
                DonutChart(
                  size: 150,
                  slices: [
                    for (final k in assetKinds)
                      DonutSlice(k.label, sum(k), k.color),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Assets', style: context.tt.bodySmall),
                      Text(
                        Money.aedCompact(totalAssets),
                        style: PulseTheme.amount(c.textPrimary, size: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Column(
                    children: [
                      for (final k in assetKinds)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: k.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  k.label,
                                  style: context.tt.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${(sum(k) / totalAssets * 100).round()}%',
                                style: context.tt.labelMedium,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final k in [
          ...assetKinds,
          if (byKind.containsKey(AssetKind.liability)) AssetKind.liability,
        ]) ...[
          SectionHeader(k.label),
          Padding(
            padding: screenPad,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              child: Column(
                children: [
                  for (final a in byKind[k]!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: k.color.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(k.icon, color: k.color, size: 20),
                          ),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: context.tt.titleSmall),
                                if (a.note.isNotEmpty)
                                  Text(a.note, style: context.tt.bodySmall),
                              ],
                            ),
                          ),
                          Text(
                            Money.aed(
                              a.isLiability ? -a.value : a.value,
                              decimals: false,
                            ),
                            style: PulseTheme.amount(
                              a.isLiability ? c.negative : c.textPrimary,
                              size: 15,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: Space.md),
        Padding(
          padding: screenPad,
          child: Text(
            'Liabilities total ${Money.aed(liabilities, decimals: false)}',
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
  }
}
