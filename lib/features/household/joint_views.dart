import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/household/household_engine.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/household_service.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import 'household_common.dart';
import 'household_screen.dart' show JointLimitSheet, addJointLimit;

/// "Mine" or "Joint", remembered while the app is open.
class ScopeNotifier extends Notifier<NwScope> {
  @override
  NwScope build() => NwScope.mine;
  void set(NwScope s) => state = s;
}

final budgetScopeProvider = NotifierProvider<ScopeNotifier, NwScope>(ScopeNotifier.new);
final wealthScopeProvider = NotifierProvider<ScopeNotifier, NwScope>(ScopeNotifier.new);

/// The Mine / Joint switch shown under a tab's header.
class ScopeToggle extends StatelessWidget {
  const ScopeToggle({super.key, required this.value, required this.onChanged});
  final NwScope value;
  final ValueChanged<NwScope> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.lg),
    child: Segmented<NwScope>(
      key: const Key('scope_toggle'),
      segments: const {NwScope.mine: 'Mine', NwScope.joint: 'Joint'},
      value: value,
      onChanged: onChanged,
    ),
  );
}

String _daysAway(int d) => d == 0 ? 'today' : (d == 1 ? 'tomorrow' : 'in $d days');

// ---- Budget > Joint -------------------------------------------------------------------

class JointBudgetView extends ConsumerWidget {
  const JointBudgetView(this.j, {super.key, this.now});
  final JointData j;

  /// For tests and screenshots.
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final now = this.now ?? DateTime.now();
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    final b = jointBudget(j.limits, j.txs, month: now, me: j.me, shareMine: j.shareMine);
    final from = DateTime.utc(now.year, now.month, 1), to = DateTime.utc(now.year, now.month + 1, 1);
    final by = spendByMember(j.txs, from: from, to: to, me: j.me, shareMine: j.shareMine);
    final totalSpent = by.fold(0, (a, s) => a + s.spentMinor);
    final today = CalDate(now.year, now.month, now.day);
    final bills = upcomingBills(j.bills, today, j.me);
    final goals = jointGoals(j.goals, me: j.me, shareMine: j.shareMine);
    final daysLeft = DateTime.utc(now.year, now.month + 1, 0).day - now.day;
    final hasLimits = b.lines.isNotEmpty;

    return Column(
      key: const Key('joint_budget'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroNumber(
          label: 'Household spent this month',
          value: totalSpent / 100,
          caption: hasLimits
              ? 'of ${aedMinor(b.plannedMinor)} in joint limits · $daysLeft days left'
              : 'No joint limits yet · $daysLeft days left',
          footer: hasLimits
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Meter(value: b.progress, color: c.forProgress(b.progress)),
                    const SizedBox(height: Space.md),
                    Row(
                      children: [
                        Dot(c.forProgress(b.progress)),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            '${PulseColors.statusLabel(b.progress)} · ${aedMinor(b.remainingMinor.abs())} ${b.remainingMinor < 0 ? 'over' : 'left'} in limits',
                            style: context.tt.bodyMedium!.copyWith(color: c.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : null,
        ),
        SectionHeader('Joint limits', action: 'Add', onAction: () => addJointLimit(context, ref)),
        if (!hasLimits)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Pick the categories you manage together, like groceries or dining, and set one limit for both of you.',
              style: context.tt.bodySmall,
            ),
          )
        else
          RowGroup(
            indent: 32 + Space.md,
            children: [
              for (final l in b.lines)
                _LimitRow(l, categoryFor(cats, l.limit.categoryId), j),
            ],
          ),
        const SectionHeader('Who spent it'),
        if (by.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Nothing shared yet this month.', style: context.tt.bodySmall),
          )
        else
          RowGroup(
            key: const Key('by_member'),
            indent: 32 + Space.md,
            children: [
              for (final s in by)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.md),
                  child: Row(
                    children: [
                      ownerAvatar(j, s.owner),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.owner == j.me ? '${j.nameOf(s.owner)} (you)' : j.nameOf(s.owner),
                                    style: context.tt.bodyLarge,
                                  ),
                                ),
                                Text(aedMinor(s.spentMinor), style: PulseTheme.amount(c.textPrimary, size: 15)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Meter(value: totalSpent == 0 ? 0 : s.spentMinor / totalSpent, height: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        SectionHeader('Shared bills', action: j.bills.isEmpty ? 'Add' : 'Manage', onAction: () => context.push(Routes.household)),
        if (bills.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Split rent, internet or the helper and see what each of you owes.', style: context.tt.bodySmall),
          )
        else
          RowGroup(
            key: const Key('joint_bills'),
            children: [
              for (final d in bills)
                ListRow(
                  title: d.bill.name,
                  subtitle: 'Due ${_daysAway(d.daysAway)} · your share ${aedMinor(d.myShareMinor)}',
                  trailing: Text(aedMinor(d.bill.amountMinor), style: PulseTheme.amount(c.textPrimary, size: 15)),
                ),
            ],
          ),
        const SectionHeader('Shared goals'),
        if (goals.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text('Mark a goal as Shared and it shows here for everyone.', style: context.tt.bodySmall),
          )
        else
          RowGroup(
            key: const Key('joint_goals'),
            indent: 32 + Space.md,
            children: [
              for (final g in goals)
                ListRow(
                  leading: ProgressRing(progress: g.progress, size: 32, stroke: 4),
                  title: g.name,
                  subtitle: '${aedMinor(g.kind == 'paydown' ? g.targetMinor - g.currentMinor : g.currentMinor)} of ${aedMinor(g.targetMinor)} · ${absOwnerLabel(j, g.owner)}',
                  trailing: Text('${(g.progress * 100).round()}%', style: PulseTheme.amount(c.textPrimary, size: 15)),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
          child: Text(
            'Joint totals count what is shared and what each person has chosen to share. Private items are never included.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _LimitRow extends ConsumerWidget {
  const _LimitRow(this.l, this.cat, this.j);
  final JointBudgetLine l;
  final SpendCategory cat;
  final JointData j;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final over = l.remainingMinor < 0;
    return Pressable(
      onTap: () => showPulseSheet<void>(
        context,
        builder: (_) => JointLimitSheet(categoryId: cat.id, categoryLabel: cat.label, existing: l.limit),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.md),
        child: Row(
          children: [
            CategoryIcon.well(cat),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(cat.label, style: context.tt.bodyLarge)),
                      Text(
                        over ? '${aedMinor(-l.remainingMinor)} over' : '${aedMinor(l.remainingMinor)} left',
                        style: context.tt.bodyMedium!.copyWith(color: over ? c.negative : c.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Meter(value: l.progress, color: c.forProgress(l.progress)),
                  const SizedBox(height: 4),
                  Text(
                    '${aedMinor(l.spentMinor)} of ${aedMinor(l.limit.limitMinor)}',
                    style: context.tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Wealth > Joint --------------------------------------------------------------------

class JointNetWorthView extends StatelessWidget {
  const JointNetWorthView(this.j, {super.key});
  final JointData j;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final nw = j.netWorth(NwScope.joint);
    final lines = [
      for (final l in j.lines)
        if (visibleInJoint(owner: l.owner, isPrivate: l.isPrivate, me: j.me, shareMine: j.shareMine)) l,
    ]..sort((a, b) {
        if (a.isLiability != b.isLiability) return a.isLiability ? 1 : -1;
        return b.valueMinor.compareTo(a.valueMinor);
      });
    return Column(
      key: const Key('joint_networth'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroNumber(
          label: 'Joint net worth',
          value: nw.netMinor / 100,
          caption: 'Assets ${aedMinor(nw.assetsMinor)} · Liabilities ${aedMinor(nw.liabilitiesMinor)}',
        ),
        const SectionHeader('By person'),
        RowGroup(
          key: const Key('nw_by_owner'),
          indent: 32 + Space.md,
          children: [
            for (final o in nw.byOwner)
              ListRow(
                leading: ownerAvatar(j, o.owner),
                title: o.owner == j.me ? '${j.nameOf(o.owner)} (you)' : j.nameOf(o.owner),
                trailing: Text(
                  Money.aed(o.netMinor / 100, decimals: false),
                  style: PulseTheme.amount(c.textPrimary, size: 15),
                ),
              ),
          ],
        ),
        const SectionHeader('What is counted'),
        RowGroup(
          key: const Key('nw_lines'),
          children: [
            for (final l in lines)
              ListRow(
                title: l.name,
                subtitle: absOwnerLabel(j, l.owner),
                trailing: Text(
                  Money.aed((l.isLiability ? -l.valueMinor : l.valueMinor) / 100, decimals: false),
                  style: PulseTheme.amount(c.textPrimary, size: 15),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
          child: Text(
            j.shareMine
                ? 'Includes shared items and what each person shares. Anything marked Private is left out, here and on their phone.'
                : 'You are not sharing your own items, so they are left out. Turn it on in Settings > Household.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}
