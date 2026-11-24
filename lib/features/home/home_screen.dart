import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_util.dart';
import '../../data/insights.dart';
import '../../data/providers.dart';
import '../../data/splits_util.dart';
import '../cards/card_widgets.dart';
import '../transactions/tx_detail_sheet.dart';
import 'health_sheet.dart';
import '../transactions/tx_tile.dart';

/// Home answers one question: how much can I safely spend today?
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
              const _WhichCard(),
              const _Health(),
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
    final s = ref.watch(safeToSpendProvider);
    return s.when(
      loading: () => const Padding(
        padding: screenPad,
        child: Skeleton(height: 120, radius: Radii.md),
      ),
      error: (e, _) => Padding(
        padding: screenPad,
        child: Text('Safe to spend unavailable', style: context.tt.bodyMedium),
      ),
      data: (v) {
        final none = v.available <= 0;
        return Pressable(
          onTap: () => showPulseSheet<void>(
            context,
            builder: (_) => _SafeToSpendSheet(v),
          ),
          child: HeroNumber(
            label: 'Safe to spend today',
            value: v.today,
            color: none ? c.warning : null,
            caption: none
                ? 'Bills, card dues and goals take what is left this month'
                : '${Money.aed(v.available, decimals: false)} free for the next ${v.daysLeft} days, after bills, card dues and goals',
            footer: Row(
              children: [
                _Figure('Bills', v.bills),
                _Figure('Card dues', v.cardDues),
                _Figure('Goals', v.goals),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value);
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.tt.bodySmall),
        const SizedBox(height: 2),
        Text(
          Money.aed(value, decimals: false),
          style: PulseTheme.amount(context.pc.textPrimary, size: 15),
        ),
      ],
    ),
  );
}

class _SafeToSpendSheet extends ConsumerWidget {
  const _SafeToSpendSheet(this.v);
  final SafeToSpend v;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final b = ref.watch(budgetProvider).value;
    Text num(double x, {bool minus = false}) => Text(
      '${minus ? '−' : ''}${Money.aed(x, decimals: false)}',
      style: PulseTheme.amount(minus ? c.textSecondary : c.textPrimary),
    );
    return SheetScaffold(
      title: 'Safe to spend',
      subtitle: 'The lower of what your budget and your cash allow',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RowGroup(
            padding: EdgeInsets.zero,
            children: [
              if (b != null)
                ListRow(
                  dense: true,
                  title: 'Left in budget',
                  trailing: num(b.remaining),
                ),
              ListRow(
                dense: true,
                title: 'Bills still to come',
                trailing: num(v.bills, minus: true),
              ),
              ListRow(
                dense: true,
                title: 'Card dues this month',
                subtitle: 'From your cash, not your budget',
                trailing: num(v.cardDues, minus: true),
              ),
              ListRow(
                dense: true,
                title: 'Goal contributions',
                trailing: num(v.goals, minus: true),
              ),
              ListRow(
                dense: true,
                title: 'Free until month end',
                titleStyle: context.tt.titleMedium,
                trailing: num(v.available),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          Text(
            'Spread over ${v.daysLeft} days, that is ${Money.aed(v.today, decimals: false)} a day. It updates with every purchase.',
            style: context.tt.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Pre-purchase advice, one tap from Home.
class _WhichCard extends ConsumerWidget {
  const _WhichCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xl,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        onTap: () => showWhichCard(context, ref),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(Icons.bolt_rounded, size: 20, color: c.onAccent),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which card should I use?',
                    style: context.tt.titleSmall,
                  ),
                  Text('Before you pay', style: context.tt.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Health extends ConsumerWidget {
  const _Health();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final h = ref.watch(healthScoreProvider).value;
    if (h == null || h.insufficient) return const SizedBox.shrink();
    final tone = h.score >= 60
        ? c.accent
        : h.score >= 40
        ? c.warning
        : c.negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Today'),
        RowGroup(
          children: [
            ListRow(
              leading: ProgressRing(
                progress: h.score / 100,
                size: 32,
                stroke: 3,
                color: tone,
              ),
              title: 'Financial health ${h.score} · ${h.band}',
              subtitle: h.readiness,
              chevron: true,
              onTap: () =>
                  showPulseSheet<void>(context, builder: (_) => HealthSheet(h)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComingUp extends ConsumerWidget {
  const _ComingUp();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myCardsProvider).value;
    if (cards == null || cards.isEmpty) return const SizedBox.shrink();
    final dues = [
      for (final k in cards)
        if (k.totalDue > 0) dueInfo(k),
    ]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    if (dues.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Card payments'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final d in dues.take(3))
              DueRow(d, onTap: () => context.go(Routes.cards)),
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
            ListRow(
              title: 'Family',
              subtitle: 'Shared spending, with privacy per person',
              chevron: true,
              onTap: () => context.push(Routes.family),
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
