import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/budget_overrun.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/budget_plan_service.dart';
import '../../data/overrun_providers.dart';
import '../../data/providers.dart';

Color _tone(BuildContext context, OverrunKind k) => switch (k) {
  OverrunKind.pattern => context.pc.warning,
  _ => context.pc.textSecondary,
};

/// Reports each kind shown on a surface once per screen visit.
mixin _ViewedOnce<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final _seen = <String>{};
  void reportViewed(Iterable<OverrunKind> kinds, String surface) {
    final fresh = [
      for (final k in kinds.toSet())
        if (_seen.add(k.key)) k,
    ];
    if (fresh.isEmpty) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final k in fresh) {
        ref
            .read(analyticsProvider)
            .track(AnalyticsEvent.overrunViewed(kind: k.key, surface: surface));
      }
    });
  }
}

/// Budget: where you went over, whether it looks like a one-off or a habit,
/// and what you can do about it. Nothing here changes a budget until you tap.
class OverrunSection extends ConsumerStatefulWidget {
  const OverrunSection({super.key});
  @override
  ConsumerState<OverrunSection> createState() => _OverrunSectionState();
}

class _OverrunSectionState extends ConsumerState<OverrunSection>
    with _ViewedOnce {
  bool _all = false;
  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(overrunReportProvider).value;
    if (report == null || report.items.isEmpty) return const SizedBox.shrink();
    final items = _all ? report.items : report.items.take(_shown).toList();
    reportViewed(items.map((i) => i.overrun.kind), 'budget');
    final c = context.pc;
    return Column(
      key: const Key('overrun_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Over budget'),
        for (final i in items)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              0,
            ),
            child: OverrunCard(item: i, report: report),
          ),
        if (report.items.length > _shown)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              child: TextAction(
                key: const Key('overrun_more'),
                _all
                    ? 'Show fewer'
                    : 'Show ${report.items.length - _shown} more',
                onTap: () => setState(() => _all = !_all),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            Space.sm,
            Space.gutter,
            0,
          ),
          child: Text(
            overrunCaveat,
            key: const Key('overrun_caveat'),
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}

class OverrunCard extends ConsumerWidget {
  const OverrunCard({super.key, required this.item, required this.report});
  final OverrunItem item;
  final OverrunReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final o = item.overrun;
    final cat = item.category;
    final tone = _tone(context, o.kind);
    final names = [for (final x in o.contributors.take(2)) x.merchant];
    final ceiling = o.suggestedCeilingMinor;
    return SurfaceCard(
      key: Key('overrun_${cat.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon.well(cat),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      overrunTitle(o, cat.label),
                      style: context.tt.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      key: Key('overrun_kind_${cat.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                      child: Text(
                        o.kind.label,
                        style: context.tt.labelMedium!.copyWith(
                          color: c.isDark ? tone : c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(overrunSentence(o), style: context.tt.bodyMedium),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Mostly ${names.join(' and ')}.', style: context.tt.bodySmall),
          ],
          if (ceiling != null && item.funding != null) ...[
            const SizedBox(height: Space.sm),
            Text(
              fundingSentence(item.funding!, report.labelOf),
              key: Key('overrun_funding_${cat.id}'),
              style: context.tt.bodySmall,
            ),
          ],
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (ceiling != null)
                PrimaryButton(
                  key: Key('overrun_raise_${cat.id}'),
                  label: raiseLabel(ceiling),
                  expand: false,
                  onPressed: () => _raise(context, ref, ceiling),
                ),
              TextAction(
                key: Key('overrun_oneoff_${cat.id}'),
                'Mark as one-off',
                color: ceiling != null ? c.textSecondary : null,
                onTap: () => _markOneOff(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _markOneOff(BuildContext context, WidgetRef ref) async {
    final o = item.overrun;
    final marks = ref.read(overrunMarksProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    Haptics.light();
    await marks.mark(o.categoryId, o.month);
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.overrunMarkedOneOff(item.category.id));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Marked as a one-off. Your ${item.category.label} budget is unchanged.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => marks.unmark(o.categoryId, o.month),
        ),
      ),
    );
  }

  Future<void> _raise(
    BuildContext context,
    WidgetRef ref,
    int ceilingMinor,
  ) async {
    final o = item.overrun;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final label = item.category.label;
    Haptics.light();
    await repo.setBudget(item.category, ceilingMinor / 100);
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.overrunCeilingRaised(item.category.id));
    invalidateBudgetPlan(ref);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('$label budget is now ${aedWhole(ceilingMinor)} a month'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repo.setBudget(item.category, o.plannedMinor / 100);
            ref
                .read(analyticsProvider)
                .track(AnalyticsEvent.overrunRaiseUndone(item.category.id));
            invalidateBudgetPlan(ref);
          },
        ),
      ),
    );
  }
}

/// Home: one calm line when something is over budget. Quiet otherwise.
class OverrunHomeLine extends ConsumerStatefulWidget {
  const OverrunHomeLine({super.key});
  @override
  ConsumerState<OverrunHomeLine> createState() => _OverrunHomeLineState();
}

class _OverrunHomeLineState extends ConsumerState<OverrunHomeLine>
    with _ViewedOnce {
  @override
  Widget build(BuildContext context) {
    final report = ref.watch(overrunReportProvider).value;
    if (report == null || report.items.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    final first = report.items.first;
    final n = report.items.length;
    final o = first.overrun;
    reportViewed([o.kind], 'home');
    final hint = switch (o.kind) {
      OverrunKind.oneOff => 'Looks like a one-off. See why',
      OverrunKind.pattern => 'Keeps happening. See why',
      _ => 'See why',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        key: const Key('overrun_home_line'),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        onTap: () => context.go(Routes.budget),
        child: Row(
          children: [
            IconWell(Icons.trending_up_rounded, color: c.warning),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n == 1
                        ? '${first.category.label} is over budget'
                        : '$n categories are over budget',
                    style: context.tt.titleSmall,
                  ),
                  Text(
                    n == 1 ? hint : 'Biggest: ${first.category.label}. See why',
                    style: context.tt.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
