import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
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
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            ScreenHeader(
              'Wealth',
              subtitle: 'Assets and liabilities',
              trailing: [
                TabTip(
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
              ],
            ),
            if (joint != null)
              ScopeToggle(
                value: scope,
                onChanged: (v) => ref.read(wealthScopeProvider.notifier).set(v),
              ),
            if (showJoint)
              JointNetWorthView(joint)
            else ...[
            if (nw != null) ...[
              HeroNumber(
                label: 'Net worth',
                value: nw.total,
                caption:
                    '${nw.changePct >= 0 ? '+' : ''}${nw.changePct.toStringAsFixed(1)}% this month',
                captionColor: nw.changePct >= 0 ? c.positive : c.negative,
              ),
              const PriceStatusLine(),
              NetWorthHistorySection(
                fallback: nw.labels.length == nw.series.length && nw.series.length > 1
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
                        child: InspectLineChart(
                          labels: [
                            for (final (i, l) in nw.labels.indexed)
                              i.isEven || i == nw.labels.length - 1 ? l : '',
                          ],
                          title: (i) => nw.labels[i],
                          fill: true,
                          height: 140,
                          format: Money.aedCompact,
                          series: [ChartSeries('Net worth', nw.series, c.accent)],
                        ),
                      )
                    : null,
              ),
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
            if (nw != null) _LiveValues(nw),
            ],
          ],
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

class _Body extends ConsumerWidget {
  const _Body(this.list);
  final List<Asset> list;

  /// Allocation colours: one hue family, stepped in lightness, so the bar
  /// reads as proportion rather than a rainbow.
  static Color _shade(PulseColors c, int i, int n) {
    final t = n <= 1 ? 0.0 : i / (n - 1);
    return Color.lerp(c.accent, c.surfaceElevated, t * 0.85)!;
  }

  /// The note, plus how the row is shared when there is a household.
  static String? _subtitle(JointData? j, Asset a) {
    final share = j == null ? null : lineCaption(j, a.id);
    final parts = [if (a.note.isNotEmpty) a.note, ?share];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final joint = ref.watch(jointDataProvider).value;
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
    final liabilities = sum(AssetKind.liability);
    TextStyle num([Color? col]) => PulseTheme.amount(col ?? c.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AssetsVsLiabilities(list),
        const SectionHeader('Allocation'),
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
                size: 176,
                thickness: 20,
                slices: [
                  for (var i = 0; i < kinds.length; i++)
                    ChartSlice(
                      kinds[i].label,
                      sum(kinds[i]),
                      _shade(c, i, kinds.length),
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
        RowGroup(
          children: [
            for (var i = 0; i < kinds.length; i++)
              ListRow(
                dense: true,
                leading: Dot(_shade(c, i, kinds.length), size: 10),
                title: kinds[i].label,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalAssets > 0 ? '${(sum(kinds[i]) / totalAssets * 100).round()}%' : '0%',
                      style: num(c.textSecondary),
                    ),
                    const SizedBox(width: Space.lg),
                    SizedBox(
                      width: 104,
                      child: Text(
                        Money.aedCompact(sum(kinds[i])),
                        style: num(),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const WealthSections(),
        for (final k in [
          ...kinds,
          if (byKind.containsKey(AssetKind.liability)) AssetKind.liability,
        ]) ...[
          if (byKind[k]!.any((a) => !_inSections(a))) SectionHeader(k.label),
          RowGroup(
            children: [
              for (final a in byKind[k]!.where((a) => !_inSections(a)))
                _swipeToDelete(
                  context,
                  ref,
                  a,
                  ListRow(
                    key: Key('asset_${a.id}'),
                    title: a.name,
                    subtitle: _subtitle(joint, a),
                    onTap: a.editable
                        ? () => showEditAssetSheet(
                            context,
                            a,
                            onOwnership: joint == null
                                ? null
                                : () => showOwnershipSheet(context, table: 'lines', id: a.id, title: a.name),
                          )
                        : (joint == null
                              ? null
                              : () => showOwnershipSheet(context, table: 'lines', id: a.id, title: a.name)),
                    trailing: Text(
                      Money.aed(
                        a.isLiability ? -a.value : a.value,
                        decimals: false,
                      ),
                      style: num(),
                    ),
                  ),
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.lg,
            Space.gutter,
            0,
          ),
          child: Text(
            'Assets ${Money.aed(totalAssets, decimals: false)} · '
            'Liabilities ${Money.aed(liabilities, decimals: false)}',
            style: context.tt.bodySmall,
          ),
        ),
      ],
    );
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
Widget _swipeToDelete(BuildContext context, WidgetRef ref, Asset a, Widget row) {
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
