import '../wealth/wealth_icons.dart';
import '../discover/feature_shortcuts.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../core/engine/valuation.dart' show FundValue;
import '../../data/goal_models.dart' show GoalView;
import '../../data/investing_service.dart' show StockView;
import '../../data/models.dart';
import '../../data/wealth_service.dart' show FundView;
import '../../data/providers.dart';
import '../../core/household/household_engine.dart' show NwScope;
import '../../household/household_providers.dart';
import '../goals/goals_screen.dart' show GoalsSection;
import 'net_worth_history.dart';
import '../../data/household_service.dart' show JointData;
import '../household/household_common.dart';
import '../household/joint_views.dart';
import '../household/ownership_widgets.dart';
import '../wallet/add_sheets.dart';
import '../wealth/investing_screens.dart';
import '../wealth/wealth_sections.dart';
import '../tour/tab_tip.dart';
import '../tour/tour_progress.dart';
import '../coach/coach.dart';

/// "12 min ago", "3 h ago", "6 days ago".
String ago(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  final days = d.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}

class WealthScreen extends ConsumerWidget {
  const WealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final assets = ref.watch(assetsProvider);
    final nw = ref.watch(netWorthProvider).value;
    final joint = ref.watch(jointDataProvider).value;
    final scope = ref.watch(wealthScopeProvider);
    final showJoint = joint != null && scope == NwScope.joint;
    return CoachHost(
      screen: CoachScreen.wealth,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              ScreenHeader(
                showSettings: true,
                'Wealth',
                subtitle: 'Assets and liabilities',
                trailing: [
                  CoachTarget(
                    id: 'add',
                    child: TabTip(
                      tab: TipTab.wealth,
                      child: RoundIconButton(
                        icon: Icons.add_rounded,
                        label: 'Add an asset or loan',
                        onTap: () => showWealthAddMenu(
                          context,
                          assetSheet: (_) => const AddAssetSheet(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const FeatureShortcuts(ids: ['household']),
              if (joint != null)
                ScopeToggle(
                  value: scope,
                  onChanged: (v) =>
                      ref.read(wealthScopeProvider.notifier).set(v),
                ),
              if (showJoint)
                JointNetWorthView(joint)
              else ...[
                if (nw != null) ...[
                  CoachTarget(
                    id: 'hero',
                    child: HeroNumber(
                      label: 'Net worth',
                      value: nw.total,
                      caption:
                          '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month',
                      captionColor: nw.changePct >= 0 ? c.positive : c.negative,
                    ),
                  ),
                  const PriceStatusLine(),
                ],
                AsyncView<List<Asset>>(
                  value: assets,
                  loading: const SkeletonList(rows: 4),
                  onRetry: () => ref.invalidate(assetsProvider),
                  builder: (list) => list.isEmpty
                      ? Column(
                          children: [
                            EmptyState(
                              icon: Icons.account_balance_wallet_outlined,
                              title: 'Nothing here yet',
                              message:
                                  'Add what you own and owe: accounts, property, gold, '
                                  'deposits, loans. Net worth is worked out on this phone.',
                              action: PrimaryButton(
                                label: 'Add to Wealth',
                                expand: false,
                                onPressed: () => showWealthAddMenu(
                                  context,
                                  assetSheet: (_) => const AddAssetSheet(),
                                ),
                              ),
                            ),
                            const WealthSections(),
                          ],
                        )
                      : _Body(list),
                ),
                if (nw != null) ...[
                  NetWorthHistorySection(
                    fallback:
                        nw.labels.length == nw.series.length &&
                            nw.series.length > 1
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(
                              Space.gutter,
                              Space.xl,
                              Space.gutter,
                              0,
                            ),
                            child: InspectLineChart(
                              labels: [
                                for (final (i, l) in nw.labels.indexed)
                                  i.isEven || i == nw.labels.length - 1
                                      ? l
                                      : '',
                              ],
                              title: (i) => nw.labels[i],
                              fill: true,
                              height: 140,
                              format: Money.aedCompact,
                              series: [
                                ChartSeries('Net worth', nw.series, c.accent),
                              ],
                            ),
                          )
                        : null,
                  ),
                ],
                if (nw != null) _LiveValues(nw),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Jewellery and funds have their own sections with photos, gain and detail
/// pages, so the plain per-kind list leaves them out (they still count in the
/// allocation and the totals).
bool _inSections(Asset a) =>
    a.id.startsWith('jewel:') ||
    a.id.startsWith('fund:') ||
    a.id.startsWith('stock:');

/// Upcoming dates, jewellery, funds and documents.
class WealthSections extends StatelessWidget {
  const WealthSections({super.key});
  @override
  Widget build(BuildContext context) => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      GoalsSection(),
      UpcomingSection(),
      JewellerySection(),
      FundsSection(),
      InvestmentsSection(),
      InvestingPlanSection(),
      DocumentsSection(),
    ],
  );
}

/// Wealth overview: how the money is split, then a grid of tiles. Each tile
/// is one thing you own with its value and how it moved; tap it for the list.
class _Body extends ConsumerWidget {
  const _Body(this.list);
  final List<Asset> list;

  /// Allocation colours: one hue family, stepped in lightness, so the chart
  /// reads as proportion rather than a rainbow.
  static Color _shade(PulseColors c, int i, int n) {
    final t = n <= 1 ? 0.0 : i / (n - 1);
    return Color.lerp(c.accent, c.surfaceElevated, t * 0.85)!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final byKind = <AssetKind, List<Asset>>{};
    for (final a in list) {
      byKind.putIfAbsent(a.kind, () => []).add(a);
    }
    double sum(AssetKind k) =>
        (byKind[k] ?? []).fold(0.0, (a, e) => a + e.value);
    final kinds =
        AssetKind.values
            .where((k) => k != AssetKind.liability && byKind.containsKey(k))
            .toList()
          ..sort((a, b) => sum(b).compareTo(sum(a)));
    final totalAssets = kinds.fold(0.0, (a, k) => a + sum(k));
    final allocated = [
      for (final k in kinds)
        if (sum(k) > 0) k,
    ];

    // Gain per kind, from the views that know what was paid.
    final gold = ref.watch(jewelleryProvider).value ?? const [];
    final goldPaid = gold.every((v) => v.item.purchasePriceMinor != null)
        ? gold.fold<int>(0, (a, v) => a + v.item.purchasePriceMinor!)
        : 0;
    final goldNow = gold.fold<int>(0, (a, v) => a + v.value.valueMinor);
    final double? goldGain = gold.isEmpty || goldPaid <= 0
        ? null
        : (goldNow - goldPaid) / goldPaid * 100;
    double? fundGain(Iterable<FundValue> vs) {
      var cost = 0, gain = 0;
      for (final v in vs) {
        final cst = v.costAedMinor, g = v.gainAedMinor;
        if (cst == null || g == null || cst <= 0) continue;
        cost += cst;
        gain += g;
      }
      return cost <= 0 ? null : gain / cost * 100;
    }

    final fundsGain = fundGain([
      for (final v in ref.watch(fundsProvider).value ?? const <FundView>[])
        v.value,
    ]);
    final stocksGain = fundGain([
      for (final v
          in ref.watch(stockViewsProvider).value ?? const <StockView>[])
        v.value,
    ]);
    final goals = (ref.watch(goalsProvider).value ?? const <GoalView>[])
        .where((g) => !g.state.done)
        .length;
    final docs = (ref.watch(documentsProvider).value ?? const []).length;
    final rules = (ref.watch(ruleViewsProvider).value ?? const []).length;

    double? gainFor(AssetKind k) => switch (k) {
      AssetKind.gold => goldGain,
      AssetKind.funds => fundsGain,
      AssetKind.stocks => stocksGain,
      _ => null,
    };
    String countOf(AssetKind k) {
      final n = byKind[k]!.length;
      return '$n ${n == 1 ? 'item' : 'items'}';
    }

    void open(String id) => context.push('${Routes.wealthSection}/$id');
    final owned = [
      ...kinds,
      if (byKind.containsKey(AssetKind.liability)) AssetKind.liability,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('What you own'),
        SummaryGrid(
          key: const Key('wealth-grid'),
          tiles: [
            for (final k in owned)
              SummaryTile(
                key: Key('wealth-tile-${k.name}'),
                icon: k.icon,
                label: k.label,
                value: Money.aedCompact(sum(k)),
                caption: totalAssets > 0 && k != AssetKind.liability
                    ? '${(sum(k) / totalAssets * 100).round()}% of assets'
                    : countOf(k),
                deltaPct: gainFor(k),
                onTap: () => open(k.name),
              ),
          ],
        ),
        AssetsVsLiabilities(list),
        const SectionHeader('Allocation'),
        if (allocated.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.lg,
            ),
            child: Center(
              child: Semantics(
                label:
                    'Allocation of ${Money.aed(totalAssets, decimals: false)} in assets',
                child: DonutChart(
                  size: 160,
                  thickness: 18,
                  slices: [
                    for (var i = 0; i < allocated.length; i++)
                      ChartSlice(
                        allocated[i].label,
                        sum(allocated[i]),
                        _shade(c, i, allocated.length),
                      ),
                  ],
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Assets', style: context.tt.bodySmall),
                      Text(
                        Money.aedCompact(totalAssets),
                        style: PulseTheme.amount(c.textPrimary, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.lg,
              Space.gutter,
              Space.lg,
            ),
            child: Text(
              'Add an asset or an account balance to see how your money is split.',
              style: context.tt.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        const SectionHeader('Plans and papers'),
        SummaryGrid(
          key: const Key('wealth-grid-plans'),
          tiles: [
            SummaryTile(
              key: const Key('wealth-tile-goals'),
              icon: Icons.flag_outlined,
              label: 'Goals',
              value: '$goals',
              caption: goals == 0 ? 'Set a goal' : 'in progress',
              onTap: () => open('goals'),
            ),
            SummaryTile(
              key: const Key('wealth-tile-plan'),
              icon: Icons.autorenew_rounded,
              label: 'Investing plan',
              value: '$rules',
              caption: rules == 0 ? 'Add a rule' : 'rules',
              onTap: () => open('plan'),
            ),
            SummaryTile(
              key: const Key('wealth-tile-papers'),
              icon: Icons.description_outlined,
              label: 'Papers',
              value: '$docs',
              caption: docs == 0 ? 'Add a document' : 'documents',
              onTap: () => open('papers'),
            ),
          ],
        ),
      ],
    );
  }
}

/// The page behind a Wealth tile: everything in one kind of holding.
class WealthSectionScreen extends ConsumerWidget {
  const WealthSectionScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = switch (id) {
      'goals' => ('Goals', const <Widget>[GoalsSection()]),
      'plan' => ('Investing plan', const <Widget>[InvestingPlanSection()]),
      'papers' => (
        'Papers',
        const <Widget>[UpcomingSection(), DocumentsSection()],
      ),
      _ => null,
    };
    final kind = AssetKind.values.where((k) => k.name == id).firstOrNull;
    final title = plan?.$1 ?? kind?.label ?? 'Wealth';
    final joint = ref.watch(jointDataProvider).value;
    final assets = (ref.watch(assetsProvider).value ?? const <Asset>[])
        .where((a) => a.kind == kind && !_inSections(a))
        .toList();
    final top = switch (kind) {
      AssetKind.gold => const <Widget>[JewellerySection()],
      AssetKind.funds => const <Widget>[FundsSection()],
      AssetKind.stocks => const <Widget>[InvestmentsSection()],
      _ => const <Widget>[],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(Routes.wealth),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxxl),
        children: [
          ...?plan?.$2,
          ...top,
          if (assets.isNotEmpty) ...[
            if (top.isNotEmpty) SectionHeader('Other ${title.toLowerCase()}'),
            RowGroup(
              children: [
                for (final a in assets)
                  _swipeToDelete(
                    context,
                    ref,
                    a,
                    ListRow(
                      key: Key('asset_${a.id}'),
                      leading: WealthIcon(
                        WealthKind.forAsset(a.kind),
                        size: 36,
                      ),
                      title: a.name,
                      subtitle: _subtitle(joint, a),
                      onTap: a.editable
                          ? () => showEditAssetSheet(
                              context,
                              a,
                              onOwnership: joint == null
                                  ? null
                                  : () => showOwnershipSheet(
                                      context,
                                      table: 'lines',
                                      id: a.id,
                                      title: a.name,
                                    ),
                            )
                          : (joint == null
                                ? null
                                : () => showOwnershipSheet(
                                    context,
                                    table: 'lines',
                                    id: a.id,
                                    title: a.name,
                                  )),
                      trailing: Text(
                        Money.aed(
                          a.isLiability ? -a.value : a.value,
                          decimals: false,
                        ),
                        style: PulseTheme.amount(context.pc.textPrimary),
                      ),
                    ),
                  ),
              ],
            ),
          ] else if (plan == null && top.isEmpty)
            const EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Nothing here yet',
              message: 'Add one from the plus on Wealth.',
            ),
        ],
      ),
    );
  }

  /// The note, plus how the row is shared when there is a household.
  static String? _subtitle(JointData? j, Asset a) {
    final share = j == null ? null : lineCaption(j, a.id);
    final parts = [if (a.note.isNotEmpty) a.note, ?share];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// The prices Pulse values things with.
class _LiveValues extends StatelessWidget {
  const _LiveValues(this.nw);
  final NetWorth nw;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    if (nw.prices.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Live values'),
        RowGroup(
          children: [
            for (final p in nw.prices)
              ListRow(
                dense: true,
                title: p.name,
                subtitle: '${p.source} · ${ago(p.updatedAt)}',
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      p.value,
                      style: PulseTheme.amount(c.textPrimary, size: 15),
                    ),
                    if (p.changePct != 0)
                      Text(
                        '${p.changePct > 0 ? '+' : '−'}${p.changePct.abs().toStringAsFixed(1)}%',
                        style: context.tt.bodySmall!.copyWith(
                          color: p.changePct > 0 ? c.positive : c.negative,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Text(
            'Gold, property and foreign holdings revalue themselves as these move.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Swipe left to delete a row the user typed in; priced holdings and cards
/// are managed on their own screens and do not swipe.
Widget _swipeToDelete(
  BuildContext context,
  WidgetRef ref,
  Asset a,
  Widget row,
) {
  if (!a.editable) return row;
  final c = context.pc;
  return Dismissible(
    key: Key('swipe_${a.id}'),
    direction: DismissDirection.endToStart,
    background: Container(
      color: c.negative,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: Space.gutter),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
    ),
    confirmDismiss: (_) => confirmDeleteAsset(context, ref, a),
    child: row,
  );
}
