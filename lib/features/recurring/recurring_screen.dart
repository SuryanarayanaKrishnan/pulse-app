import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/recurring_plan.dart';
import '../../core/router/router.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/recurring_providers.dart';
import 'recurring_calendar.dart';
import 'recurring_detail_sheet.dart';

enum _View { list, calendar }

String dayLabel(CalDate d) => DateFormat('d MMM').format(DateTime(d.year, d.month, d.day));

String cadenceLabel(String c) => switch (c) {
  'weekly' => 'Weekly',
  'fortnightly' => 'Every 2 weeks',
  'monthly' => 'Monthly',
  'quarterly' => 'Every 3 months',
  _ => 'Yearly',
};

IconData iconFor(RecKind k) => switch (k) {
  RecKind.subscription => Icons.autorenew_rounded,
  RecKind.payment => Icons.event_repeat_rounded,
  RecKind.cardDue => Icons.credit_card_outlined,
  RecKind.bill => Icons.receipt_long_outlined,
};

/// Recurring payments: bills and subscriptions found in your own ledger, by
/// status or on a calendar. Lives under Budget.
class RecurringScreen extends ConsumerStatefulWidget {
  const RecurringScreen({super.key});

  @override
  ConsumerState<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends ConsumerState<RecurringScreen> {
  _View _view = _View.list;

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(recurringMonthProvider);
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
          const ScreenHeader('Recurring', subtitle: 'Bills and subscriptions'),
          const _MonthBar(),
          AsyncView<RecurringMonth>(
            value: month,
            loading: const SkeletonList(rows: 4),
            onRetry: () => ref.invalidate(recurringMonthProvider),
            builder: (m) {
              if (m.items.isEmpty && m.lapsed.isEmpty) {
                return EmptyState(
                  icon: Icons.event_repeat_rounded,
                  title: 'Nothing recurring yet',
                  message:
                      'Pulse looks for payments that repeat, like a subscription, rent or a phone bill. '
                      'Once a payment has shown up three times it appears here. This happens on your phone.',
                );
              }
              return _Body(m, _view, (v) => setState(() => _view = v));
            },
          ),
        ],
      ),
    );
  }
}

class _MonthBar extends ConsumerWidget {
  const _MonthBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final today = ref.watch(recurringTodayProvider);
    final cur = ref.watch(recurringMonthSelectionProvider);
    final idx = cur.year * 12 + cur.month - 1;
    final base = today.year * 12 + today.month - 1;
    CalDate at(int i) => CalDate(i ~/ 12, i % 12 + 1, 1);
    Widget arrow(IconData icon, String label, bool on, int to) => Semantics(
      button: true,
      enabled: on,
      label: label,
      child: Pressable(
        onTap: on ? () => ref.read(recurringMonthSelectionProvider.notifier).set(at(to)) : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: 22, color: on ? c.textPrimary : c.textTertiary.withValues(alpha: 0.4)),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter - 8),
      child: Row(
        key: const Key('recurring_month_bar'),
        children: [
          arrow(Icons.chevron_left_rounded, 'Previous month', idx > base - 12, idx - 1),
          Expanded(
            child: Text(
              DateFormat('MMMM y').format(DateTime(cur.year, cur.month)),
              textAlign: TextAlign.center,
              style: context.tt.titleSmall,
            ),
          ),
          arrow(Icons.chevron_right_rounded, 'Next month', idx < base + 6, idx + 1),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.m, this.view, this.onView);
  final RecurringMonth m;
  final _View view;
  final ValueChanged<_View> onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final progress = m.committedMinor == 0 ? 0.0 : m.paidMinor / m.committedMinor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Space.md),
        HeroNumber(
          label: 'Committed this month',
          value: m.committedMinor / 100,
          caption: '${Money.aed(m.paidMinor / 100, decimals: false)} paid · '
              '${Money.aed(m.leftMinor / 100, decimals: false)} still to come',
          footer: Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Meter(value: progress.clamp(0, 1).toDouble(), color: c.accent),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
          child: Segmented<_View>(
            segments: const {_View.list: 'List', _View.calendar: 'Calendar'},
            value: view,
            onChanged: onView,
          ),
        ),
        if (m.hints.isNotEmpty) _Hints(m),
        if (view == _View.calendar)
          RecurringCalendar(m)
        else ...[
          if (m.overdue.isNotEmpty) _Section('Overdue', m.overdue, tint: c.warning),
          if (m.upcoming.isNotEmpty) _Section('Upcoming', m.upcoming),
          if (m.paid.isNotEmpty) _Section('Paid', m.paid),
          if (m.items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xl, Space.gutter, 0),
              child: Text('Nothing due in this month.', style: context.tt.bodyMedium),
            ),
        ],
        const _HiddenRow(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.lg, Space.gutter, 0),
          child: Text(
            'Found on this phone from your payments. Tap one to confirm it or say it is not recurring.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}

class _Hints extends StatelessWidget {
  const _Hints(this.m);
  final RecurringMonth m;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Price rises'),
        for (final h in m.hints)
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.xs, Space.gutter, 0),
            child: SurfaceCard(
              key: Key('price_hint_${h.series.key}'),
              padding: const EdgeInsets.all(Space.md),
              onTap: () => showRecurringDetail(context, h.series),
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 20, color: c.warning),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${h.series.merchant} went up ${h.change.pct.toStringAsFixed(0)}%',
                          style: context.tt.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${Money.number(h.change.fromMinor / 100)} to ${Money.number(h.change.toMinor / 100)}, '
                          'about ${Money.aed(h.yearlyExtraMinor / 100, decimals: false)} more a year.',
                          style: context.tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.items, {this.tint});
  final String title;
  final List<RecItem> items;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionHeader(title),
      RowGroup(
        key: Key('rec_${title.toLowerCase()}'),
        indent: ListRow.leadingInset,
        children: [for (final i in items) RecRow(i, tint: tint)],
      ),
    ],
  );
}

/// One recurring item as a list row.
class RecRow extends StatelessWidget {
  const RecRow(this.item, {super.key, this.tint});
  final RecItem item;
  final Color? tint;

  String get _subtitle {
    final parts = <String>[
      switch (item.state) {
        RecState.paid => 'Paid ${dayLabel(item.dueOn)}',
        RecState.upcoming => 'Due ${dayLabel(item.dueOn)}',
        RecState.overdue => 'Expected ${dayLabel(item.dueOn)}',
      },
      if (item.series != null) cadenceLabel(item.series!.cadence).toLowerCase(),
      if (item.kind == RecKind.cardDue) 'card payment',
      if (item.kind == RecKind.bill) 'household bill',
      if (item.confirmed) 'confirmed',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final s = item.series;
    return ListRow(
      key: Key('rec_item_${item.id}_${item.dueOn.toIso()}'),
      leading: IconWell(iconFor(item.kind)),
      title: item.title,
      subtitle: _subtitle,
      subtitleColor: item.state == RecState.overdue ? c.warning : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s?.priceIncrease != null) ...[
            Icon(Icons.trending_up_rounded, size: 16, color: c.warning),
            const SizedBox(width: Space.xs),
          ],
          Text(
            '${s != null && s.amountKind == 'variable' && item.state != RecState.paid ? '~' : ''}'
            '${Money.aed(item.amountMinor / 100, decimals: false)}',
            style: PulseTheme.amount(item.state == RecState.paid ? c.textSecondary : c.textPrimary),
          ),
        ],
      ),
      chevron: true,
      onTap: () => showRecurringItem(context, item),
    );
  }
}

class _HiddenRow extends ConsumerWidget {
  const _HiddenRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(recurringChoicesProvider).value ?? const {};
    final n = choices.values.where((v) => v == RecChoice.ignored).length;
    if (n == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: RowGroup(
        children: [
          ListRow(
            key: const Key('rec_hidden'),
            leading: const IconWell(Icons.visibility_off_outlined),
            title: 'Not recurring',
            subtitle: '$n hidden',
            chevron: true,
            onTap: () => showHiddenRecurring(context),
          ),
        ],
      ),
    );
  }
}
