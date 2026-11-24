import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';

import 'package:go_router/go_router.dart';

import '../../core/env/env.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session.dart';
import '../privacy/consent_prompt.dart';
import '../tour/tour_progress.dart';
import '../tour/tour_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The intro after the tour: one page of value, then Start fresh or Restore
/// from backup. The tour already covered the rest.
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.read(analyticsProvider).track(AnalyticsEvent.onboardingStarted),
    );
  }

  void _start() {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.onboardingStepCompleted('intro_1'));
    ref.read(analyticsProvider).track(AnalyticsEvent.onboardingCompleted);
    ref.read(sessionProvider).finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(tourProgressProvider);
    if (!progress.loaded) {
      return const Scaffold(body: SizedBox.shrink());
    }
    // First launch: the short tour comes first, then the intro below
    // (with Restore from backup).
    if (progress.shouldShowTour) {
      return TourScreen(
        onFinished: (_) {
          ref.read(tourProgressProvider.notifier).markTourSeen();
          // After the tour, ask once about anonymous usage (default stays off).
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) askForUsageSharingOnce(context, ref);
          });
        },
      );
    }
    final c = context.pc;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_graph_rounded, size: 56, color: c.accent),
                    const SizedBox(height: Space.xxxl),
                    Text(
                      'Budgets that build themselves',
                      style: context.tt.displayMedium,
                    ),
                    const SizedBox(height: Space.md),
                    Text(
                      'Connect once. Every card swipe is captured and categorised automatically. No typing, ever.',
                      style: context.tt.bodyLarge!.copyWith(
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: 'Start fresh with ${Env.appName}',
                    onPressed: _start,
                  ),
                  const SizedBox(height: Space.md),
                  PrimaryButton(
                    label: 'Restore from backup',
                    icon: Icons.settings_backup_restore_rounded,
                    secondary: true,
                    onPressed: () => context.go(Routes.restore),
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
