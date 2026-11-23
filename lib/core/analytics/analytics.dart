import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../env/env.dart';

/// Typed product-analytics events. Add new events here, never as raw strings.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, [this.properties = const {}]);
  final String name;
  final Map<String, Object> properties;

  static const onboardingStarted = AnalyticsEvent._('onboarding_started');
  factory AnalyticsEvent.onboardingStepCompleted(String step) =>
      AnalyticsEvent._('onboarding_step_completed', {'step': step});
  static const signupCompleted = AnalyticsEvent._('signup_completed');
  factory AnalyticsEvent.sourceConnected(String type) =>
      AnalyticsEvent._('source_connected', {'type': type});
  static const statementUploaded = AnalyticsEvent._('statement_uploaded');
  factory AnalyticsEvent.transactionRecategorized({
    required String from,
    required String to,
  }) => AnalyticsEvent._('transaction_recategorized', {'from': from, 'to': to});
  static const budgetCreated = AnalyticsEvent._('budget_created');
  static const cardAdded = AnalyticsEvent._('card_added');
  factory AnalyticsEvent.cardRecommendationViewed(String category) =>
      AnalyticsEvent._('card_recommendation_viewed', {'category': category});
  static const splitExpenseAdded = AnalyticsEvent._('split_expense_added');

  /// Manual entry is the exception; we measure how often it is needed.
  factory AnalyticsEvent.manualTransactionAdded({required String category}) =>
      AnalyticsEvent._('manual_transaction_added', {'category': category});
}

/// Analytics abstraction.
abstract class Analytics {
  Future<void> init();
  void track(AnalyticsEvent event);
  void screen(String name);
  void identify(String userId);
  void reset();
}

/// Prints events to the debug console.
class ConsoleAnalytics implements Analytics {
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent e) =>
      debugPrint('[analytics] ${e.name} ${e.properties}');
  @override
  void screen(String name) => debugPrint('[analytics] screen $name');
  @override
  void identify(String userId) => debugPrint('[analytics] identify $userId');
  @override
  void reset() => debugPrint('[analytics] reset');
}

/// Does nothing. Used when no key is configured in release builds, and in tests.
class NoopAnalytics implements Analytics {
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent event) {}
  @override
  void screen(String name) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
}

/// PostHog-backed implementation.
class PostHogAnalytics implements Analytics {
  @override
  Future<void> init() async {
    final config = PostHogConfig(Env.posthogKey)
      ..host = Env.posthogHost
      ..captureApplicationLifecycleEvents = true
      ..debug = kDebugMode;
    await Posthog().setup(config);
  }

  @override
  void track(AnalyticsEvent e) =>
      Posthog().capture(eventName: e.name, properties: e.properties);
  @override
  void screen(String name) => Posthog().screen(screenName: name);
  @override
  void identify(String userId) => Posthog().identify(userId: userId);
  @override
  void reset() => Posthog().reset();
}

/// Fans out to several backends.
class CompositeAnalytics implements Analytics {
  CompositeAnalytics(this.children);
  final List<Analytics> children;
  @override
  Future<void> init() async {
    for (final c in children) {
      await c.init();
    }
  }

  @override
  void track(AnalyticsEvent e) {
    for (final c in children) {
      c.track(e);
    }
  }

  @override
  void screen(String name) {
    for (final c in children) {
      c.screen(name);
    }
  }

  @override
  void identify(String userId) {
    for (final c in children) {
      c.identify(userId);
    }
  }

  @override
  void reset() {
    for (final c in children) {
      c.reset();
    }
  }
}

/// PostHog when [Env.posthogKey] is set, plus console in debug. Noop otherwise.
Analytics buildAnalytics() {
  final list = <Analytics>[
    if (kDebugMode) ConsoleAnalytics(),
    if (Env.hasPosthog) PostHogAnalytics(),
  ];
  return list.isEmpty ? NoopAnalytics() : CompositeAnalytics(list);
}

final analyticsProvider = Provider<Analytics>((ref) => NoopAnalytics());

/// Reports every pushed/replaced route as a screen view. Tab switches are
/// reported separately by the app shell.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);
  final Analytics _analytics;

  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name != null && name.isNotEmpty) _analytics.screen(name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route);
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute);
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(previousRoute);
}
