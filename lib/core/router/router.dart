import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/session.dart';
import '../../features/backup/backup_screen.dart';
import '../../features/privacy/privacy_screen.dart';
import '../../features/sync/sync_screen.dart';
import '../../features/backup/backup_setup_screen.dart';
import '../../features/backup/restore_screen.dart';
import '../../features/capture/apple_ingest_screen.dart';
import '../../features/capture/apple_pay_setup_screen.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/automations/automations_screen.dart';
import '../../features/budgets/budget_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/splits/group_screen.dart';
import '../../features/statements/statements_screen.dart';
import '../../features/cards/cards_screen.dart';
import '../../features/cards/ranked_screen.dart';
import '../../features/family/family_screen.dart';
import '../../features/goals/goal_detail_screen.dart';
import '../../features/goals/goals_screen.dart';
import '../../features/family/legacy_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/net_worth/wealth_screen.dart';
import '../../features/onboarding/connect_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/splits/splits_screen.dart';
import '../../features/wealth/document_screens.dart';
import '../../features/wealth/fund_screens.dart';
import '../../features/wealth/jewellery_screens.dart';
import '../../features/tour/tour_screen.dart';
import '../../features/transactions/activity_screen.dart';
import '../analytics/analytics.dart';
import '../env/env.dart';
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
  static const applePaySetup = '/apple-pay-setup';
  static const appleIngest = '/apple-ingest';
  static const categories = '/categories';
  static const automations = '/automations';
  static const statements = '/statements';
  static const family = '/family';
  static const cardsRanked = '/cards-ranked';
  static const legacy = '/legacy';
  static const backup = '/backup';
  static const backupSetup = '/backup/setup';
  static const sync = '/sync';
  static const privacy = '/privacy';
  static const review = '/review';
  static const goals = '/goals';
  static const restore = '/restore';

  /// Replay of the first-launch tour (Settings).
  static const tour = '/tour';

  /// `/group/<id>`
  static const group = '/group';

  /// `/jewellery/<id>`, `/document/<id>`, `/fund/<id>` (Wealth detail pages)
  static const jewellery = '/jewellery';
  static const document = '/document';
  static const fund = '/fund';
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
      // Custom-scheme deep link: pulse://ingest?amount=..&merchant=..&card=..
      if (state.uri.scheme == Env.urlScheme) {
        final u = state.uri;
        return (u.host == 'ingest' || u.path == '/ingest')
            ? Uri(
                path: Routes.appleIngest,
                queryParameters: u.queryParameters,
              ).toString()
            : Routes.home;
      }
      final loc = state.uri.path;
      // Restore happens before the app is set up, whatever the session says.
      if (loc == Routes.restore && !session.connected) return null;
      if (!session.onboarded)
        return loc == Routes.onboarding ? null : Routes.onboarding;
      if (!session.signedIn) return loc == Routes.signIn ? null : Routes.signIn;
      if (!session.connected) {
        // The Apple Pay guide is part of the connect step.
        return {Routes.connect, Routes.applePaySetup}.contains(loc)
            ? null
            : Routes.connect;
      }
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
        path: Routes.restore,
        pageBuilder: (c, s) => fade(s, const RestoreScreen()),
      ),
      GoRoute(
        path: Routes.backup,
        pageBuilder: (c, s) => fade(s, const BackupScreen()),
      ),
      GoRoute(
        path: Routes.sync,
        pageBuilder: (c, s) => fade(s, const SyncScreen()),
      ),
      GoRoute(
        path: Routes.backupSetup,
        pageBuilder: (c, s) => fade(
          s,
          BackupSetupScreen(change: s.uri.queryParameters['change'] == '1'),
        ),
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
        path: Routes.applePaySetup,
        name: 'apple_pay_setup',
        builder: (c, s) => const ApplePaySetupScreen(),
      ),
      GoRoute(
        path: Routes.appleIngest,
        name: 'apple_ingest',
        builder: (c, s) => AppleIngestScreen(params: s.uri.queryParameters),
      ),
      GoRoute(
        path: Routes.review,
        name: 'review',
        pageBuilder: (c, s) => fade(s, const ReviewScreen()),
      ),
      GoRoute(
        path: Routes.goals,
        name: 'goals',
        builder: (c, s) => const GoalsScreen(),
      ),
      GoRoute(
        path: '${Routes.goals}/:id',
        name: 'goal',
        builder: (c, s) => GoalDetailScreen(goalId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.privacy,
        name: 'privacy',
        builder: (c, s) => const PrivacyScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        name: 'settings',
        builder: (c, s) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.tour,
        name: 'tour',
        builder: (c, s) => TourScreen(onFinished: (_) => c.pop()),
      ),
      GoRoute(
        path: Routes.categories,
        name: 'categories',
        builder: (c, s) => const CategoriesScreen(),
      ),
      GoRoute(
        path: Routes.automations,
        name: 'automations',
        builder: (c, s) => const AutomationsScreen(),
      ),
      GoRoute(
        path: Routes.cardsRanked,
        name: 'cards-ranked',
        builder: (c, s) => const RankedCardsScreen(),
      ),
      GoRoute(
        path: Routes.family,
        name: 'family',
        builder: (c, s) => const FamilyScreen(),
      ),
      GoRoute(
        path: Routes.legacy,
        name: 'legacy',
        builder: (c, s) => const LegacyScreen(),
      ),
      GoRoute(
        path: Routes.statements,
        name: 'statements',
        builder: (c, s) => const StatementsScreen(),
      ),
      GoRoute(
        path: '${Routes.jewellery}/:id',
        name: 'jewellery',
        builder: (c, s) =>
            JewelleryDetailScreen(itemId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.document}/:id',
        name: 'document',
        builder: (c, s) => DocumentDetailScreen(docId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.fund}/:id',
        name: 'fund',
        builder: (c, s) => FundDetailScreen(fundId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '${Routes.group}/:id',
        name: 'group',
        builder: (c, s) => GroupScreen(groupId: s.pathParameters['id']!),
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
