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
import 'start_choice.dart';
import '../tour/tour_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

/// The intro after the tour: one page of value and the one question that is
/// ever asked on first launch, sample data or an empty start. The answer is
/// remembered, so a returning person never sees this again. There is no
/// sign-in here: that only appears when a backend is configured.
class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.read(analyticsProvider).track(AnalyticsEvent.onboardingStarted),
    );
  }

  Future<void> _start(StartChoice choice) async {
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.onboardingStepCompleted('intro_1'));
    ref.read(analyticsProvider).track(AnalyticsEvent.onboardingCompleted);
    await ref.read(startChoiceProvider.notifier).choose(choice);
    final session = ref.read(sessionProvider);
    session.finishOnboarding();
    // Sample data has nothing to connect; look around straight away.
    if (choice == StartChoice.sample) session.finishConnect();
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
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xl,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.auto_graph_rounded,
                              size: 56,
                              color: c.accent,
                            ),
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
                            key: const Key('start-fresh'),
                            label: 'Start fresh with ${Env.appName}',
                            onPressed: () => _start(StartChoice.fresh),
                          ),
                          if (Env.sampleAllowed) ...[
                            const SizedBox(height: Space.md),
                            PrimaryButton(
                              key: const Key('try-sample'),
                              label: 'Try with sample data',
                              icon: Icons.auto_awesome_rounded,
                              secondary: true,
                              onPressed: () => _start(StartChoice.sample),
                            ),
                            const SizedBox(height: Space.sm),
                            Text(
                              'Sample data is made up and can be switched off in Settings.',
                              textAlign: TextAlign.center,
                              style: context.tt.bodySmall!.copyWith(
                                color: c.textTertiary,
                              ),
                            ),
                          ],
                          if (!Env.demoData) ...[
                            const SizedBox(height: Space.sm),
                            TextAction(
                              'Have a backup? Restore it',
                              color: c.textSecondary,
                              onTap: () => context.go(Routes.restore),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
