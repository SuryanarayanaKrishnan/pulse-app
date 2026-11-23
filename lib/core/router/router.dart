import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/budgets/budget_screen.dart';
import '../../features/cards/cards_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/net_worth/wealth_screen.dart';
import '../../features/onboarding/connect_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splits/splits_screen.dart';
import '../../features/transactions/activity_screen.dart';
import '../analytics/analytics.dart';
import 'app_shell.dart';

abstract class Routes {
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const connect = '/connect';
  static const home = '/home';
  static const budget = '/budget';
  static const cards = '/cards';
  static const splits = '/splits';
  static const wealth = '/wealth';
  static const activity = '/activity';
  static const settings = '/settings';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter buildRouter({
  required SessionController session,
  required Analytics analytics,
  String? initialLocation,
}) {
  CustomTransitionPage<void> fade(GoRouterState s, Widget child) =>
      CustomTransitionPage<void>(
        key: s.pageKey,
        name: s.uri.path,
        child: child,
        transitionDuration: const Duration(milliseconds: 380),
        transitionsBuilder: (_, a, _, c) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: c,
          ),
        ),
      );

  final observer = AnalyticsRouteObserver(analytics);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation ?? Routes.home,
    refreshListenable: session,
    observers: [observer],
    redirect: (context, state) {
      final loc = state.uri.path;
      if (!session.onboarded)
        return loc == Routes.onboarding ? null : Routes.onboarding;
      if (!session.signedIn) return loc == Routes.signIn ? null : Routes.signIn;
      if (!session.connected)
        return loc == Routes.connect ? null : Routes.connect;
      if ({Routes.onboarding, Routes.signIn, Routes.connect}.contains(loc))
        return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (c, s) => fade(s, const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.signIn,
        pageBuilder: (c, s) => fade(s, const SignInScreen()),
      ),
      GoRoute(
        path: Routes.connect,
        pageBuilder: (c, s) => fade(s, const ConnectScreen()),
      ),
      GoRoute(
        path: Routes.activity,
        name: 'activity',
        builder: (c, s) =>
            ActivityScreen(initialCategory: s.uri.queryParameters['category']),
      ),
      GoRoute(
        path: Routes.settings,
        name: 'settings',
        builder: (c, s) => const SettingsScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                name: 'home',
                builder: (c, s) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budget,
                name: 'budget',
                builder: (c, s) => const BudgetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cards,
                name: 'cards',
                builder: (c, s) => const CardsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.splits,
                name: 'splits',
                builder: (c, s) => const SplitsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.wealth,
                name: 'wealth',
                builder: (c, s) => const WealthScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return router;
}
