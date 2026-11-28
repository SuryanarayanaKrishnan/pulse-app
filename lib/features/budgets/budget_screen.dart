import '../../core/utils/app_clock.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/budget_plan_service.dart' show PlanRow;
import '../../data/models.dart';
import '../../data/providers.dart';
import 'export_action.dart';
import '../discover/feature_shortcuts.dart';
import '../household/joint_views.dart';
import '../../core/household/household_engine.dart' show NwScope;
import '../../household/household_providers.dart';
import '../../data/local/budget_plan_store.dart' show BudgetMode;
import 'budget_chart_pager.dart';
import 'flex_budget_section.dart';
import 'overrun_section.dart';
import '../tour/tab_tip.dart';
import '../tour/tour_progress.dart';
import '../coach/coach.dart';

/// Budget: spent against plan, by category, and where it went.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetProvider);
    final joint = ref.watch(jointDataProvider).value;
    final scope = ref.watch(budgetScopeProvider);
    final showJoint = joint != null && scope == NwScope.joint;
    return CoachHost(
      screen: CoachScreen.budget,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                showSettings: true,
                'Budget',
                subtitle: DateFormat('MMMM y').format(AppClock.now()),
                trailing: [
                  RoundIconButton(
                    icon: Icons.receipt_long_outlined,
                    label: 'Activity',
                    onTap: () => context.push(Routes.activity),
                  ),
                ],
              ),
              if (joint != null)
                ScopeToggle(
                  value: scope,
                  onChanged: (v) =>
                      ref.read(budgetScopeProvider.notifier).set(v),
                ),
              if (showJoint)
                JointBudgetView(joint)
              else
                AsyncView<BudgetOverview>(
                  value: b,
                  onRetry: () => ref.invalidate(budgetProvider),
                  loading: const SkeletonList(rows: 4, height: 96),
                  builder: (o) => (o.planned == 0 && o.spent == 0)
                      ? EmptyState(
                          icon: Icons.donut_small_outlined,
                          title: 'No spending or budget yet',
                          message:
                              'Once card alerts arrive, or you add a payment by '
                              'hand, spending shows up here. Set a monthly budget '
                              'to see how much is left.',
                          action: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PrimaryButton(
                                key: const Key('budget_build'),
                                label: 'Build my budget',
                                icon: Icons.auto_awesome_outlined,
                                expand: false,
                                onPressed: () =>
                                    context.push(Routes.budgetSetup),
                              ),
                              const SizedBox(height: Space.sm),
                              PrimaryButton(
                                key: const Key('budget_import'),
                                label: 'Import my sheet',
                                icon: Icons.upload_file_outlined,
                                secondary: true,
                                expand: false,
                                onPressed: () =>
                                    context.push(Routes.budgetImport),
                              ),
                            ],
                          ),
                        )
                      : _Body(o),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.o);
  final BudgetOverview o;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final rules = ref.watch(rulesProvider).value;
    final statements = ref.watch(statementsProvider).value;
    final attention = statements?.where((s) => s.needsAttention).length ?? 0;
    final lines = [...o.lines.where((l) => l.planned > 0 || l.spent > 0)]
      ..sort((a, b) {
        // Most urgent first: over budget, then closest to the limit.
        final pa = a.planned == 0 ? 2.0 : a.progress;
        final pb = b.planned == 0 ? 2.0 : b.progress;
        return pb.compareTo(pa);
      });
    final autoPct = (o.autoShare * 100).round();
    final plan = ref.watch(budgetPlanProvider).value;
    final flex = plan != null && plan.mode == BudgetMode.flex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const TabTip(
          tab: TipTab.budget,
          child: FeatureShortcuts(ids: ['recurring', 'household']),
        ),
        if (!flex)
          CoachTarget(
            id: 'hero',
            child: HeroNumber(
              label: 'Spent this month',
              value: o.spent,
              caption: o.planned == 0
                  ? 'No budget set yet · ${o.daysLeft} days left'
                  : 'of ${Money.aed(o.planned, decimals: false)} · ${o.daysLeft} days left',
              // Without a budget there is nothing to be on track or over against.
              footer: o.planned == 0
                  ? Padding(
                      padding: const EdgeInsets.only(top: Space.md),
                      child: Text(
                        'Set an amount on a category to see how much is left.',
                        style: context.tt.bodyMedium!.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Meter(
                          value: o.progress,
                          color: c.forProgress(o.progress),
                        ),
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            Dot(c.forProgress(o.progress)),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                '${PulseColors.statusLabel(o.progress)} · ${Money.aed(o.remaining.abs(), decimals: false)} ${o.remaining < 0 ? 'over' : 'left'}',
                                style: context.tt.bodyMedium!.copyWith(
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '$autoPct% automatic',
                              style: context.tt.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        // Flex mode has no big hero above, so the key numbers stay on top as a
        // compact strip; the charts come next, then the plan itself.
        if (flex) _KeyNumbers(o),
        BudgetChartPager(o),
        flex
            ? const CoachTarget(id: 'hero', child: FlexBudgetSection())
            : const FlexBudgetSection(),
        if (o.planned > 0) const OverrunSection(),
        if (!flex) ...[
          SectionHeader(
            'Categories',
            action: 'Edit',
            onAction: () => context.push(Routes.categories),
          ),
          const SizedBox(height: Space.sm),
        ],
        CoachTarget(
          id: 'categories',
          child: flex
              ? const SizedBox.shrink()
              : SnapRail(
                  // Grows with large text so the tile never clips.
                  height: MediaQuery.textScalerOf(context).scale(128) + 24,
                  itemCount: lines.length,
                  itemBuilder: (context, i) =>
                      _CategoryTile(lines[i], plan?.row(lines[i].category.id)),
                ),
        ),
        _WhereItWent(o),
        const SectionHeader('Manage'),
        CoachTarget(
          id: 'manage',
          child: _ManageGroup(
            // With no budget yet, building or importing one is the whole point.
            initiallyOpen: o.planned == 0,
            primary: [
              SummaryTile.link(
                icon: Icons.category_outlined,
                label: 'Categories & budgets',
                caption: '${lines.length} categories',
                onTap: () => context.push(Routes.categories),
              ),
              SummaryTile.link(
                key: const Key('manage_recurring'),
                icon: Icons.event_repeat_rounded,
                label: 'Recurring',
                caption: 'Bills and subscriptions',
                onTap: () => context.push(Routes.recurring),
              ),
              SummaryTile.link(
                key: const Key('manage_reports'),
                icon: Icons.grid_view_rounded,
                label: 'Reports',
                caption: 'Where the month went',
                onTap: () => context.push(Routes.reports),
              ),
              SummaryTile.link(
                icon: Icons.fact_check_outlined,
                label: 'Monthly close',
                caption: statements == null
                    ? null
                    : (attention == 0
                          ? 'All statements match'
                          : '$attention need you'),
                captionColor: attention == 0 ? null : c.warning,
                onTap: () => context.push(Routes.statements),
              ),
            ],
            more: [
              SummaryTile.link(
                key: const Key('manage_build'),
                icon: Icons.auto_awesome_outlined,
                label: 'Build my budget',
                caption: 'From a few answers',
                onTap: () => context.push(Routes.budgetSetup),
              ),
              SummaryTile.link(
                key: const Key('manage_import'),
                icon: Icons.upload_file_outlined,
                label: 'Import my sheet',
                caption: 'Excel, Sheets or CSV',
                onTap: () => context.push(Routes.budgetImport),
              ),
              SummaryTile.link(
                key: const Key('manage_export'),
                icon: Icons.ios_share_rounded,
                label: 'Export to Excel',
                caption: 'Budget and every payment',
                onTap: () => exportSpreadsheet(context, ref, ExportFormat.xlsx),
              ),
              SummaryTile.link(
                key: const Key('manage_export_csv'),
                icon: Icons.table_chart_outlined,
                label: 'Export as CSV',
                caption: 'For Google Sheets',
                onTap: () => exportSpreadsheet(context, ref, ExportFormat.csv),
              ),
              SummaryTile.link(
                icon: Icons.auto_mode_rounded,
                label: 'Automations',
                caption: rules == null
                    ? null
                    : '${rules.length} ${rules.length == 1 ? 'rule' : 'rules'}',
                onTap: () => context.push(Routes.automations),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Spent, left and days left: the numbers that matter, always above the charts.
class _KeyNumbers extends StatelessWidget {
  const _KeyNumbers(this.o);
  final BudgetOverview o;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final noBudget = o.planned == 0;
    Widget stat(String label, String value, {Color? color}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.tt.labelMedium!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: PulseTheme.amount(color ?? c.textPrimary),
            ),
          ),
        ],
      ),
    );
    return Padding(
      key: const Key('budget_key_numbers'),
      padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          stat('Spent', Money.aed(o.spent, decimals: false)),
          const SizedBox(width: Space.md),
          stat(
            o.remaining < 0 ? 'Over' : 'Left',
            noBudget
                ? 'No budget'
                : Money.aed(o.remaining.abs(), decimals: false),
            color: o.remaining < 0 ? c.negative : null,
          ),
          const SizedBox(width: Space.md),
          stat('Days left', '${o.daysLeft}'),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.l, [this.plan]);
  final BudgetLine l;

  /// The category's flex row, for the rollover balance.
  final PlanRow? plan;
  String _carry() {
    final k = plan?.carryMinor;
    if (k == null || k == 0) return '';
    return ' (${k > 0 ? '+' : '-'}${Money.number(k.abs() / 100)})';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final noBudget = l.planned == 0;
    final status = noBudget
        ? c.textTertiary
        : (l.progress > 1
              ? c.negative
              : (l.progress >= 0.9 ? c.warning : c.textSecondary));
    return SurfaceCard(
      padding: const EdgeInsets.all(Space.md),
      onTap: () => context.push('${Routes.activity}?category=${l.category.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(l.category, size: 22),
              if (plan?.config.rolls ?? false) ...[
                const SizedBox(width: 6),
                Icon(Icons.autorenew_rounded, size: 13, color: c.textTertiary),
              ],
              const Spacer(),
              if (!noBudget)
                ProgressRing(progress: l.progress, size: 20, stroke: 3),
            ],
          ),
          const Spacer(),
          Text(
            l.category.label,
            style: context.tt.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            Money.aed(l.spent, decimals: false),
            style: PulseTheme.amount(c.textPrimary),
          ),
          Text(
            noBudget
                ? 'No budget'
                : (l.progress > 1
                      ? '${Money.number(l.spent - l.planned)} over'
                      : 'of ${Money.number(l.planned)}${_carry()}'),
            style: context.tt.bodySmall!.copyWith(color: status),
            maxLines: 1,
          ),
        ],
      ),
    );
  }
}

enum _By { merchants, cards, accounts }

class _WhereItWent extends StatefulWidget {
  const _WhereItWent(this.o);
  final BudgetOverview o;
  @override
  State<_WhereItWent> createState() => _WhereItWentState();
}

class _WhereItWentState extends State<_WhereItWent> {
  _By _by = _By.merchants;

  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final c = context.pc;
    final rows = switch (_by) {
      _By.merchants => [
        for (final m in o.topMerchants)
          (
            m.merchant,
            '${m.count} ${m.count == 1 ? 'payment' : 'payments'}',
            m.total,
            CategoryIcon.well(m.category),
          ),
      ],
      _By.cards => _entries(
        o.byCard,
        const IconWell(Icons.credit_card_outlined),
      ),
      _By.accounts => _entries(
        o.byAccount,
        const IconWell(Icons.account_balance_outlined),
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Where it went'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.md,
            Space.gutter,
            Space.xs,
          ),
          child: Segmented<_By>(
            segments: const {
              _By.merchants: 'Merchants',
              _By.cards: 'Cards',
              _By.accounts: 'Accounts',
            },
            value: _by,
            onChanged: (v) => setState(() => _by = v),
          ),
        ),
        PulseSwitcher(
          child: RowGroup(
            key: ValueKey(_by),
            indent: ListRow.leadingInset,
            children: [
              for (final r in rows)
                ListRow(
                  leading: r.$4,
                  title: r.$1,
                  subtitle: r.$2,
                  trailing: Text(
                    Money.aed(r.$3, decimals: false),
                    style: PulseTheme.amount(c.textPrimary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<(String, String?, double, Widget)> _entries(
    Map<String, double> m,
    Widget icon,
  ) {
    final total = m.values.fold(0.0, (a, b) => a + b);
    final e = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final x in e)
        (
          x.key,
          total == 0 ? null : '${(x.value / total * 100).round()}% of spend',
          x.value,
          icon,
        ),
    ];
  }
}

/// The tools under Budget, as tiles. The few used most are always there; the
/// rest sit behind "More tools" so the tab is not a long menu.
class _ManageGroup extends StatefulWidget {
  const _ManageGroup({
    required this.primary,
    required this.more,
    this.initiallyOpen = false,
  });
  final bool initiallyOpen;
  final List<Widget> primary;
  final List<Widget> more;
  @override
  State<_ManageGroup> createState() => _ManageGroupState();
}

class _ManageGroupState extends State<_ManageGroup> {
  late var _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) => SummaryGrid(
    tiles: [
      ...widget.primary,
      if (_open) ...widget.more,
      SummaryTile.link(
        key: const Key('manage_more'),
        icon: _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        label: _open ? 'Fewer tools' : 'More tools',
        caption: _open ? null : 'Build, import, export, rules',
        onTap: () => setState(() => _open = !_open),
      ),
    ],
  );
}
