import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/router/router.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/money.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/card_util.dart';
import '../../../data/providers.dart';
import '../../../data/splits_util.dart';
import '../../cards/card_widgets.dart';
import '../../transactions/tx_detail_sheet.dart';
import '../../transactions/tx_tile.dart';
import '../../tour/tab_tip.dart';
import '../../tour/tour_progress.dart';
import '../../goals/goal_widgets.dart';
import '../../goals/goals_screen.dart';
import '../home_sheets.dart';
import 'dashboard_layout.dart';
import '../../coach/coach.dart';

/// One metric widget as it appears on Home. Regular shows the detail, compact
/// folds it to a single quiet row. Widgets with nothing to say yet render
/// nothing, so a fresh install never shows a wall of zeros.
class DashTile extends ConsumerWidget {
  const DashTile(this.widget, {super.key});
  final DashWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = widget.size == WidgetSize.compact;
    return switch (widget.kind) {
      DashKind.safeToSpend => SafeToSpendTile(compact: compact),
      DashKind.budgetProgress => _BudgetTile(compact: compact),
      DashKind.upcoming => _UpcomingTile(compact: compact),
      DashKind.cardRewards => _RewardsTile(compact: compact),
      DashKind.netWorth => _NetWorthTile(compact: compact),
      DashKind.spendByCategory => _CategoryTile(compact: compact),
      DashKind.cashFlow => _CashFlowTile(compact: compact),
      DashKind.savingsRate => _SavingsTile(compact: compact),
      DashKind.splitBalances => _SplitsTile(compact: compact),
      DashKind.recentCaptures => _RecentTile(compact: compact),
      DashKind.goals => _GoalsTile(compact: compact),
    };
  }
}

TextStyle _num(BuildContext context, [Color? color]) =>
    PulseTheme.amount(color ?? context.pc.textPrimary);

/// A compact widget: one titled row on the page background.
Widget _compactRow(
  BuildContext context, {
  required String title,
  required String subtitle,
  required Widget trailing,
  Color? subtitleColor,
  VoidCallback? onTap,
}) => RowGroup(
  children: [
    ListRow(
      title: title,
      subtitle: subtitle,
      subtitleColor: subtitleColor,
      trailing: trailing,
      chevron: onTap != null,
      onTap: onTap,
    ),
  ],
);

class _Section extends StatelessWidget {
  const _Section(this.title, this.child, {this.action, this.onAction});
  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(title, action: action, onAction: onAction),
      child,
    ],
  );
}

// ---- Safe to spend ----

class SafeToSpendTile extends ConsumerWidget {
  const SafeToSpendTile({super.key, this.compact = false});
  final bool compact;

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
        void open() =>
            showPulseSheet<void>(context, builder: (_) => SafeToSpendSheet(v));
        return CoachTarget(
          id: 'safe',
          child: TabTip(
            tab: TipTab.home,
            child: compact
                ? Pressable(
                    onTap: open,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.gutter,
                        Space.lg,
                        Space.gutter,
                        Space.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Safe to spend today',
                              style: context.tt.bodyLarge,
                            ),
                          ),
                          Text(
                            Money.aed(v.today, decimals: false),
                            style: PulseTheme.amount(
                              none ? c.warning : c.textPrimary,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Pressable(
                    onTap: open,
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

// ---- Budget progress ----

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final b = ref.watch(budgetProvider).value;
    if (b == null || b.planned <= 0) return const SizedBox.shrink();
    final over = b.spent > b.planned;
    final tone = over ? c.negative : (b.progress > 0.85 ? c.warning : c.accent);
    final left = over
        ? '${Money.aed(b.spent - b.planned, decimals: false)} over'
        : '${Money.aed(b.remaining, decimals: false)} left';
    void open() => context.go(Routes.budget);
    if (compact) {
      return _compactRow(
        context,
        title: 'Budget',
        subtitle: '$left · ${b.daysLeft} days to go',
        subtitleColor: over ? c.negative : null,
        trailing: ProgressRing(
          progress: b.progress.clamp(0, 1).toDouble(),
          size: 28,
          stroke: 3,
          color: tone,
        ),
        onTap: open,
      );
    }
    return _Section(
      'Budget',
      action: 'Open',
      onAction: open,
      Padding(
        padding: screenPad,
        child: SurfaceCard(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.aed(b.spent, decimals: false),
                    style: PulseTheme.amount(c.textPrimary, size: 24),
                  ),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      'of ${Money.aed(b.planned, decimals: false)}',
                      style: context.tt.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.md),
              Meter(value: b.progress, color: tone, height: 6),
              const SizedBox(height: Space.sm),
              Text(
                '$left · ${b.daysLeft} days to go',
                style: context.tt.bodySmall!.copyWith(
                  color: over ? c.negative : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Upcoming bills and due dates ----

class _UpcomingTile extends ConsumerWidget {
  const _UpcomingTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final cards = ref.watch(myCardsProvider).value;
    if (cards == null) return const SizedBox.shrink();
    final dues = [
      for (final k in cards)
        if (k.totalDue > 0 && k.hasDueDate) dueInfo(k),
    ]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    if (dues.isEmpty) return const SizedBox.shrink();
    if (compact) {
      final d = dues.first;
      final when = d.overdue
          ? 'overdue'
          : (d.daysLeft == 0 ? 'today' : 'in ${d.daysLeft} days');
      return _compactRow(
        context,
        title: 'Next payment',
        subtitle: '${d.card.name} · due $when',
        subtitleColor: d.urgent ? c.warning : null,
        trailing: Text(
          Money.aed(d.totalDue, decimals: false),
          style: _num(context),
        ),
        onTap: () => context.go(Routes.cards),
      );
    }
    return _Section(
      'Card payments',
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          for (final d in dues.take(3))
            DueRow(d, onTap: () => context.go(Routes.cards)),
        ],
      ),
    );
  }
}

// ---- Card rewards ----

class _RewardsTile extends ConsumerWidget {
  const _RewardsTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(cardValueProvider).value;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final total =
        r.ranking.fold<int>(0, (a, x) => a + x.windowRewardsMinor) / 100;
    if (total <= 0) return const SizedBox.shrink();
    final best = [...r.ranking]
      ..sort((a, b) => b.windowRewardsMinor.compareTo(a.windowRewardsMinor));
    final sub = 'Estimated, last 90 days';
    void open() => context.go(Routes.cards);
    if (compact) {
      return _compactRow(
        context,
        title: 'Card rewards',
        subtitle: sub,
        trailing: Text(Money.aed(total, decimals: false), style: _num(context)),
        onTap: open,
      );
    }
    return _Section(
      'Card rewards',
      RowGroup(
        children: [
          ListRow(
            title: Money.aed(total, decimals: false),
            titleStyle: PulseTheme.amount(context.pc.textPrimary, size: 24),
            subtitle: sub,
            onTap: open,
            chevron: true,
          ),
          for (final k in best.take(2))
            if (k.windowRewardsMinor > 0)
              ListRow(
                dense: true,
                title: k.title,
                trailing: Text(
                  Money.aed(k.windowRewardsMinor / 100, decimals: false),
                  style: _num(context),
                ),
              ),
        ],
      ),
    );
  }
}

// ---- Net worth ----

class _NetWorthTile extends ConsumerWidget {
  const _NetWorthTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final nw = ref.watch(netWorthProvider).value;
    if (nw == null) return const SizedBox.shrink();
    final change =
        '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month';
    final tone = nw.changePct >= 0 ? c.positive : c.negative;
    void open() => context.go(Routes.wealth);
    if (compact) {
      return _compactRow(
        context,
        title: 'Net worth',
        subtitle: change,
        subtitleColor: tone,
        trailing: Text(
          Money.aed(nw.total, decimals: false),
          style: _num(context),
        ),
        onTap: open,
      );
    }
    return _Section(
      'Net worth',
      action: 'Open',
      onAction: open,
      Padding(
        padding: screenPad,
        child: SurfaceCard(
          onTap: open,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                Money.aed(nw.total, decimals: false),
                style: PulseTheme.amount(c.textPrimary, size: 28),
              ),
              const SizedBox(height: 2),
              Text(change, style: context.tt.bodySmall!.copyWith(color: tone)),
              if (nw.series.length > 1) ...[
                const SizedBox(height: Space.md),
                Sparkline(values: nw.series, height: 48),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Spend by category ----

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetProvider).value;
    if (b == null) return const SizedBox.shrink();
    final lines = [
      for (final l in b.lines)
        if (l.spent > 0) l,
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    if (lines.isEmpty) return const SizedBox.shrink();
    final total = lines.fold<double>(0, (a, l) => a + l.spent);
    void open() => context.go(Routes.budget);
    if (compact) {
      final top = lines.first;
      return _compactRow(
        context,
        title: 'Biggest category',
        subtitle:
            '${top.category.label} · ${(top.spent / total * 100).round()}% of spend',
        trailing: Text(
          Money.aed(top.spent, decimals: false),
          style: _num(context),
        ),
        onTap: open,
      );
    }
    return _Section(
      'Spend by category',
      action: 'Budget',
      onAction: open,
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          for (final l in lines.take(4))
            ListRow(
              leading: CategoryIcon.well(l.category),
              title: l.category.label,
              subtitle: '${(l.spent / total * 100).round()}% of spend',
              trailing: Text(
                Money.aed(l.spent, decimals: false),
                style: _num(context),
              ),
              onTap: open,
            ),
        ],
      ),
    );
  }
}

// ---- Cash flow ----

class _CashFlowTile extends ConsumerWidget {
  const _CashFlowTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final f = ref.watch(cashflowProvider).value;
    if (f == null || f.months.isEmpty) return const SizedBox.shrink();
    void open() => context.go(Routes.budget);
    if (compact) {
      return _compactRow(
        context,
        title: 'Cash flow',
        subtitle: 'Expected at month end',
        trailing: Text(
          Money.aed(f.projectedEndBalance, decimals: false),
          style: _num(context, f.projectedEndBalance < 0 ? c.negative : null),
        ),
        onTap: open,
      );
    }
    return _Section(
      'Cash flow',
      RowGroup(
        children: [
          ListRow(
            title: 'Cash today',
            trailing: Text(
              Money.aed(f.balanceNow, decimals: false),
              style: _num(context),
            ),
            onTap: open,
          ),
          ListRow(
            title: 'Still to go out',
            subtitle: 'Bills and card dues',
            trailing: Text(
              Money.aed(f.committed, decimals: false),
              style: _num(context),
            ),
            onTap: open,
          ),
          ListRow(
            title: 'Expected at month end',
            titleStyle: context.tt.titleMedium,
            trailing: Text(
              Money.aed(f.projectedEndBalance, decimals: false),
              style: _num(
                context,
                f.projectedEndBalance < 0 ? c.negative : null,
              ),
            ),
            onTap: open,
          ),
        ],
      ),
    );
  }
}

// ---- Savings rate ----

class _SavingsTile extends ConsumerWidget {
  const _SavingsTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final f = ref.watch(cashflowProvider).value;
    if (f == null || f.months.isEmpty) return const SizedBox.shrink();
    // The last month is the current, part-finished one; prefer the last full
    // month when there is one, otherwise show what we have.
    final m = f.months.length > 1
        ? f.months[f.months.length - 2]
        : f.months.last;
    if (m.income <= 0) return const SizedBox.shrink();
    final pct = (m.savingsRate * 100).round();
    final tone = pct >= 20
        ? c.positive
        : (pct >= 0 ? c.textPrimary : c.negative);
    final sub = '${m.label} · saved ${Money.aed(m.saved, decimals: false)}';
    if (compact) {
      return _compactRow(
        context,
        title: 'Savings rate',
        subtitle: sub,
        trailing: Text('$pct%', style: _num(context, tone)),
      );
    }
    return _Section(
      'Savings rate',
      Padding(
        padding: screenPad,
        child: SurfaceCard(
          child: Row(
            children: [
              ProgressRing(
                progress: (m.savingsRate).clamp(0, 1).toDouble(),
                size: 56,
                stroke: 5,
                color: tone,
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$pct%', style: PulseTheme.amount(tone, size: 28)),
                    Text(
                      'of income kept in ${m.label}',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---- Split balances ----

class _SplitsTile extends ConsumerWidget {
  const _SplitsTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final groups = ref.watch(splitGroupsProvider).value;
    if (groups == null) return const SizedBox.shrink();
    final (owed, owe) = myTotals(groups);
    final net = owed - owe;
    final settled = net.abs() < 0.01;
    void open() => context.go(Routes.splits);
    if (compact) {
      return _compactRow(
        context,
        title: 'Splits',
        subtitle: settled
            ? 'All settled'
            : (net > 0 ? 'You are owed' : 'You owe'),
        trailing: Text(
          Money.aed(net.abs(), decimals: false),
          style: _num(
            context,
            settled ? c.textSecondary : (net > 0 ? c.positive : null),
          ),
        ),
        onTap: open,
      );
    }
    return _Section(
      'Splits',
      RowGroup(
        children: [
          ListRow(
            title: 'You are owed',
            trailing: Text(
              Money.aed(owed, decimals: false),
              style: _num(context, owed > 0 ? c.positive : c.textSecondary),
            ),
            onTap: open,
          ),
          ListRow(
            title: 'You owe',
            trailing: Text(
              Money.aed(owe, decimals: false),
              style: _num(context, owe > 0 ? null : c.textSecondary),
            ),
            onTap: open,
          ),
        ],
      ),
    );
  }
}

// ---- Recent captures ----

class _RecentTile extends ConsumerWidget {
  const _RecentTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tx = ref.watch(transactionsProvider);
    return tx.when(
      loading: () => const SkeletonList(rows: 4, height: 52),
      error: (e, _) => Padding(
        padding: screenPad,
        child: Text('Activity unavailable', style: context.tt.bodyMedium),
      ),
      data: (list) => _Section(
        'Recent',
        action: 'See all',
        onAction: () => context.push(Routes.activity),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            for (final t in list.take(compact ? 3 : 5))
              TxTile(
                t,
                onTap: () => showPulseSheet<void>(
                  context,
                  builder: (_) => TxDetailSheet(tx: t),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---- Goals ----

/// Goals on Home. Quiet when there are none; otherwise what is set aside this
/// month and whether anything has slipped.
class _GoalsTile extends ConsumerWidget {
  const _GoalsTile({required this.compact});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(goalsProvider).value;
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    final sum = goalSummary(list);
    void open() => context.push(Routes.goals);
    final line = sum.active == 0
        ? 'All reached'
        : '${sum.active} ${sum.active == 1 ? 'goal' : 'goals'}'
              '${sum.behind > 0 ? ' · ${sum.behind} a little behind' : ' · on track'}';
    if (compact) {
      return _compactRow(
        context,
        title: 'Goals',
        subtitle: line,
        subtitleColor: sum.behind > 0 ? c.warning : null,
        trailing: Text(aedMinor(sum.reservedMinor), style: _num(context)),
        onTap: open,
      );
    }
    final active = list.where((g) => !g.state.done).toList();
    return _Section(
      'Goals',
      action: 'See all',
      onAction: open,
      RowGroup(
        indent: ListRow.leadingInset,
        children: [
          for (final g in (active.isEmpty ? list : active).take(3)) GoalRow(g),
          ListRow(
            dense: true,
            title: 'Set aside this month',
            subtitle: line,
            trailing: Text(aedMinor(sum.reservedMinor), style: _num(context)),
            onTap: open,
          ),
        ],
      ),
    );
  }
}
