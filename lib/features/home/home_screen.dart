import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/providers.dart';
import '../cards/card_widgets.dart';
import '../discover/all_features_sheet.dart';
import '../wallet/add_sheets.dart';
import 'dashboard/dashboard_controller.dart';
import 'dashboard/dashboard_editor.dart';
import 'dashboard/dashboard_tiles.dart';
import '../../core/utils/app_clock.dart';
import 'home_extras.dart';
import '../coach/coach.dart';

/// Home answers one question: how much can I safely spend today?
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final now = AppClock.now();
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
          // Content scrolls under the status bar instead of being sliced off
          // at the safe-area line (it clipped the dashboard chips).
          top: false,
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
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top,
                bottom: 120,
              ),
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
                          RoundIconButton(
                            key: const Key('home-all-features'),
                            icon: Icons.search_rounded,
                            label: 'Search',
                            onTap: () => showAllFeaturesSheet(context),
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
                if (empty)
                  const _GetStarted()
                else ...[
                  const DashboardChips(),
                  if (editing)
                    const DashboardEditor()
                  else ...[
                    for (var i = 0; i < widgets.length; i++) ...[
                      DashTile(widgets[i], key: ValueKey(widgets[i].kind)),
                      // The calm part of Home: which card to use and the one
                      // insight worth knowing, right under the lead widget.
                      if (i == 0) ...[
                        const _WhichCard(),
                        TopInsight(skip: {for (final w in widgets) w.kind}),
                      ],
                    ],
                    if (widgets.isEmpty) ...[
                      const _WhichCard(),
                      const TopInsight(),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: Space.xl),
                      child: Center(
                        child: CoachTarget(
                          id: 'customise',
                          child: TextAction(
                            'Add to Home',
                            key: const Key('home-add-widget'),
                            onTap: () {
                              Haptics.tap();
                              dash.setEditing(true);
                            },
                          ),
                        ),
                      ),
                    ),
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
