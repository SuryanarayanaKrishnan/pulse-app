import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/router.dart';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/goal_models.dart';
import '../../data/providers.dart';
import '../wealth/wealth_widgets.dart' show formatDate;
import 'contribution_sheet.dart';
import '../household/ownership_widgets.dart';
import 'goal_sheet.dart';
import 'goal_widgets.dart';

void _back(BuildContext context) {
  if (context.canPop()) {
    context.popOrHome();
  } else {
    context.go('/wealth');
  }
}

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});
  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final goals = ref.watch(goalsProvider);
    final v = goals.value?.where((g) => g.id == goalId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.record.name ?? '', overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => _back(context),
        ),
        actions: [
          if (v != null)
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showPulseSheet<void>(
                context,
                full: true,
                builder: (_) => GoalSheet(initial: v.record),
              ),
            ),
        ],
      ),
      body: v == null
          ? (goals.isLoading
                ? const SkeletonList(rows: 3)
                : const Center(child: Text('This goal is not here any more.')))
          : _Body(v, c),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body(this.v, this.c);
  final GoalView v;
  final PulseColors c;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: const Text(
          'Its history goes too. Money in your accounts is not touched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(goalServiceProvider).delete(v.id);
    invalidateGoals(ref);
    if (context.mounted) _back(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = v.state;
    final rec = v.record;
    final big = aedMinor(s.currentMinor);
    final of = v.isPaydown
        ? 'left of ${aedMinor(rec.startMinor)}'
        : 'of ${aedMinor(rec.targetMinor)}';
    final tt = context.tt;
    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        const SizedBox(height: Space.md),
        Center(
          child: Semantics(
            label: '${(s.progress * 100).round()} percent of the way',
            child: ProgressRing(
              progress: s.progress,
              size: 200,
              stroke: 12,
              color: s.done ? c.positive : c.accent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GoalIcon(rec.iconKey, kind: rec.kind, size: 36),
                  const SizedBox(height: Space.sm),
                  Text(
                    big,
                    key: const Key('goal_current'),
                    style: PulseTheme.amount(c.textPrimary, size: 26),
                  ),
                  Text(of, style: tt.bodySmall),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          child: Column(
            children: [
              Text(
                paceLabel(v.pace),
                key: const Key('goal_pace'),
                style: tt.titleMedium!.copyWith(color: paceColor(c, v.pace)),
              ),
              const SizedBox(height: Space.xs),
              Text(
                paceDetail(v),
                key: const Key('goal_pace_detail'),
                textAlign: TextAlign.center,
                style: tt.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        if (!v.linked && !s.done)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    key: const Key('goal_add'),
                    label: v.isPaydown ? 'Log a payment' : 'Add money',
                    onPressed: () => showPulseSheet<void>(
                      context,
                      builder: (_) => ContributionSheet(goal: v),
                    ),
                  ),
                ),
                if (!v.isPaydown) ...[
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('goal_withdraw'),
                      label: 'Withdraw',
                      secondary: true,
                      onPressed: s.currentMinor <= 0
                          ? null
                          : () => showPulseSheet<void>(
                              context,
                              builder: (_) =>
                                  ContributionSheet(goal: v, withdraw: true),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        const SectionHeader('Plan'),
        RowGroup(
          children: [
            ListRow(
              title: 'Each month',
              subtitle: rec.monthlyMinor == null
                  ? (v.suggestedMinor == null
                        ? 'No monthly amount yet'
                        : 'Suggested from your date')
                  : (v.suggestedMinor != null &&
                            v.suggestedMinor != rec.monthlyMinor
                        ? 'Your figure. Your date suggests ${aedMinor(v.suggestedMinor!)}'
                        : 'Your figure'),
              trailing: Text(
                aedMinor(v.plannedMinor),
                style: PulseTheme.amount(c.textPrimary, size: 15),
              ),
            ),
            if (rec.targetDate != null)
              ListRow(
                title: 'Target date',
                trailing: Text(
                  formatDate(rec.targetDate!),
                  style: tt.bodyMedium,
                ),
              ),
            if (v.projected != null)
              ListRow(
                title: 'Projected finish',
                trailing: Text(monthYear(v.projected!), style: tt.bodyMedium),
              ),
            ListRow(
              title: 'Set aside this month',
              subtitle: v.record.paused
                  ? 'Paused'
                  : 'Held back from Safe to spend',
              trailing: Text(
                aedMinor(v.reservedMinor),
                key: const Key('goal_reserved'),
                style: PulseTheme.amount(c.textPrimary, size: 15),
              ),
            ),
            if (v.linkedName != null)
              ListRow(
                title: 'Follows',
                trailing: Text(v.linkedName!, style: tt.bodyMedium),
              ),
            OwnerRow(table: 'goals', id: v.id, title: rec.name, dense: false),
            if (!s.done)
              ListRow(
                title: 'Pause set-aside',
                subtitle: 'Stop holding money back for now. Progress is kept.',
                trailing: Switch(
                  key: const Key('goal_pause'),
                  value: rec.paused,
                  onChanged: (p) async {
                    await ref.read(goalServiceProvider).setPaused(v.id, p);
                    invalidateGoals(ref);
                  },
                ),
              ),
          ],
        ),
        if (!v.linked) ...[
          const SectionHeader('History'),
          if (v.contributions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: Text(
                'Nothing yet. Each deposit or payment you log shows up here.',
                style: tt.bodySmall,
              ),
            )
          else
            RowGroup(
              children: [
                for (final h in v.contributions)
                  ListRow(
                    key: ValueKey('hist_${h.id}'),
                    title: h.amountMinor >= 0
                        ? (v.isPaydown ? 'Payment' : 'Added')
                        : 'Withdrawn',
                    subtitle: [
                      formatDate(h.date),
                      if (h.note != null) h.note!,
                    ].join(' · '),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${h.amountMinor >= 0 ? '+' : '−'}${Money.aed(h.amountMinor.abs() / 100, decimals: false)}',
                          style: PulseTheme.amount(
                            h.amountMinor >= 0 ? c.positive : c.textSecondary,
                            size: 15,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove',
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () async {
                            await ref
                                .read(goalServiceProvider)
                                .removeContribution(h.id);
                            invalidateGoals(ref);
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
        const SizedBox(height: Space.xl),
        Center(
          child: TextAction(
            'Delete goal',
            color: c.negative,
            onTap: () => _delete(context, ref),
          ),
        ),
      ],
    );
  }
}
