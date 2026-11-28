import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/engine/review.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/cap_providers.dart';
import '../../data/overrun_providers.dart';
import '../../data/providers.dart';
import '../budgets/overrun_section.dart';
import '../cards/cap_watch_card.dart';
import '../review/review_state.dart';
import 'dashboard/dashboard_layout.dart';
import 'health_sheet.dart';

/// "N to review": one tap to the card stack. Quiet when there is nothing.
class ReviewTile extends ConsumerWidget {
  const ReviewTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final n = ref.watch(reviewCountProvider).value;
    if (n == null) return const SizedBox.shrink();
    final streak = streakLabel(ref.watch(reviewStreakProvider));
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        key: const ValueKey('review-card-home'),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        onTap: () => context.push(Routes.review),
        child: Row(
          children: [
            IconWell(
              n > 0 ? Icons.layers_outlined : Icons.check_rounded,
              color: n > 0 ? c.accent : c.textSecondary,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n > 0 ? '$n to review' : 'Inbox zero',
                    style: context.tt.titleSmall,
                  ),
                  Text(
                    n > 0
                        ? 'Swipe through, one at a time'
                        : (streak ?? 'All caught up'),
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

class HealthTile extends ConsumerWidget {
  const HealthTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final h = ref.watch(healthScoreProvider).value;
    if (h == null || h.insufficient) return const SizedBox.shrink();
    final tone = h.score >= 60
        ? c.accent
        : h.score >= 40
        ? c.warning
        : c.negative;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Today'),
        RowGroup(
          children: [
            ListRow(
              leading: ProgressRing(
                progress: h.score / 100,
                size: 32,
                stroke: 3,
                color: tone,
              ),
              title: 'Financial health ${h.score} · ${h.band}',
              subtitle: h.readiness,
              chevron: true,
              onTap: () =>
                  showPulseSheet<void>(context, builder: (_) => HealthSheet(h)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Family shortcut, one row.
class FamilyTile extends StatelessWidget {
  const FamilyTile({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RowGroup(
        children: [
          ListRow(
            title: 'Family',
            subtitle: 'Shared spending, with privacy per person',
            chevron: true,
            onTap: () => context.push(Routes.family),
          ),
        ],
      ),
    ],
  );
}

/// Monthly close shortcut, one row.
class CloseTile extends ConsumerWidget {
  const CloseTile({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final statements = ref.watch(statementsProvider).value;
    if (statements == null) return const SizedBox.shrink();
    final attention = statements.where((s) => s.needsAttention).length;
    return RowGroup(
      children: [
        ListRow(
          title: 'Monthly close',
          subtitle: attention == 0
              ? 'Every statement matches'
              : '$attention ${attention == 1 ? 'statement needs' : 'statements need'} you',
          subtitleColor: attention == 0 ? null : c.warning,
          chevron: true,
          onTap: () => context.push(Routes.statements),
        ),
      ],
    );
  }
}

/// The one thing worth knowing right now. Home shows a single insight, picked
/// in this order: a budget overrun, a reward cap, then items to review. Each
/// of these is also a Home widget a person can add, and then it is not
/// repeated here.
class TopInsight extends ConsumerWidget {
  const TopInsight({super.key, this.skip = const {}});

  /// Kinds already on this dashboard.
  final Set<DashKind> skip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overrun = skip.contains(DashKind.overrun)
        ? null
        : ref.watch(overrunReportProvider).value;
    if (overrun != null && overrun.items.isNotEmpty) {
      return const OverrunHomeLine();
    }
    final caps = skip.contains(DashKind.capWatch)
        ? null
        : ref.watch(capWatchProvider).value;
    if (caps != null && caps.isNotEmpty) return const CapWatchCard();
    final n = skip.contains(DashKind.review)
        ? null
        : ref.watch(reviewCountProvider).value;
    if (n != null && n > 0) return const ReviewTile();
    return const SizedBox.shrink();
  }
}
