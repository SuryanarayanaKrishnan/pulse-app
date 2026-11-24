import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/household/household_keys.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/demo_household.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/recurring_providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/household/household_providers.dart';

import '../../support/recurring_fixtures.dart';
import '../recurring/recurring_widget_test.dart' show Rec;

Future<void> open(WidgetTester tester, Rec rec, {bool household = false}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final store = household ? await demoJoinedHousehold(() async => [], now: DateTime(2026, 11, 14)) : null;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(MockPulseRepository(latency: Duration.zero)),
        transactionsProvider.overrideWith((ref) async => syntheticLedger()),
        recurringTodayProvider.overrideWithValue(fixtureToday),
        analyticsProvider.overrideWithValue(rec),
        kvStoreProvider.overrideWithValue(MemoryKvStore()),
        sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
        if (store != null) ...[
          householdStoreProvider.overrideWithValue(store),
          householdKeyStoreProvider.overrideWithValue(MemoryHouseholdKeyStore()..key = Uint8List.fromList(List.filled(32, 7))),
        ],
      ],
      child: const PulseApp(initialLocation: '/reports'),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  testWidgets('shows the month as a treemap with the biggest category first, and counts one view', (tester) async {
    final rec = Rec();
    await open(tester, rec);
    expect(find.text('Reports'), findsWidgets);
    expect(find.byKey(const Key('treemap')), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.byKey(const Key('report_row_rent')), findsOneWidget);
    final views = rec.events.where((e) => e.name == 'report_viewed').toList();
    expect(views, hasLength(1));
    expect(views.single.properties, {'view': 'category'});
    // No member control outside a household.
    expect(find.text('By member'), findsNothing);
  });

  testWidgets('tapping a tile selects its category; See payments opens Activity filtered by it', (tester) async {
    await open(tester, Rec());
    final box = tester.getRect(find.byKey(const Key('treemap')));
    // Rent is by far the biggest slice, so it owns the top-left corner.
    await tester.tapAt(box.topLeft + const Offset(20, 20));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('report_selected')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('report_selected')), matching: find.text('Rent & Housing')), findsOneWidget);
    await tester.tap(find.text('See payments'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Activity'), findsWidgets);
  });

  testWidgets('range chips and the month arrows change the period', (tester) async {
    await open(tester, Rec());
    await tester.tap(find.text('3M'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Sep 2026 to Nov 2026'), findsOneWidget);
    await tester.tap(find.text('Month'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('Earlier'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.byKey(const Key('treemap')), findsOneWidget);
    // Can not go past the current month.
    await tester.tap(find.bySemanticsLabel('Later'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.bySemanticsLabel('Later'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('an empty period says so', (tester) async {
    await open(tester, Rec());
    for (var i = 0; i < 11; i++) {
      await tester.tap(find.bySemanticsLabel('Earlier'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Nothing spent in this period'), findsOneWidget);
  });

  testWidgets('in a household there is a by-member view from the shared log, and it is counted as such', (tester) async {
    final rec = Rec();
    await open(tester, rec, household: true);
    expect(find.text('By member'), findsOneWidget);
    await tester.tap(find.text('By member'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Household spent'), findsOneWidget);
    expect(find.byKey(const Key('treemap')), findsOneWidget);
    expect(find.text('Omar'), findsWidgets);
    expect(find.textContaining('Private payments are never counted'), findsOneWidget);
    final props = rec.events.where((e) => e.name == 'report_viewed').map((e) => e.properties['view']).toList();
    expect(props, ['category', 'member']);
  });
}
