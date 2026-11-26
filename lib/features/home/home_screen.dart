import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../capture/providers.dart';
import '../../core/engine/review.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../cards/best_moves_strip.dart';
import '../cards/card_widgets.dart';
import '../review/review_state.dart';
import '../wallet/add_sheets.dart';
import 'dashboard/dashboard_controller.dart';
import 'dashboard/dashboard_editor.dart';
import 'dashboard/dashboard_tiles.dart';
import 'health_sheet.dart';
import '../coach/coach.dart';

/// Home answers one question: how much can I safely spend today?
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final now = DateTime.now();
    // A brand-new on-device ledger has nothing to summarise yet.
    final accounts = ref.watch(bankAccountsProvider).value;
    final cards = ref.watch(myCardsProvider).value;
    final txs = ref.watch(transactionsProvider).value;
    final empty =
        accounts != null &&
        cards != null &&
        txs != null &&
        accounts.isEmpty &&
        cards.isEmpty &&
        txs.isEmpty;
    final dashState = ref.watch(dashboardProvider);
    final dash = ref.read(dashboardProvider.notifier);
    final editing = dashState.editing && !empty;
    final widgets = dashState.layout.active.widgets;
    final greeting = now.hour < 12
        ? 'Good morning'
        : (now.hour < 18 ? 'Good afternoon' : 'Good evening');
    return CoachHost(
      screen: CoachScreen.home,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: c.accent,
            backgroundColor: c.surface,
            onRefresh: () async {
              ref.invalidate(netWorthProvider);
              ref.invalidate(myCardsProvider);
              ref.invalidate(statementsProvider);
              ref.invalidate(splitGroupsProvider);
              invalidateLedger(ref);
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 120),
              children: [
                ScreenHeader(
                  greeting,
                  subtitle: DateFormat('EEEE d MMMM').format(now),
                  trailing: editing
                      ? [
                          TextAction(
                            'Done',
                            onTap: () {
                              Haptics.tap();
                              dash.setEditing(false);
                            },
                          ),
                          const SizedBox(width: Space.md),
                        ]
                      : [
                          if (!empty)
                            CoachTarget(
                              id: 'customise',
                              child: RoundIconButton(
                                icon: Icons.tune_rounded,
                                label: 'Customise',
                                onTap: () {
                                  Haptics.tap();
                                  dash.setEditing(true);
                                },
                              ),
                            ),
                          CoachTarget(
                            id: 'settings',
                            child: RoundIconButton(
                              icon: Icons.account_circle_outlined,
                              label: 'Settings',
                              onTap: () => context.push(Routes.settings),
                            ),
                          ),
                        ],
                ),
                const _CaptureNudge(),
                if (empty)
                  const _GetStarted()
                else ...[
                  const DashboardChips(),
                  if (editing)
                    const DashboardEditor()
                  else ...[
                    for (var i = 0; i < widgets.length; i++) ...[
                      DashTile(widgets[i], key: ValueKey(widgets[i].kind)),
                      // Which card and health sit right under the lead widget, wherever
                      // the user has put it.
                      if (i == 0) ...[
                        const _WhichCard(),
                        const BestMovesStrip(),
                        const _ReviewCard(),
                        const _Health(),
                      ],
                    ],
                    if (widgets.isEmpty) ...[
                      const _WhichCard(),
                      const BestMovesStrip(),
                      const _ReviewCard(),
                      const _Health(),
                    ],
                    const _Overview(),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// First run: the ledger is empty, so say what to do instead of showing zeros.
class _GetStarted extends StatelessWidget {
  const _GetStarted();
  @override
  Widget build(BuildContext context) => EmptyState(
    icon: Icons.waving_hand_outlined,
    title: 'Let us set up your money',
    message:
        'Add an account or a card. Pulse then reads your bank alerts on this '
        'phone and works out what is safe to spend. Nothing leaves the device.',
    action: PrimaryButton(
      label: 'Add an account or card',
      expand: false,
      onPressed: () => showAddMenu(context),
    ),
  );
}

/// Pre-purchase advice, one tap from Home.
class _WhichCard extends ConsumerWidget {
  const _WhichCard();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.xl,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md + 2,
        ),
        onTap: () => showWhichCard(context, ref),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(Icons.bolt_rounded, size: 20, color: c.onAccent),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Which card should I use?',
                    style: context.tt.titleSmall,
                  ),
                  Text('Before you pay', style: context.tt.bodySmall),
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

/// "N to review": one tap to the card stack. Quiet when there is nothing.
class _ReviewCard extends ConsumerWidget {
  const _ReviewCard();
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

class _Health extends ConsumerWidget {
  const _Health();
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

/// Secondary figures, one row each, linking to their home.
class _Overview extends ConsumerWidget {
  const _Overview();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final statements = ref.watch(statementsProvider).value;
    final attention = statements?.where((s) => s.needsAttention).length ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('More'),
        RowGroup(
          children: [
            ListRow(
              title: 'Family',
              subtitle: 'Shared spending, with privacy per person',
              chevron: true,
              onTap: () => context.push(Routes.family),
            ),
            if (statements != null)
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
        ),
      ],
    );
  }
}

/// Reminder on iPhone while any of the four capture paths is not working yet.
class _CaptureNudge extends ConsumerWidget {
  const _CaptureNudge();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(iosCaptureProvider)) return const SizedBox.shrink();
    final done = ref.watch(captureProgressProvider).value;
    if (done == null || done.length >= 4) return const SizedBox.shrink();
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.md,
        Space.gutter,
        0,
      ),
      child: SurfaceCard(
        key: const Key('capture_nudge'),
        onTap: () => context.push(Routes.applePaySetup),
        child: Row(
          children: [
            Icon(Icons.bolt_rounded, color: c.accent),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                'Finish capture setup: ${done.length} of 4 working. '
                'Payments on the other paths are missed until then.',
                style: context.tt.bodyMedium,
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}
