import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/spend_report.dart';
import '../../core/household/household_engine.dart' as hh;
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/recurring_providers.dart';
import '../../household/household_providers.dart';
import 'treemap_view.dart';

enum ReportView { category, member }

class _ViewNotifier extends Notifier<ReportView> {
  @override
  ReportView build() => ReportView.category;
  void set(ReportView v) => state = v;
}

final reportViewProvider = NotifierProvider<_ViewNotifier, ReportView>(
  _ViewNotifier.new,
);

/// Reports: where the money went, as a treemap you can tap into. By category
/// always; by member when you are in a household. Month or a longer range.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String? _selected;
  String? _reported;

  void _report(ReportView v) {
    if (_reported == v.name) return;
    _reported = v.name;
    // After the frame: the screen is built, then this is noted once a view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ref.read(analyticsProvider).track(AnalyticsEvent.reportViewed(v.name));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final joint = ref.watch(jointDataProvider).value;
    final requested = ref.watch(reportViewProvider);
    final view = joint == null ? ReportView.category : requested;
    _report(view);
    final span = ref.watch(reportSpanProvider);
    final end = ref.watch(reportEndProvider);
    final today = ref.watch(recurringTodayProvider);
    final range = span == ReportSpan.month
        ? ReportRange.month(end)
        : ReportRange.lastMonths(end, span.months);
    final rows = ref.watch(spendRowsProvider);
    final cats = ref.watch(categoriesProvider).value ?? SpendCategory.defaults;
    String catLabel(String id) =>
        cats.where((x) => x.id == id).firstOrNull?.label ??
        SpendCategory.byId(id)?.label ??
        'Other';

    List<SpendSlice> slices = const [];
    List<SpendSlice> before = const [];
    String Function(String) labelOf = catLabel;
    if (view == ReportView.category) {
      final all = rows.value ?? const <SpendRow>[];
      slices = spendByCategory(all, range);
      before = spendByCategory(all, range.previous);
    } else if (joint != null) {
      DateTime utc(CalDate d) => DateTime.utc(d.year, d.month, d.day);
      List<SpendSlice> memberSlices(ReportRange r) => [
        for (final m in hh.spendByMember(
          joint.txs,
          from: utc(r.start),
          to: utc(r.end).add(const Duration(days: 1)),
          me: joint.me,
          shareMine: joint.shareMine,
        ))
          SpendSlice(m.owner, m.spentMinor, m.count),
      ];
      slices = memberSlices(range);
      before = memberSlices(range.previous);
      labelOf = joint.nameOf;
    }
    final shown = view == ReportView.category ? foldSmall(slices) : slices;
    final total = slices.fold(0, (a, s) => a + s.totalMinor);
    final prevTotal = before.fold(0, (a, s) => a + s.totalMinor);
    final sel = shown.where((s) => s.id == _selected).firstOrNull;
    final label = switch (span) {
      ReportSpan.month => DateFormat(
        'MMMM y',
      ).format(DateTime(end.year, end.month)),
      _ =>
        '${DateFormat('MMM y').format(DateTime(range.start.year, range.start.month))} to ${DateFormat('MMM y').format(DateTime(end.year, end.month))}',
    };
    final base = today.year * 12 + today.month - 1;
    final idx = end.year * 12 + end.month - 1;
    CalDate at(int i) => CalDate(i ~/ 12, i % 12 + 1, 1);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.popOrHome(Routes.budget),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          const ScreenHeader('Reports', subtitle: 'Where the money went'),
          if (joint != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                0,
                Space.gutter,
                Space.md,
              ),
              child: Segmented<ReportView>(
                segments: const {
                  ReportView.category: 'By category',
                  ReportView.member: 'By member',
                },
                value: view,
                onChanged: (v) {
                  setState(() => _selected = null);
                  ref.read(reportViewProvider.notifier).set(v);
                },
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              key: const Key('report_spans'),
              children: [
                for (final s in ReportSpan.values) ...[
                  Pill(
                    s.label,
                    selected: s == span,
                    onTap: () {
                      setState(() => _selected = null);
                      ref.read(reportSpanProvider.notifier).set(s);
                    },
                  ),
                  const SizedBox(width: Space.sm),
                ],
              ],
            ),
          ),
          _ReportMonthBar(
            label: label,
            canBack: idx > base - 24,
            canFwd: idx < base,
            onBack: () => ref.read(reportEndProvider.notifier).set(at(idx - 1)),
            onFwd: () => ref.read(reportEndProvider.notifier).set(at(idx + 1)),
          ),
          const SizedBox(height: Space.sm),
          HeroNumber(
            label: view == ReportView.member ? 'Household spent' : 'Spent',
            value: total / 100,
            caption: prevTotal == 0
                ? null
                : '${total >= prevTotal ? '+' : '-'}${((total - prevTotal).abs() / prevTotal * 100).round()}% vs the period before',
            captionColor: total > prevTotal ? c.warning : c.positive,
          ),
          if (rows.isLoading && view == ReportView.category)
            const SkeletonList(rows: 3)
          else if (shown.isEmpty)
            EmptyState(
              icon: Icons.grid_view_rounded,
              title: 'Nothing spent in this period',
              message: view == ReportView.member
                  ? 'Members appear here once they share payments with the household.'
                  : 'Pick another month, or a longer range.',
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xl,
                Space.gutter,
                0,
              ),
              child: TreemapView(
                entries: [
                  for (final s in shown)
                    TreemapEntry(
                      s.id,
                      labelOf(s.id),
                      s.totalMinor.toDouble(),
                      Money.aed(s.totalMinor / 100, decimals: false),
                    ),
                ],
                selectedId: _selected,
                onSelect: (id) => setState(() => _selected = id),
              ),
            ),
            if (sel != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  0,
                ),
                child: SurfaceCard(
                  key: const Key('report_selected'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(labelOf(sel.id), style: context.tt.titleSmall),
                            Text(
                              '${Money.aed(sel.totalMinor / 100, decimals: false)} · '
                              '${(sel.totalMinor / total * 100).round()}% · ${sel.count} ${sel.count == 1 ? 'payment' : 'payments'}',
                              style: context.tt.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      if (view == ReportView.category &&
                          !(sel.id == 'other' && shown.length < slices.length))
                        TextAction(
                          'See payments',
                          onTap: () => context.push(
                            '${Routes.activity}?category=${sel.id}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SectionHeader(''),
            RowGroup(
              key: const Key('report_rows'),
              children: [
                for (final s in shown)
                  ListRow(
                    key: Key('report_row_${s.id}'),
                    dense: true,
                    title: labelOf(s.id),
                    subtitle:
                        '${(s.totalMinor / total * 100).round()}% of spend',
                    onTap: () => setState(() => _selected = s.id),
                    trailing: Text(
                      Money.aed(s.totalMinor / 100, decimals: false),
                      style: PulseTheme.amount(c.textPrimary, size: 15),
                    ),
                  ),
              ],
            ),
            if (view == ReportView.member)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.gutter,
                  Space.md,
                  Space.gutter,
                  0,
                ),
                child: Text(
                  'Only what each member shares with the household. Private payments are never counted.',
                  style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ReportMonthBar extends StatelessWidget {
  const _ReportMonthBar({
    required this.label,
    required this.canBack,
    required this.canFwd,
    required this.onBack,
    required this.onFwd,
  });
  final String label;
  final bool canBack, canFwd;
  final VoidCallback onBack, onFwd;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    Widget arrow(IconData icon, String l, bool on, VoidCallback f) => Semantics(
      button: true,
      enabled: on,
      label: l,
      child: Pressable(
        onTap: on ? f : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: on ? c.textPrimary : c.textTertiary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.gutter - 8,
        vertical: Space.xs,
      ),
      child: Row(
        key: const Key('report_month_bar'),
        children: [
          arrow(Icons.chevron_left_rounded, 'Earlier', canBack, onBack),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: context.tt.titleSmall,
            ),
          ),
          arrow(Icons.chevron_right_rounded, 'Later', canFwd, onFwd),
        ],
      ),
    );
  }
}
