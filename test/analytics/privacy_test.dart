import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/analytics/gated_analytics.dart';
import 'package:pulse/core/analytics/privacy_controller.dart';
import 'package:pulse/data/models.dart';

class Sink implements Analytics {
  final events = <AnalyticsEvent>[];
  final screens = <String>[];
  final identified = <String>[];
  var resets = 0;
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  void screen(String name) => screens.add(name);
  @override
  void identify(String userId) => identified.add(userId);
  @override
  void reset() => resets++;
}

({Sink sink, PrivacyController privacy, GatedAnalytics gate}) setup({
  bool on = true,
  DateTime Function()? clock,
}) {
  final sink = Sink();
  final privacy = PrivacyController(MemoryKvStore(), clock: clock);
  if (on) privacy.setSharing(true);
  return (sink: sink, privacy: privacy, gate: GatedAnalytics(sink, privacy));
}

/// Every event the app can build, to push through the gate.
List<AnalyticsEvent> everyEvent() => [
  AnalyticsEvent.onboardingStarted,
  AnalyticsEvent.onboardingCompleted,
  AnalyticsEvent.onboardingStepCompleted('intro_1'),
  AnalyticsEvent.tourStarted,
  AnalyticsEvent.tourStepViewed('right_card'),
  AnalyticsEvent.tourSkipped('net_worth'),
  AnalyticsEvent.tourCompleted,
  AnalyticsEvent.signupCompleted,
  AnalyticsEvent.sourceConnected('gmail'),
  AnalyticsEvent.statementUploaded,
  AnalyticsEvent.transactionRecategorized(from: 'dining', to: 'My Secret Club'),
  AnalyticsEvent.recategoriseScope('all'),
  AnalyticsEvent.dashboardCustomised(action: 'moved', widget: 'net_worth'),
  AnalyticsEvent.budgetCreated,
  AnalyticsEvent.cardAdded,
  AnalyticsEvent.firstCapture,
  AnalyticsEvent.firstCardAdded,
  AnalyticsEvent.firstBudgetSet,
  AnalyticsEvent.firstSplitSettled,
  AnalyticsEvent.appReturned('d1'),
  AnalyticsEvent.cardCheckShown(result: 'wrong', estimated: true),
  AnalyticsEvent.cardCheckWrong(missedBucket: 'lt_5'),
  AnalyticsEvent.cardRecommendationViewed('detail'),
  AnalyticsEvent.permissionGranted('sms_read'),
  AnalyticsEvent.permissionDenied('sms_receive'),
  AnalyticsEvent.splitExpenseAdded,
  AnalyticsEvent.splitAutoSettled(match: 'phone', partial: false, direction: 'debit'),
  AnalyticsEvent.splitSettleUndone,
  AnalyticsEvent.splitSettleAsked(match: 'iban'),
  AnalyticsEvent.manualTransactionAdded(category: 'groceries'),
  AnalyticsEvent.backupEnabled(secretKind: 'phrase', destination: 'cloud'),
  AnalyticsEvent.backupCompleted(trigger: 'auto', sizeBucket: '<1MB', seconds: 12),
  AnalyticsEvent.backupFailed(trigger: 'manual', reason: 'offline'),
  AnalyticsEvent.backupExported,
  AnalyticsEvent.backupPassphraseChanged,
  AnalyticsEvent.backupCloudDeleted,
  AnalyticsEvent.backupDisabled,
  AnalyticsEvent.bugReportOpened('shake'),
  AnalyticsEvent.bugReportOpened('settings'),
  AnalyticsEvent.bugReportSent('local'),
  AnalyticsEvent.bugReportSent('issue'),
  AnalyticsEvent.syncEnabled,
  AnalyticsEvent.syncStarted(trigger: 'resume'),
  AnalyticsEvent.syncCompleted(trigger: 'auto', changesBucket: 'few', seconds: 3),
  AnalyticsEvent.syncFailed(trigger: 'manual', reason: 'too_new'),
  AnalyticsEvent.restoreStarted('file'),
  AnalyticsEvent.restoreCompleted('cloud'),
  AnalyticsEvent.restoreFailed(source: 'cloud', reason: 'corrupt'),
  AnalyticsEvent.learningOptIn(true),
  AnalyticsEvent.learningOptIn(false),
  AnalyticsEvent.reviewSwiped('right'),
  AnalyticsEvent.reviewSwiped('left'),
  AnalyticsEvent.reviewInboxZero,
  AnalyticsEvent.goalCreated('save'),
  AnalyticsEvent.goalCreated('paydown'),
  AnalyticsEvent.goalCompleted,
  AnalyticsEvent.householdCreated,
  AnalyticsEvent.householdMemberJoined,
  AnalyticsEvent.budgetModeChanged('flex'),
  AnalyticsEvent.budgetModeChanged('category'),
  AnalyticsEvent.moneyMoved,
  AnalyticsEvent.budgetSuggested(history: true),
  AnalyticsEvent.budgetImported(source: 'link', history: false, items: 'few'),
  AnalyticsEvent.receiptMatched('noon'),
  AnalyticsEvent.receiptMatched('talabat'),
  AnalyticsEvent.receiptMatched('careem'),
  AnalyticsEvent.receiptMatched('other'),
  AnalyticsEvent.vaultEntryAdded('bank'),
  AnalyticsEvent.vaultEntryAdded('insurance'),
  AnalyticsEvent.vaultExported('sheet'),
  AnalyticsEvent.vaultExported('sealed'),
  AnalyticsEvent.recurringConfirmed('monthly'),
  AnalyticsEvent.recurringConfirmed('yearly'),
  AnalyticsEvent.reportViewed('category'),
  AnalyticsEvent.reportViewed('member'),
];

void main() {
  group('schema', () {
    test('every event the app builds is listed, and the list has no extras', () {
      final built = everyEvent().map((e) => e.name).toSet();
      final listed = AnalyticsSchema.events.map((e) => e.name).toSet();
      expect(listed, built);
      expect(AnalyticsSchema.events.length, listed.length, reason: 'no duplicates');
    });

    test('every built event survives the schema untouched (properties match)', () {
      for (final e in everyEvent()) {
        if (e.name == 'transaction_recategorized') continue; // custom -> custom
        expect(AnalyticsSchema.clean(e.name, e.properties), e.properties, reason: e.name);
      }
    });

    test('the listing describes exactly the properties the events carry', () {
      for (final e in everyEvent()) {
        final spec = AnalyticsSchema.specFor(e.name)!;
        expect(spec.props.keys.toSet(), e.properties.keys.toSet(), reason: e.name);
      }
    });

    test('category values track the app categories; custom ones are masked', () {
      final ids = SpendCategory.defaults.map((c) => c.id).toSet();
      expect(AnalyticsSchema.categories.toSet(), {...ids, 'custom'});
      final e = AnalyticsEvent.manualTransactionAdded(category: 'Dad birthday gifts');
      expect(e.properties['category'], 'custom');
    });

    test('durations are buckets, not seconds', () {
      expect(AnalyticsEvent.durationBucket(2), 'lt_5s');
      expect(AnalyticsEvent.durationBucket(29), '5_30s');
      expect(AnalyticsEvent.durationBucket(100), '30_120s');
      expect(AnalyticsEvent.durationBucket(9999), 'gt_120s');
    });

    test('properties can only be fixed choices or yes/no', () {
      for (final e in AnalyticsSchema.events) {
        for (final p in e.props.values) {
          expect(p is EnumProp || p is BoolProp, isTrue);
          if (p is EnumProp) {
            expect(p.values, isNotEmpty);
            for (final v in p.values) {
              expect(v.length, lessThan(24), reason: 'a choice, never free text');
            }
          }
        }
      }
    });
  });

  group('private values never reach the sink', () {
    test('free-text, amounts, merchants and names in properties are dropped', () {
      final t = setup();
      t.gate.track(const AnalyticsEvent.unchecked('card_check_shown', {
        'result': 'wrong',
        'estimated': true,
        'merchant': 'Carrefour Dubai Mall',
        'amount': 123.45,
        'name': 'Aisha Rahman',
        'contact': '+971501234567',
        'message': 'Your card ending 1234 was charged AED 99',
      }));
      expect(t.sink.events, hasLength(1));
      expect(t.sink.events.single.properties, {'result': 'wrong', 'estimated': true});
    });

    test('a value outside the allowed choices is dropped, not forwarded', () {
      final t = setup();
      t.gate.track(const AnalyticsEvent.unchecked('source_connected', {'type': 'Carrefour'}));
      t.gate.track(const AnalyticsEvent.unchecked('card_check_wrong', {'missed_bucket': '37.50'}));
      t.gate.track(const AnalyticsEvent.unchecked('card_check_shown', {'result': 'right', 'estimated': 'yes'}));
      for (final e in t.sink.events) {
        expect(e.properties.values.every((v) => v != 'Carrefour' && v != '37.50' && v != 'yes'), isTrue);
      }
      expect(t.sink.events[0].properties, isEmpty);
      expect(t.sink.events[1].properties, isEmpty);
      expect(t.sink.events[2].properties, {'result': 'right'});
    });

    test('unknown events are dropped', () {
      final t = setup();
      t.gate.track(const AnalyticsEvent.unchecked('merchant_viewed', {'merchant': 'Noon'}));
      t.gate.track(const AnalyticsEvent.unchecked('transaction_added', {'amount': 10.0}));
      expect(t.sink.events, isEmpty);
    });

    test('nothing the sink receives contains a planted private string', () {
      final t = setup();
      const secrets = ['Carrefour', 'Aisha', '+9715', '99.50'];
      for (final key in ['merchant', 'name', 'phone', 'amount', 'note', 'step', 'type', 'category']) {
        for (final s in secrets) {
          for (final spec in AnalyticsSchema.events) {
            t.gate.track(AnalyticsEvent.unchecked(spec.name, {key: s}));
          }
        }
      }
      for (final e in t.sink.events) {
        for (final v in e.properties.values) {
          for (final s in secrets) {
            expect('$v'.contains(s), isFalse, reason: '${e.name} leaked $s');
          }
        }
      }
    });

    test('account ids never reach the sink', () {
      final t = setup();
      t.gate.identify('user-42@example.com');
      t.gate.track(AnalyticsEvent.budgetCreated);
      expect(t.sink.identified, hasLength(1));
      expect(t.sink.identified.single, isNot(contains('user-42')));
    });

    test('screens with ids in the path are not reported', () {
      final t = setup();
      t.gate.screen('/group/abc123');
      t.gate.screen('/document/passport-scan');
      t.gate.screen('/home');
      expect(t.sink.screens, ['/home']);
    });
  });

  group('opt-out', () {
    test('default is off: nothing is sent, not even after the event', () {
      final t = setup(on: false);
      expect(t.privacy.sharing, isFalse);
      for (final e in everyEvent()) {
        t.gate.track(e);
      }
      t.gate.screen('/home');
      expect(t.sink.events, isEmpty);
      expect(t.sink.screens, isEmpty);
      expect(t.sink.identified, isEmpty);
    });

    test('turning sharing off drops everything and forgets the id', () async {
      final t = setup();
      t.gate.track(AnalyticsEvent.budgetCreated);
      expect(t.sink.events, hasLength(1));
      await t.privacy.setSharing(false);
      expect(t.sink.resets, 1);
      expect(t.privacy.installId, isNull);
      for (final e in everyEvent()) {
        t.gate.track(e);
      }
      t.gate.screen('/home');
      expect(t.sink.events, hasLength(1));
      expect(t.sink.screens, isEmpty);
    });

    test('declining the question keeps it off', () async {
      final t = setup(on: false);
      await t.privacy.setSharing(false);
      expect(t.privacy.asked, isTrue);
      t.gate.track(AnalyticsEvent.cardAdded);
      expect(t.sink.events, isEmpty);
    });

    test('a saved choice is restored; a saved id is not kept without consent', () async {
      final kv = MemoryKvStore()
        ..data[PrivacyController.consentKey] = 'declined'
        ..data[PrivacyController.idKey] = 'leftover';
      final p = PrivacyController(kv);
      await p.load();
      expect(p.sharing, isFalse);
      expect(p.installId, isNull);
      final on = PrivacyController(MemoryKvStore()..data[PrivacyController.consentKey] = 'granted');
      await on.load();
      expect(on.sharing, isTrue);
    });
  });

  group('anonymous id', () {
    test('is random, not derived from anything, and differs per install', () {
      final a = setup().privacy.installId!;
      final b = setup().privacy.installId!;
      expect(a, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(a, isNot(b));
      // Seeded randomness only decides the bytes; the clock plays no part.
      final x = PrivacyController(MemoryKvStore(), random: Random(1))..setSharing(true);
      final y = PrivacyController(MemoryKvStore(), random: Random(1), clock: () => DateTime(2030))..setSharing(true);
      expect(x.installId, y.installId);
    });

    test('reset gives a new id and the backend starts fresh', () {
      final t = setup();
      t.gate.track(AnalyticsEvent.budgetCreated);
      final first = t.privacy.installId;
      t.privacy.resetId();
      expect(t.privacy.installId, isNot(first));
      expect(t.sink.resets, 1);
      t.gate.track(AnalyticsEvent.cardAdded);
      expect(t.sink.identified, [first, t.privacy.installId]);
    });

    test('rotates by itself after its lifetime', () {
      var now = DateTime(2026, 1, 1);
      final t = setup(clock: () => now);
      final first = t.privacy.installId;
      now = now.add(const Duration(days: 30));
      expect(t.privacy.installId, first);
      now = now.add(const Duration(days: 61));
      expect(t.privacy.installId, isNot(first));
    });
  });

  group('funnel', () {
    test('first_* milestones are sent once', () {
      final t = setup();
      t.gate.track(AnalyticsEvent.firstCardAdded);
      t.gate.track(AnalyticsEvent.firstCardAdded);
      t.gate.track(AnalyticsEvent.firstCapture);
      expect(t.sink.events.map((e) => e.name), ['first_card_added', 'first_capture']);
    });

    test('a milestone reached before opting in is not sent later', () {
      final t = setup(on: false);
      t.gate.track(AnalyticsEvent.firstBudgetSet);
      t.privacy.setSharing(true);
      t.gate.track(AnalyticsEvent.firstBudgetSet);
      expect(t.sink.events, isEmpty);
    });

    test('d1 and d7 return buckets fire once, and only while sharing', () {
      var now = DateTime(2026, 3, 1, 10);
      final t = setup(clock: () => now);
      expect(t.privacy.returnBucket(), isNull); // first open
      expect(t.privacy.returnBucket(), isNull); // same day
      now = DateTime(2026, 3, 2, 9);
      expect(t.privacy.returnBucket(), 'd1');
      expect(t.privacy.returnBucket(), isNull);
      now = DateTime(2026, 3, 9, 9);
      expect(t.privacy.returnBucket(), 'd7');
      expect(t.privacy.returnBucket(), isNull);
      final off = setup(on: false, clock: () => now);
      off.privacy.returnBucket();
      now = DateTime(2026, 3, 10);
      expect(off.privacy.returnBucket(), isNull);
    });
  });
}
