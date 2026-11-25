import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../env/env.dart';
import 'event_schema.dart';

/// Typed product-analytics events. Add new events here AND in
/// [AnalyticsSchema]; an event the schema does not list is never sent.
@immutable
class AnalyticsEvent {
  const AnalyticsEvent._(this.name, [this.properties = const {}]);

  /// Builds an event without the typed factories. The gate re-checks every
  /// event against [AnalyticsSchema], so this cannot widen what is sent.
  const AnalyticsEvent.unchecked(this.name, [this.properties = const {}]);

  final String name;
  final Map<String, Object> properties;

  /// Default categories keep their id; a category you made is just `custom`.
  static String _category(String id) =>
      AnalyticsSchema.categories.contains(id) && id != 'custom' ? id : 'custom';

  /// Coarse duration bucket (never an exact time).
  static String durationBucket(int seconds) => seconds < 5
      ? 'lt_5s'
      : (seconds < 30 ? '5_30s' : (seconds < 120 ? '30_120s' : 'gt_120s'));

  static const onboardingStarted = AnalyticsEvent._('onboarding_started');
  static const onboardingCompleted = AnalyticsEvent._('onboarding_completed');
  factory AnalyticsEvent.onboardingStepCompleted(String step) =>
      AnalyticsEvent._('onboarding_step_completed', {'step': step});
  // ---- Tour. `step` is the moment key: safe_to_spend | right_card |
  // auto_capture | net_worth. ----
  static const tourStarted = AnalyticsEvent._('tour_started');
  factory AnalyticsEvent.tourStepViewed(String step) =>
      AnalyticsEvent._('tour_step_viewed', {'step': step});
  factory AnalyticsEvent.tourSkipped(String step) =>
      AnalyticsEvent._('tour_skipped', {'step': step});
  static const tourCompleted = AnalyticsEvent._('tour_completed');
  static const signupCompleted = AnalyticsEvent._('signup_completed');
  factory AnalyticsEvent.sourceConnected(String type) =>
      AnalyticsEvent._('source_connected', {'type': type});
  static const statementUploaded = AnalyticsEvent._('statement_uploaded');
  factory AnalyticsEvent.transactionRecategorized({
    required String from,
    required String to,
  }) => AnalyticsEvent._('transaction_recategorized', {
    'from': _category(from),
    'to': _category(to),
  });

  /// `scope`: once | future | all. Never carries the merchant or counts.
  factory AnalyticsEvent.recategoriseScope(String scope) =>
      AnalyticsEvent._('recategorise_scope', {'scope': scope});

  /// `direction`: right (looks right) | left (fix it). Never the payment.
  factory AnalyticsEvent.reviewSwiped(String direction) =>
      AnalyticsEvent._('review_swiped', {'direction': direction});

  /// `enabled`: yes or no. Never what would be shared.
  factory AnalyticsEvent.learningOptIn(bool enabled) =>
      AnalyticsEvent._('learning_opt_in', {'enabled': enabled});
  static const reviewInboxZero = AnalyticsEvent._('review_inbox_zero');

  /// `action`: added | removed | resized | moved. `widget`: a built-in
  /// widget kind. Never the dashboard's name.
  factory AnalyticsEvent.dashboardCustomised({
    required String action,
    required String widget,
  }) => AnalyticsEvent._('dashboard_customised', {
    'action': action,
    'widget': widget,
  });

  /// `type`: save | paydown. Never the name, the amount or the date.
  factory AnalyticsEvent.goalCreated(String type) =>
      AnalyticsEvent._('goal_created', {'type': type});
  static const goalCompleted = AnalyticsEvent._('goal_completed');

  /// Household planning. No names, amounts or member counts.
  static const householdCreated = AnalyticsEvent._('household_created');
  static const householdMemberJoined = AnalyticsEvent._(
    'household_member_joined',
  );

  /// `mode`: flex | category. Never a category, an amount or a month.
  factory AnalyticsEvent.budgetModeChanged(String mode) =>
      AnalyticsEvent._('budget_mode_changed', {'mode': mode});
  static const moneyMoved = AnalyticsEvent._('money_moved');

  /// Family vault. `type`: a vault entry type key. Never a name, a place or
  /// a value.
  factory AnalyticsEvent.vaultEntryAdded(String type) =>
      AnalyticsEvent._('vault_entry_added', {'type': type});

  /// `kind`: sheet | sealed.
  factory AnalyticsEvent.vaultExported(String kind) =>
      AnalyticsEvent._('vault_exported', {'kind': kind});

  /// You confirm a detected recurring payment. `cadence`: weekly |
  /// fortnightly | monthly | quarterly | yearly. Never the merchant or amount.
  factory AnalyticsEvent.recurringConfirmed(String cadence) =>
      AnalyticsEvent._('recurring_confirmed', {'cadence': cadence});

  /// You open a report. `view`: category | member. Never a category, a
  /// member, an amount or a month.
  factory AnalyticsEvent.reportViewed(String view) =>
      AnalyticsEvent._('report_viewed', {'view': view});
  static const budgetCreated = AnalyticsEvent._('budget_created');
  static const cardAdded = AnalyticsEvent._('card_added');

  // ---- Funnel milestones: each is sent once per install. ----
  static const firstCapture = AnalyticsEvent._('first_capture');
  static const firstCardAdded = AnalyticsEvent._('first_card_added');
  static const firstBudgetSet = AnalyticsEvent._('first_budget_set');
  static const firstSplitSettled = AnalyticsEvent._('first_split_settled');

  /// `bucket`: d1 | d7.
  factory AnalyticsEvent.appReturned(String bucket) =>
      AnalyticsEvent._('app_returned', {'bucket': bucket});

  // ---- Card check: right/wrong card after a captured payment. Never carries
  // amounts or merchants; the miss is bucketed. ----
  /// `result`: right | wrong.
  /// `merchant`: noon | talabat | careem | other. Nothing else is sent.
  factory AnalyticsEvent.receiptMatched(String merchant) =>
      AnalyticsEvent._('receipt_matched', {'merchant': merchant});

  factory AnalyticsEvent.cardCheckShown({
    required String result,
    required bool estimated,
  }) => AnalyticsEvent._('card_check_shown', {
    'result': result,
    'estimated': estimated,
  });

  /// `missed_bucket`: lt_5 | 5_20 | gt_20 (AED).
  factory AnalyticsEvent.cardCheckWrong({required String missedBucket}) =>
      AnalyticsEvent._('card_check_wrong', {'missed_bucket': missedBucket});
  factory AnalyticsEvent.cardRecommendationViewed(String category) =>
      AnalyticsEvent._('card_recommendation_viewed', {'category': category});

  /// Android capture permission results. `permission` is one of
  /// `sms_receive`, `sms_read`, `notification_access`.
  factory AnalyticsEvent.permissionGranted(String permission) =>
      AnalyticsEvent._('permission_granted', {'permission': permission});
  factory AnalyticsEvent.permissionDenied(String permission) =>
      AnalyticsEvent._('permission_denied', {'permission': permission});
  static const splitExpenseAdded = AnalyticsEvent._('split_expense_added');
  factory AnalyticsEvent.splitAutoSettled({
    required String match,
    required bool partial,
    required String direction,
  }) => AnalyticsEvent._('split_auto_settled', {
    'match': match,
    'partial': partial,
    'direction': direction,
  });
  static const splitSettleUndone = AnalyticsEvent._('split_settle_undone');
  factory AnalyticsEvent.splitSettleAsked({required String match}) =>
      AnalyticsEvent._('split_settle_asked', {'match': match});

  /// Manual entry is the exception; we measure how often it is needed.
  factory AnalyticsEvent.manualTransactionAdded({required String category}) =>
      AnalyticsEvent._('manual_transaction_added', {
        'category': _category(category),
      });

  // ---- Backup. Never carries amounts, names, file names or key material. ----

  /// `secret_kind`: phrase | passphrase. `destination`: cloud | file.
  factory AnalyticsEvent.backupEnabled({
    required String secretKind,
    required String destination,
  }) => AnalyticsEvent._('backup_enabled', {
    'secret_kind': secretKind,
    'destination': destination,
  });

  /// `trigger`: manual | auto | daily | setup. Size and time are bucketed.
  factory AnalyticsEvent.backupCompleted({
    required String trigger,
    required String sizeBucket,
    required int seconds,
  }) => AnalyticsEvent._('backup_completed', {
    'trigger': trigger,
    'size_bucket': sizeBucket,
    'duration': durationBucket(seconds),
  });

  /// `reason`: offline | signed_out | storage_full | provider_unavailable | keys_missing | other.
  factory AnalyticsEvent.backupFailed({
    required String trigger,
    required String reason,
  }) =>
      AnalyticsEvent._('backup_failed', {'trigger': trigger, 'reason': reason});
  static const backupExported = AnalyticsEvent._('backup_exported');
  static const backupPassphraseChanged = AnalyticsEvent._(
    'backup_passphrase_changed',
  );
  static const backupCloudDeleted = AnalyticsEvent._('backup_cloud_deleted');
  static const backupDisabled = AnalyticsEvent._('backup_disabled');

  // ---- Beta bug reports. Never carries the note, screenshot or log. ----

  /// `source`: shake | settings.
  factory AnalyticsEvent.bugReportOpened(String source) =>
      AnalyticsEvent._('bug_report_opened', {'source': source});

  /// `method`: local | issue.
  factory AnalyticsEvent.bugReportSent(String method) =>
      AnalyticsEvent._('bug_report_sent', {'method': method});
  // ---- Cross-device sync. Never carries rows, names, amounts or key
  // material; counts and times are bucketed. ----
  static const syncEnabled = AnalyticsEvent._('sync_enabled');

  /// `trigger`: manual | auto | resume.
  factory AnalyticsEvent.syncStarted({required String trigger}) =>
      AnalyticsEvent._('sync_started', {'trigger': trigger});

  /// `changes_bucket`: none | few | many (sent plus received).
  factory AnalyticsEvent.syncCompleted({
    required String trigger,
    required String changesBucket,
    required int seconds,
  }) => AnalyticsEvent._('sync_completed', {
    'trigger': trigger,
    'changes_bucket': changesBucket,
    'duration': durationBucket(seconds),
  });

  /// `reason`: offline | signed_out | too_new | integrity | keys_missing | other.
  factory AnalyticsEvent.syncFailed({
    required String trigger,
    required String reason,
  }) => AnalyticsEvent._('sync_failed', {'trigger': trigger, 'reason': reason});

  factory AnalyticsEvent.restoreStarted(String source) =>
      AnalyticsEvent._('restore_started', {'source': source});
  factory AnalyticsEvent.restoreCompleted(String source) =>
      AnalyticsEvent._('restore_completed', {'source': source});

  /// `reason`: wrong_passphrase | not_found | incomplete | corrupt | too_new | other.
  factory AnalyticsEvent.restoreFailed({
    required String source,
    required String reason,
  }) =>
      AnalyticsEvent._('restore_failed', {'source': source, 'reason': reason});
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
      // Nothing is captured behind the schema's back.
      ..captureApplicationLifecycleEvents = false
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
