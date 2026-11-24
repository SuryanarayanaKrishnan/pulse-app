import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart' show Transaction;
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/recurring_providers.dart';
import 'package:pulse/features/auth/session.dart';

import '../../support/recurring_fixtures.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

List<Override> overrides(Rec rec, {List<Transaction>? ledger}) => [
  repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero)),
  transactionsProvider.overrideWith((ref) async => ledger ?? syntheticLedger()),
  myCardsProvider.overrideWith((ref) async => []),
  recurringTodayProvider.overrideWithValue(fixtureToday),
  analyticsProvider.overrideWithValue(rec),
  kvStoreProvider.overrideWithValue(MemoryKvStore()),
  sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
];

Future<void> open(WidgetTester tester, Rec rec, {String at = '/recurring', List<Transaction>? ledger}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: overrides(rec, ledger: ledger), child: PulseApp(initialLocation: at)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.4);
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('groups by status and shows what is committed this month', (tester) async {
    await open(tester, Rec());
    expect(find.text('Recurring'), findsWidgets);
    expect(find.text('Committed this month'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Paid'), findsOneWidget);
    expect(find.text('Powergrid'), findsOneWidget); // overdue
    await reveal(tester, find.text('FitBox Gym'));
    expect(find.text('FitBox Gym'), findsOneWidget);
    // One-offs are not in the list.
    expect(find.text('Corner Cafe'), findsNothing);
    expect(find.text('Gadget Shop'), findsNothing);
  });

  testWidgets('price rises are called out', (tester) async {
    await open(tester, Rec());
    expect(find.text('Price rises'), findsOneWidget);
    expect(find.textContaining('Cloudbox Storage went up 25%'), findsOneWidget);
    expect(find.textContaining('36 more a year'), findsOneWidget);
  });

  testWidgets('the calendar shows a dot on due days and the day list below', (tester) async {
    await open(tester, Rec());
    await tester.tap(find.text('Calendar'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('recurring_calendar')), findsOneWidget);
    expect(find.byKey(const Key('cal_dot')), findsWidgets);
    // Today is the 14th; nothing is due. Tap the 28th: the gym.
    await tester.tap(find.byKey(const Key('cal_day_28')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('FitBox Gym'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cal_day_10')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Powergrid'), findsOneWidget);
  });

  testWidgets('the detail sheet shows history and next date; confirming is remembered and counted', (tester) async {
    final rec = Rec();
    await open(tester, rec);
    await reveal(tester, find.text('Cloudbox Storage').last);
    await tester.tap(find.text('Cloudbox Storage').last);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('rec_next')), findsOneWidget);
    expect(find.textContaining('Next expected 22 Nov'), findsOneWidget);
    expect(find.byKey(const Key('rec_history')), findsOneWidget);
    await tester.tap(find.text('Yes, this is recurring'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(rec.events.map((e) => e.name), contains('recurring_confirmed'));
    expect(rec.events.firstWhere((e) => e.name == 'recurring_confirmed').properties, {'cadence': 'monthly'});
    expect(find.textContaining('confirmed'), findsWidgets);
  });

  testWidgets('not recurring hides the series and totals shrink; it can be shown again', (tester) async {
    await open(tester, Rec());
    expect(find.text('Powergrid'), findsOneWidget);
    await tester.tap(find.text('Powergrid'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Not recurring'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Powergrid'), findsNothing);
    expect(find.text('Overdue'), findsNothing);
    await reveal(tester, find.byKey(const Key('rec_hidden')));
    expect(find.text('1 hidden'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rec_hidden')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Show'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Powergrid'), findsOneWidget);
  });

  testWidgets('months can be browsed: the next month projects the same bills', (tester) async {
    await open(tester, Rec());
    await tester.tap(find.bySemanticsLabel('Next month'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('December 2026'), findsOneWidget);
    expect(find.text('Paid'), findsNothing);
    expect(find.text('Upcoming'), findsOneWidget);
  });

  testWidgets('with no history it explains itself instead of showing nothing', (tester) async {
    await open(tester, Rec(), ledger: []);
    expect(find.text('Nothing recurring yet'), findsOneWidget);
  });

  testWidgets('Budget links to Recurring and Reports', (tester) async {
    await open(tester, Rec(), at: '/budget');
    await reveal(tester, find.byKey(const Key('manage_recurring')));
    expect(find.byKey(const Key('manage_reports')), findsOneWidget);
    await tester.tap(find.byKey(const Key('manage_recurring')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Committed this month'), findsOneWidget);
  });
}
