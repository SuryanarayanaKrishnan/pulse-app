import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';

import 'package:go_router/go_router.dart';

import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session.dart';
import '../tour/tour_progress.dart';
import '../tour/tour_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _ctl = PageController();
  int _page = 0;

  static const _pages = [
    (
      Icons.auto_graph_rounded,
      'Budgets that build themselves',
      'Connect once. Every card swipe is captured and categorised automatically. No typing, ever.',
    ),
    (
      Icons.credit_card_rounded,
      'The right card, every time',
      'See which of your UAE cards earns the most for groceries, dining or travel, before you pay.',
    ),
    (
      Icons.account_balance_rounded,
      'Your whole net worth',
      'Cash, deposits, gold, stocks and property. All in one calm, honest picture.',
    ),
    (
      Icons.group_rounded,
      'Splits without the awkward',
      'Share bills with friends and flatmates and settle up in a tap.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.read(analyticsProvider).track(AnalyticsEvent.onboardingStarted),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _next() {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.onboardingStepCompleted('intro_${_page + 1}'));
    if (_page == _pages.length - 1) {
      ref.read(sessionProvider).finishOnboarding();
    } else {
      _ctl.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(tourProgressProvider);
    if (!progress.loaded) {
      return const Scaffold(body: SizedBox.shrink());
    }
    // First launch: the short tour comes first, then the usual intro below
    // (with Restore from backup).
    if (progress.shouldShowTour) {
      return TourScreen(
        onFinished: (_) =>
            ref.read(tourProgressProvider.notifier).markTourSeen(),
      );
    }
    final c = context.pc;
    final last = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(Space.lg),
                child: TextAction(
                  'Skip',
                  color: c.textSecondary,
                  onTap: () => ref.read(sessionProvider).finishOnboarding(),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _ctl,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(p.$1, size: 56, color: c.accent),
                        const SizedBox(height: Space.xxxl),
                        Text(p.$2, style: context.tt.displayMedium),
                        const SizedBox(height: Space.md),
                        Text(
                          p.$3,
                          style: context.tt.bodyLarge!.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? c.textPrimary : c.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: last
                        ? 'Start fresh with ${Env.appName}'
                        : 'Continue',
                    onPressed: _next,
                  ),
                  if (last) ...[
                    const SizedBox(height: Space.md),
                    PrimaryButton(
                      label: 'Restore from backup',
                      icon: Icons.settings_backup_restore_rounded,
                      secondary: true,
                      onPressed: () => context.go(Routes.restore),
                    ),
                  ] else
                    TextAction(
                      'Already use ${Env.appName}? Restore from backup',
                      color: c.textSecondary,
                      onTap: () => context.go(Routes.restore),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
