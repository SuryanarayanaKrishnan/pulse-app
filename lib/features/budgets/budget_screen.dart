import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../household/joint_views.dart';
import '../../core/household/household_engine.dart' show NwScope;
import '../../household/household_providers.dart';
import 'budget_charts.dart';
import '../tour/tab_tip.dart';
import '../tour/tour_progress.dart';

/// Budget: spent against plan, by category, and where it went.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(budgetProvider);
    final joint = ref.watch(jointDataProvider).value;
    final scope = ref.watch(budgetScopeProvider);
    final showJoint = joint != null && scope == NwScope.joint;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Budget',
              subtitle: DateFormat('MMMM y').format(DateTime.now()),
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
                onChanged: (v) => ref.read(budgetScopeProvider.notifier).set(v),
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
                        action: PrimaryButton(
                          label: 'Set a budget',
                          expand: false,
                          onPressed: () => context.push(Routes.categories),
                        ),
                      )
                    : _Body(o),
              ),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroNumber(
          label: 'Spent this month',
          value: o.spent,
          caption:
              'of ${Money.aed(o.planned, decimals: false)} · ${o.daysLeft} days left',
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Meter(value: o.progress, color: c.forProgress(o.progress)),
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
                  Text('$autoPct% automatic', style: context.tt.bodySmall),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          'Categories',
          action: 'Edit',
          onAction: () => context.push(Routes.categories),
        ),
        const SizedBox(height: Space.sm),
        TabTip(
          tab: TipTab.budget,
          child: SnapRail(
            height: 128,
            itemCount: lines.length,
            itemBuilder: (context, i) => _CategoryTile(lines[i]),
          ),
        ),
        const CashflowSection(),
        const CategoryTrendSection(),
        _WhereItWent(o),
        const SectionHeader('Manage'),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [
            ListRow(
              leading: const IconWell(Icons.category_outlined),
              title: 'Categories & budgets',
              chevron: true,
              onTap: () => context.push(Routes.categories),
            ),
            ListRow(
              leading: const IconWell(Icons.auto_mode_rounded),
              title: 'Automations',
              subtitle: rules == null
                  ? null
                  : '${rules.length} ${rules.length == 1 ? 'rule' : 'rules'}',
              chevron: true,
              onTap: () => context.push(Routes.automations),
            ),
            ListRow(
              leading: const IconWell(Icons.fact_check_outlined),
              title: 'Monthly close',
              subtitle: statements == null
                  ? null
                  : (attention == 0
                        ? 'All statements match'
                        : '$attention need you'),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(this.l);
  final BudgetLine l;
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
                      : 'of ${Money.number(l.planned)}'),
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
        AnimatedSwitcher(
          duration: Motion.base,
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
