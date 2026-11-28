import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/card_value.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';

double _aed(int minor) => minor / 100;

String _signed(int minor) =>
    '${minor < 0 ? '−' : ''}${Money.aed(_aed(minor.abs()), decimals: false)}';

/// A circular progress ring with a short caption underneath.
class MilestoneRingView extends StatelessWidget {
  const MilestoneRingView(this.ring, {super.key});
  final MilestoneRing ring;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final color = switch (ring.state) {
      RingState.complete => c.positive,
      RingState.expired => c.textTertiary,
      RingState.active => c.accent,
    };
    final detail = switch (ring.state) {
      RingState.complete => 'Done',
      RingState.expired => 'Window closed',
      RingState.active =>
        '${Money.aed(_aed(ring.remainingMinor), decimals: false)} to go'
            '${ring.daysLeft == null ? '' : ' · ${ring.daysLeft} days left'}',
    };
    return Semantics(
      label: '${ring.label}: ${(ring.fraction * 100).round()} percent. $detail',
      child: Row(
        children: [
          ProgressRing(
            progress: ring.fraction,
            size: 52,
            stroke: 5,
            color: color,
            child: Text(
              '${(ring.fraction * 100).round()}%',
              style: context.tt.labelSmall,
            ),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ring.label, style: context.tt.titleSmall),
                Text(
                  '${Money.aed(_aed(ring.currentMinor), decimals: false)} of '
                  '${Money.aed(_aed(ring.targetMinor), decimals: false)} · $detail',
                  style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Rings, benefits and hints for one card; empty when there is nothing to
/// show (so a card without data adds no clutter).
class CardValueSection extends ConsumerWidget {
  const CardValueSection(this.cardId, {super.key});
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final x = ref.watch(cardValueProvider).value?.extras[cardId];
    if (x == null) return const SizedBox.shrink();
    final c = context.pc;
    final rings = [?x.feeWaiver, ?x.welcome];
    if (rings.isEmpty && x.benefits.isEmpty && x.hints.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (x.hints.isNotEmpty) ...[
          const SectionHeader('Heads up'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final h in x.hints)
                ListRow(
                  leading: IconWell(
                    Icons.hourglass_empty_rounded,
                    color: c.warning,
                  ),
                  title: h.message,
                ),
            ],
          ),
        ],
        if (rings.isNotEmpty) ...[
          const SectionHeader('Progress'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Column(
              children: [
                for (final r in rings) ...[
                  MilestoneRingView(r),
                  const SizedBox(height: Space.md),
                ],
              ],
            ),
          ),
        ],
        if (x.benefits.isNotEmpty) ...[
          const SectionHeader('Benefits per year (estimate)'),
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final b in x.benefits)
                ListRow(
                  dense: true,
                  leading: const IconWell(Icons.card_giftcard_rounded),
                  title: b.name,
                  trailing: Text(
                    Money.aed(_aed(b.annualValueMinor), decimals: false),
                    style: PulseTheme.amount(c.positive),
                  ),
                ),
            ],
          ),
        ],
        if (x.estimated)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: Text(
              'Estimates from catalog figures that are not yet verified against the issuer.',
              style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
            ),
          ),
      ],
    );
  }
}

/// Cards ranked by net annual value over the trailing 90 days.
class NetValueRanking extends ConsumerWidget {
  const NetValueRanking({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(cardValueProvider).value;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Net value per year (estimate)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Text(
            'Rewards from your last 90 days, annualised, plus benefits, minus the fee.',
            style: context.tt.bodyMedium,
          ),
        ),
        const SizedBox(height: Space.sm),
        RowGroup(
          indent: 24 + Space.md,
          children: [
            for (final (i, v) in r.ranking.indexed)
              ListRow(
                key: ValueKey('net-${v.id}'),
                leading: SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}',
                    style: PulseTheme.amount(c.textTertiary, size: 15),
                  ),
                ),
                title: v.title,
                subtitle: [
                  '${_signed(v.annualRewardsMinor)} rewards',
                  if (v.annualBenefitsMinor > 0)
                    '${_signed(v.annualBenefitsMinor)} benefits',
                  if (v.annualFeeMinor > 0) '${_signed(v.annualFeeMinor)} fee',
                  if (v.feeWaived) 'fee waived',
                  if (v.estimated) 'unverified terms',
                ].join(' · '),
                trailing: Text(
                  _signed(v.netAnnualMinor),
                  style: PulseTheme.amount(
                    v.netAnnualMinor < 0 ? c.negative : c.textPrimary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
