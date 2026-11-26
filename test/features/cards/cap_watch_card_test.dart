import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/engine/cap_tracker.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/next_best.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/cap_providers.dart';
import 'package:pulse/features/cards/cap_watch_card.dart';

CardCapStatus _status(double earned) => CardCapStatus(
  cardId: 'sib',
  title: 'SIB Cashback',
  cycleStart: const CalDate(2026, 11, 1),
  cycleEnd: const CalDate(2026, 11, 30),
  basis: CycleBasis.calendar,
  spendAed: 3000,
  earnedAed: earned,
  meters: [
    CapMeter(
      id: 'total',
      label: 'Monthly cap',
      isTotal: true,
      capAed: 300,
      earnedAed: earned,
      rate: 0.1,
      spentAed: 3000,
      categories: const {},
      approxSpend: true,
      isCashback: true,
    ),
  ],
);

NextBestPlan _plan() => const NextBestPlan(
  forecast: SpendForecast(
    remainingMinor: {'general': 50000},
    basis: ForecastBasis.history,
    cycles: 4,
    volatile: false,
    confidence: ForecastConfidence.medium,
    note: 'Based on your last 4 months of spending',
  ),
  held: null,
  heldValueMinor: 0,
  heldByCategory: {},
  getCards: [],
  reason: 'You usually spend about AED 500 after the cap.',
);

Future<void> _pump(
  WidgetTester tester,
  List<CardCapStatus> watch,
  NextBestPlan? plan, {
  double scale = 1.0,
  Brightness b = Brightness.light,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(360 * 3, 800 * 3);
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        capWatchProvider.overrideWith((ref) async => watch),
        capNotifyProvider.overrideWith((ref) async {}),
        nextBestProvider.overrideWith((ref) async => plan),
      ],
      child: MaterialApp(
        theme: b == Brightness.dark ? PulseTheme.dark : PulseTheme.light,
        home: Scaffold(body: ListView(children: const [CapWatchCard()])),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('hidden when nothing is near a cap', (tester) async {
    await _pump(tester, const [], null);
    expect(find.byKey(const Key('cap_watch')), findsNothing);
  });

  testWidgets('near a cap shows what is left, no next-best yet', (
    tester,
  ) async {
    await _pump(tester, [_status(260)], null);
    expect(find.text('Close to a cashback cap'), findsOneWidget);
    expect(find.textContaining('cashback left'), findsOneWidget);
    expect(find.byKey(const Key('cap_next_best')), findsNothing);
  });

  for (final b in Brightness.values) {
    testWidgets(
      'cap hit shows the reason and the caveat (${b.name}, 360px, 1.5x)',
      (tester) async {
        await _pump(tester, [_status(300)], _plan(), scale: 1.5, b: b);
        expect(find.text('Cashback cap reached'), findsOneWidget);
        expect(find.textContaining('Cap reached'), findsOneWidget);
        expect(find.byKey(const Key('cap_next_best')), findsOneWidget);
        expect(find.textContaining('about AED 500'), findsOneWidget);
        expect(find.textContaining('not a guarantee'), findsOneWidget);
        expect(find.textContaining('last 4 months'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
