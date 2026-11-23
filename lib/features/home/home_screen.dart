import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';
import '../transactions/tx_detail_sheet.dart';
import '../transactions/tx_tile.dart';

/// Home answers one question: how much can I still spend this month?
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.accent,
          backgroundColor: c.surface,
          onRefresh: () async {
            ref.invalidate(netWorthProvider);
            ref.invalidate(myCardsProvider);
            ref.invalidate(statementsProvider);
            ref.invalidate(splitGroupsProvider);
            invalidateLedger(ref);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                greeting,
                subtitle: DateFormat('EEEE d MMMM').format(now),
                trailing: [
                  RoundIconButton(
                    icon: Icons.account_circle_outlined,
                    label: 'Settings',
                    onTap: () => context.push(Routes.settings),
                  ),
                ],
              ),
              const _Hero(),
              const _ComingUp(),
              const _Overview(),
              SectionHeader(
                'Recent',
                action: 'See all',
                onAction: () => context.push(Routes.activity),
              ),
              const _Recent(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends ConsumerWidget {
  const _Hero();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final b = ref.watch(budgetProvider);
    final month = DateFormat('MMMM').format(DateTime.now());
    return b.when(
      loading: () => const Padding(
        padding: screenPad,
        child: Skeleton(height: 120, radius: Radii.md),
      ),
      error: (e, _) => Padding(
        padding: screenPad,
        child: Text('Budget unavailable', style: context.tt.bodyMedium),
      ),
      data: (o) {
        final over = o.remaining < 0;
        return Pressable(
          onTap: () => context.go(Routes.budget),
          child: HeroNumber(
            label: over ? 'Over budget in $month' : 'Left to spend in $month',
            value: o.remaining.abs(),
            color: over ? c.negative : null,
            caption: over
                ? 'Spent ${Money.aed(o.spent, decimals: false)} of ${Money.aed(o.planned, decimals: false)}'
                : '${Money.aed(o.safePerDay, decimals: false)} a day for the next ${o.daysLeft} days',
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Meter(value: o.progress, color: c.forProgress(o.progress)),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${Money.aed(o.spent, decimals: false)} spent',
                        style: context.tt.bodySmall,
                      ),
                    ),
                    Text(
                      'of ${Money.aed(o.planned, decimals: false)}',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ComingUp extends ConsumerWidget {
  const _ComingUp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final cards = ref.watch(myCardsProvider).value;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    final sorted = List.of(cards)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final best = rankCardsFor(cards, SpendCategory.groceries).first;
    final rate = rateFor(best, SpendCategory.groceries);
    final today = DateUtils.dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Coming up'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final k in sorted)
              Builder(
                builder: (context) {
                  final days = DateUtils.dateOnly(
                    k.dueDate,
                  ).difference(today).inDays;
                  return ListRow(
                    leading: SizedBox(
                      width: 32,
                      child: CreditCardVisual(card: k, compact: true),
                    ),
                    title: '${k.issuer} ${k.name}',
                    subtitle: k.minDue > 0
                        ? 'Minimum ${Money.aed(k.minDue, decimals: false)}'
                        : 'Card payment',
                    trailing: Text(
                      days <= 0
                          ? 'Today'
                          : days == 1
                          ? 'Tomorrow'
                          : DateFormat('d MMM').format(k.dueDate),
                      style: context.tt.bodyMedium!.copyWith(
                        color: days <= 5 ? c.warning : null,
                      ),
                    ),
                    onTap: () => context.go(Routes.cards),
                  );
                },
              ),
            if (rate > 0)
              ListRow(
                leading: IconWell(Icons.auto_awesome_outlined, color: c.accent),
                title: 'Groceries? Use ${best.issuer} ${best.name}',
                subtitle:
                    '${rate.toStringAsFixed(rate % 1 == 0 ? 0 : 1)}% back, the best of your cards',
                chevron: true,
                onTap: () {
                  ref
                      .read(analyticsProvider)
                      .track(
                        AnalyticsEvent.cardRecommendationViewed(
                          SpendCategory.groceries.name,
                        ),
                      );
                  context.go(Routes.cards);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Secondary figures, one row each, linking to their home.
class _Overview extends ConsumerWidget {
  const _Overview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final nw = ref.watch(netWorthProvider).value;
    final groups = ref.watch(splitGroupsProvider).value;
    final statements = ref.watch(statementsProvider).value;
    final attention = statements?.where((s) => s.needsAttention).length ?? 0;
    final (owed, owe) = groups == null ? (0.0, 0.0) : myTotals(groups);
    final net = owed - owe;
    TextStyle num(Color col) => PulseTheme.amount(col);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Overview'),
        RowGroup(
          children: [
            if (nw != null)
              ListRow(
                title: 'Net worth',
                subtitle:
                    '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month',
                subtitleColor: nw.changePct >= 0 ? c.positive : c.negative,
                trailing: Text(
                  Money.aed(nw.total, decimals: false),
                  style: num(c.textPrimary),
                ),
                chevron: true,
                onTap: () => context.go(Routes.wealth),
              ),
            if (groups != null)
              ListRow(
                title: 'Splits',
                subtitle: net.abs() < 0.01
                    ? 'All settled'
                    : (net > 0 ? 'You are owed' : 'You owe'),
                trailing: Text(
                  Money.aed(net.abs(), decimals: false),
                  style: num(
                    net.abs() < 0.01
                        ? c.textSecondary
                        : (net > 0 ? c.positive : c.textPrimary),
                  ),
                ),
                chevron: true,
                onTap: () => context.go(Routes.splits),
              ),
            if (statements != null)
              ListRow(
                title: 'Monthly close',
                subtitle: attention == 0
                    ? 'Every statement matches'
                    : '$attention ${attention == 1 ? 'statement needs' : 'statements need'} you',
                subtitleColor: attention == 0 ? null : c.warning,
                chevron: true,
                onTap: () => context.push(Routes.statements),
              ),
          ],
        ),
      ],
    );
  }
}

class _Recent extends ConsumerWidget {
  const _Recent();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(transactionsProvider);
    return tx.when(
      loading: () => const SkeletonList(rows: 4, height: 52),
      error: (e, _) => Padding(
        padding: screenPad,
        child: Text('Activity unavailable', style: context.tt.bodyMedium),
      ),
      data: (list) => RowGroup(
        indent: ListRow.leadingInset,
        children: [
          for (final t in list.take(5))
            TxTile(
              t,
              onTap: () => showPulseSheet<void>(
                context,
                builder: (_) => TxDetailSheet(tx: t),
              ),
            ),
        ],
      ),
    );
  }
}
