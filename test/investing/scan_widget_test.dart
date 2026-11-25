import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/investing.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/attachments.dart';
import 'package:pulse/data/local/investing_store.dart';
import 'package:pulse/data/local/ocr_service.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/features/wealth/investing_screens.dart';
import 'package:pulse/features/wealth/scan_screens.dart';

import '../engine/capture_parser_test.dart' show brokerage, goldBill;

class _Picker implements PhotoPicker {
  @override
  Future<String?> pick(PhotoSource source) async => 'demo:0';
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  List<Override> overrides,
) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: PulseTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('scanning a gold bill shows what was read and saves it', (
    tester,
  ) async {
    final wealth = MemoryWealthStore();
    await _pump(tester, const ScanSheet(), [
      wealthStoreProvider.overrideWithValue(wealth),
      investingStoreProvider.overrideWithValue(MemoryInvestingStore()),
      photoPickerProvider.overrideWithValue(_Picker()),
      ocrServiceProvider.overrideWithValue(FakeOcr(goldBill)),
    ]);

    expect(find.text('Photos'), findsOneWidget);
    await tester.tap(find.text('Photos'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Looks like a gold bill'), findsOneWidget);
    expect(find.widgetWithText(TextField, '20.35'), findsOneWidget);
    expect(find.text('These figures are exact'), findsOneWidget);

    await tester.ensureVisible(find.text('Save 1 item'));
    await tester.pump();
    await tester.tap(find.text('Save 1 item'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final saved = (await wealth.jewellery()).single;
    expect(
      (saved.weightGrams, saved.karat, saved.purchasePriceMinor),
      (20.35, 22, 521850),
    );
    expect(saved.approximate, isFalse);
  });

  testWidgets('a typed description is saved as approximate gold', (
    tester,
  ) async {
    final wealth = MemoryWealthStore();
    await _pump(tester, const ScanSheet(), [
      wealthStoreProvider.overrideWithValue(wealth),
      investingStoreProvider.overrideWithValue(MemoryInvestingStore()),
      photoPickerProvider.overrideWithValue(_Picker()),
      ocrServiceProvider.overrideWithValue(FakeOcr('')),
    ]);
    await tester.enterText(
      find.byType(TextField).first,
      'about 20g 22k gold bought 2023',
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('bought around 2023'), findsOneWidget);

    await tester.ensureVisible(find.text('Save 1 item'));
    await tester.pump();
    await tester.tap(find.text('Save 1 item'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final saved = (await wealth.jewellery()).single;
    expect(
      (saved.weightGrams, saved.approximate, saved.purchaseDate?.year),
      (20, true, 2023),
    );
  });

  testWidgets('a portfolio screenshot lists each holding to confirm', (
    tester,
  ) async {
    final inv = MemoryInvestingStore();
    await _pump(tester, const ScanSheet(), [
      wealthStoreProvider.overrideWithValue(MemoryWealthStore()),
      investingStoreProvider.overrideWithValue(inv),
      photoPickerProvider.overrideWithValue(_Picker()),
      ocrServiceProvider.overrideWithValue(FakeOcr(brokerage)),
    ]);
    await tester.tap(find.text('Photos'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('3 holdings'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'VOO'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'AAPL'), findsOneWidget);
    await tester.ensureVisible(find.text('Save 3 items'));
    await tester.pump();
    await tester.tap(find.text('Save 3 items'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect((await inv.holdings()).map((h) => h.symbol), [
      'VOO',
      'AAPL',
      'TSLA',
    ]);
  });

  testWidgets(
    'investments and the plan show approximate holdings and a buy to confirm',
    (tester) async {
      final today = DateTime.now();
      final inv = MemoryInvestingStore(
        holdings: [
          StockHolding(
            id: 'h1',
            symbol: 'VOO',
            name: 'Vanguard S&P 500 ETF',
            quantity: 6.4,
            avgCost: 468.2,
            lastPrice: 512.3,
            priceAt: today,
            createdAt: today,
          ),
          StockHolding(
            id: 'h2',
            symbol: 'AAPL',
            name: 'Apple',
            quantity: 10,
            avgCost: 150,
            lastPrice: 225.1,
            priceAt: today,
            approximate: true,
            createdAt: today,
          ),
        ],
        rules: [
          InvestRule(
            id: 'r1',
            symbol: 'VOO',
            amountMinor: 20000,
            day: toDubaiDate(today).day,
            startDate: toDubaiDate(today).addDays(-40),
          ),
        ],
      );
      await _pump(
        tester,
        const Column(children: [InvestmentsSection(), InvestingPlanSection()]),
        [
          wealthStoreProvider.overrideWithValue(MemoryWealthStore()),
          investingStoreProvider.overrideWithValue(inv),
        ],
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Vanguard S&P 500 ETF'), findsOneWidget);
      expect(find.textContaining('approximate'), findsOneWidget); // AAPL only
      expect(find.text('Investing plan'), findsOneWidget);
      expect(find.textContaining('Did you buy'), findsWidgets);
      expect(find.text('Yes, bought'), findsWidgets);

      await tester.tap(find.text('Skipped').first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final skipped = (await inv.occurrences()).where(
        (o) => o.status == OccurrenceStatus.skipped,
      );
      expect(skipped, hasLength(1));
    },
  );
}
