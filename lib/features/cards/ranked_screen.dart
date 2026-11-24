import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_ranking.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../wallet/wallet_sections.dart';
import 'card_value_widgets.dart';
import 'card_widgets.dart';

/// Your cards ranked by how you use them, what they earn and what they
/// return after fees; the best card per everyday category; and warnings.
class RankedCardsScreen extends ConsumerStatefulWidget {
  const RankedCardsScreen({super.key});
  @override
  ConsumerState<RankedCardsScreen> createState() => _RankedCardsScreenState();
}

class _RankedCardsScreenState extends ConsumerState<RankedCardsScreen> {
  CardSort _sort = CardSort.use;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final cards = ref.watch(myCardsProvider);
    final txs = ref.watch(transactionsProvider).value ?? const [];
    final best = ref.watch(bestByCategoryProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My cards ranked'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: AsyncView<List<CreditCard>>(
        value: cards,
        onRetry: () => ref.invalidate(myCardsProvider),
        builder: (list) {
          final ranked = cardStandings(list, txs, sort: _sort);
          final warnings = [
            for (final s in ranked)
              if (s.warning != null) s,
          ];
          return ListView(
            padding: const EdgeInsets.only(bottom: Space.xxxl),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.sm,
                  Space.gutter,
                  Space.lg,
                ),
                child: Segmented<CardSort>(
                  segments: {for (final s in CardSort.values) s: s.label},
                  value: _sort,
                  onChanged: (s) => setState(() => _sort = s),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                child: Text(switch (_sort) {
                  CardSort.use => 'Share of your card spending this month.',
                  CardSort.rewards => 'Rewards earned this month, after caps.',
                  CardSort.returns => 'Rewards minus a month of the annual fee, as a share of spend.',
                }, style: context.tt.bodyMedium),
              ),
              const SizedBox(height: Space.sm),
              AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : Motion.base,
                child: RowGroup(
                  key: ValueKey(_sort),
                  indent: 24 + Space.md + 44 + Space.md,
                  children: [
                    for (final (i, s) in ranked.indexed)
                      _StandingRow(
                        rank: i + 1,
                        s: s,
                        sort: _sort,
                        onTap: () =>
                            openCardDetail(context, list, list.indexOf(s.card)),
                      ),
                  ],
                ),
              ),
              const NetValueRanking(),
              const SectionHeader('Best card for each category'),
              if (best == null)
                const SkeletonList(rows: 3, height: 44)
              else
                RowGroup(
                  indent: ListRow.leadingInset,
                  children: [
                    for (final (cat, label, pick) in best)
                      ListRow(
                        dense: true,
                        leading: IconWell(cat.icon),
                        title: label,
                        subtitle: pick == null
                            ? 'No card earns extra here'
                            : '${pick.name}${pick.verified ? '' : ' · unverified terms'}',
                        trailing: Text(
                          pick == null ? '–' : formatRate(pick.ratePct),
                          style: PulseTheme.amount(
                            pick == null ? c.textTertiary : c.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              if (warnings.isNotEmpty) ...[
                const SectionHeader('Worth a look'),
                RowGroup(
                  indent: ListRow.leadingInset,
                  children: [
                    for (final s in warnings)
                      ListRow(
                        leading: IconWell(
                          s.feeNotCovered
                              ? Icons.receipt_long_outlined
                              : Icons.hourglass_empty_rounded,
                          color: c.warning,
                        ),
                        title: cardName(s.card),
                        subtitle: s.warning,
                        chevron: true,
                        onTap: () =>
                            openCardDetail(context, list, list.indexOf(s.card)),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.rank,
    required this.s,
    required this.sort,
    required this.onTap,
  });
  final int rank;
  final CardStanding s;
  final CardSort sort;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final (value, color) = switch (sort) {
      CardSort.use => ('${(s.share * 100).round()}%', c.textPrimary),
      CardSort.rewards => (Money.aed(s.rewards), c.positive),
      CardSort.returns => (
        '${s.netReturnPct >= 0 ? '' : '−'}${s.netReturnPct.abs().toStringAsFixed(1)}%',
        s.netReturnPct < 0 ? c.negative : c.textPrimary,
      ),
    };
    final detail = [
      '${Money.aed(s.spend, decimals: false)} spent',
      '${Money.aed(s.rewards, decimals: false)} earned',
      if (s.card.annualFee > 0)
        '${Money.aed(s.card.annualFee, decimals: false)} fee'
      else
        'no fee',
    ].join(' · ');
    return ListRow(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: PulseTheme.amount(c.textTertiary, size: 15),
            ),
          ),
          const SizedBox(width: Space.md),
          SizedBox(
            width: 44,
            child: CreditCardVisual(card: s.card, compact: true),
          ),
        ],
      ),
      title: cardName(s.card),
      subtitle: detail,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(value, style: PulseTheme.amount(color)),
          if (s.feeNotCovered || s.underused)
            Text(
              s.feeNotCovered ? 'Fee > rewards' : 'Underused',
              style: context.tt.labelSmall!.copyWith(color: c.warning),
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}
