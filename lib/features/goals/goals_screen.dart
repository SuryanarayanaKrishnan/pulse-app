import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/goals.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/goal_models.dart';
import '../../data/providers.dart';
import 'goal_sheet.dart';
import 'goal_widgets.dart';

Future<void> newGoal(BuildContext context, {GoalKind kind = GoalKind.save}) =>
    showPulseSheet<void>(
      context,
      full: true,
      builder: (_) => GoalSheet(kind: kind),
    );

/// All goals: active first, finished last.
class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final c = context.pc;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.wealth),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          ScreenHeader(
            'Goals',
            subtitle: 'Save up or pay down',
            trailing: [
              RoundIconButton(
                icon: Icons.add_rounded,
                label: 'New goal',
                onTap: () => newGoal(context),
              ),
            ],
          ),
          AsyncView<List<GoalView>>(
            value: goals,
            loading: const SkeletonList(rows: 3),
            onRetry: () => ref.invalidate(goalsProvider),
            builder: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.flag_outlined,
                  title: 'No goals yet',
                  message:
                      'Save for a car or a trip, build an emergency fund, or pay a card down. '
                      'Each goal sets a little aside from Safe to spend, so you can see it working.',
                  action: PrimaryButton(
                    label: 'Set a goal',
                    expand: false,
                    onPressed: () => newGoal(context),
                  ),
                );
              }
              final reserved = list.fold<int>(0, (a, g) => a + g.reservedMinor);
              final active = list.where((g) => !g.state.done).toList();
              final done = list.where((g) => g.state.done).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.gutter,
                    ),
                    child: Text(
                      '${aedMinor(reserved)} set aside for goals this month',
                      key: const Key('goals_set_aside'),
                      style: context.tt.bodyMedium!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                  if (active.isNotEmpty) ...[
                    const SectionHeader('Active', top: Space.lg),
                    RowGroup(
                      indent: ListRow.leadingInset,
                      children: [for (final g in active) GoalRow(g)],
                    ),
                  ],
                  if (done.isNotEmpty) ...[
                    const SectionHeader('Reached'),
                    RowGroup(
                      indent: ListRow.leadingInset,
                      children: [for (final g in done) GoalRow(g)],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The Goals block on Wealth: the nearest few, and a way in.
class GoalsSection extends ConsumerWidget {
  const GoalsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(goalsProvider).value ?? const <GoalView>[];
    final active = list.where((g) => !g.state.done).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Goals',
          action: list.isEmpty ? 'Set a goal' : 'See all',
          onAction: () =>
              list.isEmpty ? newGoal(context) : context.push(Routes.goals),
        ),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Text(
              'Save for something, or pay a card down. Goals set a little aside from Safe to spend.',
              style: context.tt.bodySmall,
            ),
          )
        else
          RowGroup(
            indent: ListRow.leadingInset,
            children: [
              for (final g in (active.isEmpty ? list : active).take(3))
                GoalRow(g),
            ],
          ),
      ],
    );
  }
}

/// Counts for the Home tile's second line.
({int active, int behind, int reservedMinor}) goalSummary(List<GoalView> list) {
  final active = list.where((g) => !g.state.done).toList();
  return (
    active: active.length,
    behind: active.where((g) => g.pace == GoalPace.behind).length,
    reservedMinor: active.fold(0, (a, g) => a + g.reservedMinor),
  );
}
