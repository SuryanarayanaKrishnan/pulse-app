import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/budget_moves.dart';
import '../../core/engine/flex_budget.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/budget_plan_service.dart';
import '../../data/local/budget_plan_store.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils/money.dart';
import '../goals/goal_widgets.dart' show aedMinor;
import 'move_money_sheet.dart';
import 'month_switcher.dart';

SpendCategory _cat(List<SpendCategory> cats, String id) =>
    cats.firstWhere((c) => c.id == id, orElse: () => SpendCategory(id, id));

/// The fix-overspend gesture and the header button share this.
Future<void> openMoveMoney(
  BuildContext context,
  WidgetRef ref,
  BudgetPlanView plan,
  List<SpendCategory> cats,
  DateTime month, {
  String? to,
}) {
  final over = to == null ? null : plan.row(to);
  final need = over == null || over.remainingMinor >= 0
      ? null
      : -over.remainingMinor;
  return showMoveMoney(
    context,
    ref,
    month: month,
    scope: MoveScope.mine,
    sources: [
      for (final r in plan.rows)
        if (r.plannedMinor > 0)
          MoveSource(
            _cat(cats, r.id),
            r.plannedMinor,
            r.spentMinor,
            saved: r.group == BudgetGroup.nonMonthly,
          ),
    ],
    targets: [
      for (final c in cats)
        if (!c.isIncome && !c.isTransfer) c,
    ],
    to: to,
    suggestMinor: need,
    onChanged: () => invalidateBudgetPlan(ref),
  );
}

/// Budget > flex view: one headline number, three groups, balances that roll
/// over, and Move money.
class FlexBudgetSection extends ConsumerStatefulWidget {
  const FlexBudgetSection({super.key});
  @override
  ConsumerState<FlexBudgetSection> createState() => _FlexState();
}

class _FlexState extends ConsumerState<FlexBudgetSection> {
  BudgetGroup _group = BudgetGroup.flexible;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(budgetMonthProvider);
    final plan = ref.watch(budgetPlanProvider).value;
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    if (plan == null) return const SizedBox.shrink();
    final c = context.pc;
    final flex = plan.mode == BudgetMode.flex;
    return Column(
      key: const Key('flex_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Plan',
          action: 'Move money',
          onAction: () => openMoveMoney(context, ref, plan, cats, month),
        ),
        MonthSwitcher(
          month: month,
          onChanged: (m) => ref.read(budgetMonthProvider.notifier).set(m),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            Space.md,
          ),
          child: Segmented<BudgetMode>(
            key: const Key('budget_mode'),
            segments: const {
              BudgetMode.flex: 'Flex',
              BudgetMode.category: 'Categories',
            },
            value: plan.mode,
            onChanged: (m) async {
              await ref.read(budgetPlanServiceProvider).setMode(m);
              invalidateBudgetPlan(ref);
            },
          ),
        ),
        if (flex) ...[
          _FlexHero(
            plan,
            autoShare: ref.watch(budgetProvider).value?.autoShare,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              Space.sm,
            ),
            child: Segmented<BudgetGroup>(
              key: const Key('budget_group'),
              segments: {
                for (final g in BudgetGroup.values)
                  g: '${g.label} ${plan.inGroup(g).length}',
              },
              value: _group,
              onChanged: (g) => setState(() => _group = g),
            ),
          ),
          _GroupBody(plan: plan, group: _group, cats: cats, month: month),
        ],
        if (plan.moves.isNotEmpty) ...[
          const SectionHeader('Moved this month'),
          RowGroup(
            key: const Key('moves_list'),
            children: [
              for (final m in plan.moves)
                ListRow(
                  dense: true,
                  title:
                      '${_cat(cats, m.fromId).label} to ${_cat(cats, m.toId).label}',
                  subtitle: aedMinor(m.amountMinor),
                  trailing: TextAction(
                    'Undo',
                    color: c.accent,
                    onTap: () async {
                      await ref.read(budgetPlanServiceProvider).undoMove(m.id);
                      invalidateBudgetPlan(ref);
                    },
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FlexHero extends StatelessWidget {
  const _FlexHero(this.plan, {this.autoShare});
  final BudgetPlanView plan;

  /// Share of this month's payments Pulse captured by itself.
  final double? autoShare;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final f = plan.flex;
    final over = f.remainingMinor < 0;
    return HeroNumber(
      key: const Key('flex_hero'),
      label: over ? 'Flexible overspent' : 'Flexible left',
      value: f.remainingMinor.abs() / 100,
      color: over ? c.negative : null,
      caption: f.categories == 0
          ? 'Set amounts on the categories you spend flexibly'
          : '${aedMinor(f.spentMinor)} spent of ${aedMinor(f.availableMinor)} across ${f.categories} categories',
      footer: f.categories == 0
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: Space.sm),
                Meter(value: f.progress, color: c.forProgress(f.progress)),
                const SizedBox(height: Space.md),
                Row(
                  children: [
                    Dot(c.forProgress(f.progress)),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        PulseColors.statusLabel(f.progress),
                        style: context.tt.bodyMedium!.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (autoShare != null)
                      Text(
                        '${(autoShare! * 100).round()}% automatic',
                        style: context.tt.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _GroupBody extends ConsumerWidget {
  const _GroupBody({
    required this.plan,
    required this.group,
    required this.cats,
    required this.month,
  });
  final BudgetPlanView plan;
  final BudgetGroup group;
  final List<SpendCategory> cats;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final rows = plan.inGroup(group).toList();
    final String note = switch (group) {
      BudgetGroup.fixed =>
        rows.isEmpty
            ? 'Rent, loans and bills at their set amounts.'
            : '${plan.fixed.paidCount} of ${plan.fixed.bills.length} paid · ${aedMinor(plan.fixed.dueMinor)} still to come',
      BudgetGroup.flexible =>
        rows.isEmpty
            ? 'Groceries, dining and the rest share one pool.'
            : 'One pool: overspending one category eats into the others.',
      BudgetGroup.nonMonthly =>
        rows.isEmpty
            ? 'Annual fees, insurance, school terms and trips, saved for a little each month.'
            : '${aedMinor(plan.nonMonthly.contributionMinor)} set aside this month · ${aedMinor(plan.nonMonthly.balanceMinor)} saved so far',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.sm,
          ),
          child: Text(
            note,
            key: const Key('group_note'),
            style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
        if (rows.isNotEmpty)
          RowGroup(
            key: Key('rows_${group.key}'),
            indent: ListRow.leadingInset,
            children: [
              for (final r in rows)
                PlanRowTile(
                  row: r,
                  cat: _cat(cats, r.id),
                  plan: plan,
                  cats: cats,
                  month: month,
                ),
            ],
          ),
      ],
    );
  }
}

/// One category row: what is left, with a cycle glyph and the balance
/// carried in when it rolls over. Tap the red remaining to cover it.
class PlanRowTile extends ConsumerWidget {
  const PlanRowTile({
    super.key,
    required this.row,
    required this.cat,
    required this.plan,
    required this.cats,
    required this.month,
  });
  final PlanRow row;
  final SpendCategory cat;
  final BudgetPlanView plan;
  final List<SpendCategory> cats;
  final DateTime month;

  String _subtitle() {
    final f = row.fund;
    if (f != null) {
      final cycle = f.cycleMonths == 12
          ? 'a year'
          : (f.cycleMonths == 1 ? 'a month' : 'per ${f.cycleMonths} mo');
      return f.costMinor > 0
          ? '${Money.number(f.costMinor / 100)} $cycle · ${Money.number(f.contributionMinor / 100)}/mo'
          : 'Saving ${aedMinor(f.contributionMinor)} a month';
    }
    if (row.group == BudgetGroup.fixed) {
      return switch (FixedBill(
        row.id,
        row.plannedMinor,
        row.spentMinor,
      ).status) {
        BillStatus.paid => 'Paid · ${aedMinor(row.spentMinor)}',
        BillStatus.partial =>
          'Paid ${aedMinor(row.spentMinor)} of ${aedMinor(row.plannedMinor)}',
        BillStatus.over =>
          '${aedMinor(row.spentMinor)} paid, ${aedMinor(row.plannedMinor)} set',
        BillStatus.upcoming => 'Due · ${aedMinor(row.plannedMinor)}',
      };
    }
    final moved = row.movedMinor == 0
        ? ''
        : ' · ${row.movedMinor > 0 ? '+' : '-'}${Money.number(row.movedMinor.abs() / 100)} moved';
    return '${aedMinor(row.spentMinor)} of ${aedMinor(row.plannedMinor)}$moved';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final rem = row.remainingMinor;
    final over = rem < 0;
    final carry = row.carryMinor;
    final rolls = row.config.rolls;
    final remaining = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rolls) ...[
          Icon(
            Icons.autorenew_rounded,
            key: Key('cycle_${row.id}'),
            size: 13,
            color: c.textTertiary,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          over ? '${aedMinor(-rem)} over' : '${aedMinor(rem)} left',
          style: PulseTheme.amount(over ? c.negative : c.textPrimary, size: 15),
        ),
      ],
    );
    return ListRow(
      key: Key('plan_${row.id}'),
      leading: CategoryIcon.well(cat),
      title: cat.label,
      subtitle: _subtitle(),
      onTap: () => showPulseSheet<void>(
        context,
        builder: (_) => CategoryPlanSheet(row: row, cat: cat, month: month),
      ).then((_) => invalidateBudgetPlan(ref)),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          over
              ? Pressable(
                  key: Key('cover_${row.id}'),
                  onTap: () => openMoveMoney(
                    context,
                    ref,
                    plan,
                    cats,
                    month,
                    to: row.id,
                  ),
                  child: remaining,
                )
              : remaining,
          if (rolls && carry != null && carry != 0)
            Text(
              '${carry > 0 ? '+' : '-'}${aedMinor(carry.abs())} carried',
              key: Key('carry_${row.id}'),
              style: context.tt.bodySmall!.copyWith(
                color: carry < 0 ? c.negative : c.textTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Group, rollover and amounts for one category.
class CategoryPlanSheet extends ConsumerStatefulWidget {
  const CategoryPlanSheet({
    super.key,
    required this.row,
    required this.cat,
    required this.month,
  });
  final PlanRow row;
  final SpendCategory cat;
  final DateTime month;
  @override
  ConsumerState<CategoryPlanSheet> createState() => _PlanSheetState();
}

class _PlanSheetState extends ConsumerState<CategoryPlanSheet> {
  late BudgetGroup _group = widget.row.group;
  late bool _rollover = widget.row.config.rollover;
  late int _cycle = widget.row.config.cycleMonths;
  late final _monthly = TextEditingController(
    text: _fmt(
      widget.row.config.cycleCostMinor > 0
          ? 0
          : widget.row.plannedMinor - widget.row.movedMinor,
    ),
  );
  late final _cost = TextEditingController(
    text: _fmt(widget.row.config.cycleCostMinor),
  );

  static String _fmt(int minor) => minor <= 0
      ? ''
      : (minor % 100 == 0
            ? '${minor ~/ 100}'
            : (minor / 100).toStringAsFixed(2));

  @override
  void dispose() {
    _monthly.dispose();
    _cost.dispose();
    super.dispose();
  }

  int _minor(TextEditingController c) {
    final v = double.tryParse(c.text.replaceAll(',', ''));
    return v == null || v <= 0 ? 0 : (v * 100).round();
  }

  Future<void> _save() async {
    final svc = ref.read(budgetPlanServiceProvider);
    final key = monthKeyFor(widget.month);
    final old = widget.row.config;
    final nonMonthly = _group == BudgetGroup.nonMonthly;
    var cfg = old.copyWith(
      group: _group,
      rollover: _rollover,
      cycleMonths: nonMonthly ? _cycle : 1,
      cycleCostMinor: nonMonthly ? _minor(_cost) : 0,
    );
    if ((_rollover || nonMonthly) && cfg.rolloverStart == null)
      cfg = cfg.copyWith(rolloverStart: key);
    await svc.saveCategoryPlan(cfg);
    if (!(nonMonthly && _minor(_cost) > 0))
      await svc.setMonthly(widget.cat.id, widget.month, _minor(_monthly));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final nm = _group == BudgetGroup.nonMonthly;
    final perMonth = nm && _minor(_cost) > 0
        ? spreadMinor(_minor(_cost), _cycle).first
        : null;
    return SheetScaffold(
      title: widget.cat.label,
      subtitle: 'How this category is budgeted.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Segmented<BudgetGroup>(
            key: const Key('plan_group'),
            segments: {for (final g in BudgetGroup.values) g: g.label},
            value: _group,
            onChanged: (g) => setState(() => _group = g),
          ),
          const SizedBox(height: Space.lg),
          if (nm) ...[
            TextField(
              key: const Key('plan_cost'),
              controller: _cost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Total cost',
                prefixText: 'AED  ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              children: [
                for (final m in const [1, 3, 6, 12])
                  Pill(
                    m == 12
                        ? 'Every year'
                        : (m == 1 ? 'Every month' : 'Every $m months'),
                    selected: _cycle == m,
                    onTap: () => setState(() => _cycle = m),
                  ),
              ],
            ),
            if (perMonth != null) ...[
              const SizedBox(height: Space.md),
              Text(
                'Pulse sets aside ${aedMinor(perMonth)} a month, and what you do not spend rolls forward.',
                style: context.tt.bodySmall,
              ),
            ],
          ] else ...[
            TextField(
              key: const Key('plan_monthly'),
              controller: _monthly,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                hintText: 'Amount per month',
                prefixText: 'AED  ',
              ),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Roll over what is left',
                    style: context.tt.bodyLarge,
                  ),
                ),
                Switch(
                  key: const Key('plan_rollover'),
                  value: _rollover,
                  onChanged: (v) => setState(() => _rollover = v),
                ),
              ],
            ),
            Text(
              'Unspent money carries into next month. Overspending carries too, as a negative balance.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: const Key('plan_save'),
            label: 'Save',
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
