import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/flex_budget.dart';
import '../../core/icons/category_tint.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/budget_plan_service.dart' show BudgetPlanView;
import '../../data/models.dart';
import '../../data/providers.dart';
import '../tour/tour_progress.dart';
import 'budget_charts.dart';
import 'cashflow_sankey.dart';

/// The charts on the Budget tab, one at a time in a single compact card.
enum BudgetChart {
  category('category', 'Spend by category', 'Category'),
  trend('trend', 'Month trend', 'Trend'),
  flexFixed('flex', 'Flex vs fixed', 'Flex vs fixed'),
  flow('flow', 'Where the money flows', 'Flow'),
  forecast('forecast', 'Cash-flow forecast', 'Forecast');

  const BudgetChart(this.key, this.title, this.short);
  final String key;
  final String title;
  final String short;

  /// Natural height of the page body at normal text size.
  double get height => switch (this) {
    category => 250,
    trend => 330,
    flexFixed => 250,
    flow => 400,
    forecast => 350,
  };
}

const budgetChartPageKey = 'budget.chart_page';

/// Which chart was open last, remembered on this device (one person per
/// phone, so per user). Falls back to the first chart.
class BudgetChartPageController extends Notifier<({bool loaded, String key})> {
  @override
  ({bool loaded, String key}) build() {
    _load();
    return (loaded: false, key: BudgetChart.category.key);
  }

  Future<void> _load() async {
    var key = BudgetChart.category.key;
    try {
      final v = await ref.read(tourKvProvider).read(budgetChartPageKey);
      if (v != null && BudgetChart.values.any((c) => c.key == v)) key = v;
    } catch (_) {}
    if (ref.mounted) state = (loaded: true, key: key);
  }

  Future<void> set(BudgetChart c) async {
    state = (loaded: true, key: c.key);
    try {
      await ref.read(tourKvProvider).write(budgetChartPageKey, c.key);
    } catch (_) {}
  }
}

final budgetChartPageProvider =
    NotifierProvider<BudgetChartPageController, ({bool loaded, String key})>(
      BudgetChartPageController.new,
    );

/// Swipeable chart card: dots underneath, the last page remembered, no
/// motion when the system asks for reduced motion.
class BudgetChartPager extends ConsumerStatefulWidget {
  const BudgetChartPager(this.o, {super.key});
  final BudgetOverview o;

  @override
  ConsumerState<BudgetChartPager> createState() => _BudgetChartPagerState();
}

class _BudgetChartPagerState extends ConsumerState<BudgetChartPager> {
  final PageController _controller = PageController();
  int _page = 0;

  /// Set once the person swipes or taps, so a late-loading saved page never
  /// moves the chart out from under them.
  bool _touched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<BudgetChart> _pages(BudgetPlanView? plan) => [
    for (final c in BudgetChart.values)
      if (c != BudgetChart.flexFixed || (plan != null && plan.rows.isNotEmpty))
        c,
  ];

  void _go(int i) {
    _touched = true;
    if (!_controller.hasClients) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: Motion.base, curve: Motion.curve);
    }
  }

  /// Opens on the page that was open last, as soon as it has been read.
  void _restore(String key, List<BudgetChart> pages) {
    if (_touched) return;
    final i = pages.indexWhere((p) => p.key == key);
    if (i <= 0 || i == _page) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _touched || !_controller.hasClients) return;
      _controller.jumpToPage(i);
      setState(() => _page = i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final plan = ref.watch(budgetPlanProvider).value;
    final pages = _pages(plan);
    ref.listen(budgetChartPageProvider, (_, next) {
      if (next.loaded) _restore(next.key, pages);
    });
    final saved = ref.read(budgetChartPageProvider);
    if (saved.loaded && !_touched && _page == 0) _restore(saved.key, pages);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final index = _page.clamp(0, pages.length - 1);
    final current = pages[index];
    final height = (current.height - 80) * scale + 80;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md, bottom: Space.lg),
      child: Column(
        key: const Key('chart_pager'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      current.title,
                      key: const Key('chart_title'),
                      style: context.tt.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Text(
                  '${index + 1} / ${pages.length}',
                  style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
                ),
              ],
            ),
          ),
          AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : Motion.base,
            curve: Motion.curve,
            height: height,
            child: PageView(
              key: const Key('chart_pages'),
              controller: _controller,
              onPageChanged: (i) {
                _touched = true;
                setState(() => _page = i);
                ref.read(budgetChartPageProvider.notifier).set(pages[i]);
              },
              children: [
                for (final p in pages)
                  SingleChildScrollView(
                    key: Key('chart_page_${p.key}'),
                    padding: const EdgeInsets.only(top: Space.sm),
                    child: _page_(p),
                  ),
              ],
            ),
          ),
          _Dots(pages: pages, index: index, onTap: _go),
        ],
      ),
    );
  }

  Widget _page_(BudgetChart p) => switch (p) {
    BudgetChart.category => _CategoryDonut(widget.o),
    BudgetChart.trend => const CategoryTrendSection(showHeader: false),
    BudgetChart.flexFixed => const _FlexVsFixed(),
    BudgetChart.flow => const CashflowSankeySection(showHeader: false),
    BudgetChart.forecast => const CashflowSection(showHeader: false),
  };
}

class _Dots extends StatelessWidget {
  const _Dots({required this.pages, required this.index, required this.onTap});
  final List<BudgetChart> pages;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pages.length; i++)
          Semantics(
            button: true,
            selected: i == index,
            label: 'Chart ${i + 1} of ${pages.length}, ${pages[i].title}',
            child: GestureDetector(
              key: Key('chart-dot-${pages[i].key}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              // A 44 point target around a small dot.
              child: SizedBox(
                width: 44,
                height: 36,
                child: Center(
                  child: AnimatedContainer(
                    duration: reduce ? Duration.zero : Motion.fast,
                    width: i == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == index ? c.accent : c.border,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Spent by category as a donut, with the biggest ones listed beside it.
class _CategoryDonut extends StatelessWidget {
  const _CategoryDonut(this.o);
  final BudgetOverview o;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final lines = [
      for (final l in o.lines)
        if (l.spent > 0) l,
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    if (lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Text(
          'No spending yet this month.',
          style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
        ),
      );
    }
    final total = lines.fold<double>(0, (a, l) => a + l.spent);
    final top = lines.take(5).toList();
    final rest = total - top.fold<double>(0, (a, l) => a + l.spent);
    Color tint(SpendCategory cat) =>
        categoryTint(categoryTokenFor(cat.id), dark: c.isDark);
    final slices = [
      for (final l in top)
        ChartSlice(l.category.label, l.spent, tint(l.category)),
      if (rest > 0) ChartSlice('Other', rest, c.textTertiary),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Wrap(
        spacing: Space.lg,
        runSpacing: Space.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Semantics(
            label:
                'Spend by category, ${Money.aed(total, decimals: false)} in total',
            child: DonutChart(
              key: const Key('category_donut'),
              slices: slices,
              size: 132,
              thickness: 16,
              center: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Spent', style: context.tt.labelSmall),
                  Text(
                    Money.aed(total, decimals: false),
                    style: PulseTheme.amount(c.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 260),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final s in slices)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Dot(s.color),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: Text(
                            s.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.tt.bodyMedium,
                          ),
                        ),
                        const SizedBox(width: Space.sm),
                        Text(
                          '${(s.value / total * 100).round()}%',
                          style: context.tt.bodySmall!.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How the plan splits between fixed bills, flexible spending and the
/// non-monthly set-asides: spent against planned, per group.
class _FlexVsFixed extends ConsumerWidget {
  const _FlexVsFixed();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final plan = ref.watch(budgetPlanProvider).value;
    if (plan == null || plan.rows.isEmpty) return const SizedBox.shrink();
    final colors = {
      BudgetGroup.fixed: c.textTertiary,
      BudgetGroup.flexible: c.accent,
      BudgetGroup.nonMonthly: c.warning,
    };
    int spent(BudgetGroup g) =>
        plan.inGroup(g).fold(0, (a, r) => a + r.spentMinor);
    int planned(BudgetGroup g) =>
        plan.inGroup(g).fold(0, (a, r) => a + r.plannedMinor);
    final totalSpent =
        spent(BudgetGroup.fixed) +
        spent(BudgetGroup.flexible) +
        spent(BudgetGroup.nonMonthly);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        key: const Key('flex_vs_fixed'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: 'Share of spending by group',
            child: StackedBar(
              height: 14,
              slices: [
                for (final g in BudgetGroup.values)
                  if (spent(g) > 0)
                    ChartSlice(g.label, spent(g) / 100, colors[g]!),
              ],
            ),
          ),
          const SizedBox(height: Space.md),
          if (totalSpent == 0)
            Text(
              'Nothing spent against the plan yet.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          for (final g in BudgetGroup.values)
            if (plan.inGroup(g).isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.xs),
                child: Row(
                  children: [
                    Dot(colors[g]!),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(g.label, style: context.tt.bodyMedium),
                    ),
                    Flexible(
                      child: Text(
                        '${Money.aed(spent(g) / 100, decimals: false)} of ${Money.aed(planned(g) / 100, decimals: false)}',
                        textAlign: TextAlign.end,
                        style: context.tt.bodySmall!.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
