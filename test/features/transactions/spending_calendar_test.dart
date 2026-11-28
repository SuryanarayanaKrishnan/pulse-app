import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/transactions/spending_calendar.dart';

Transaction _tx(
  String id,
  String m,
  double a,
  DateTime d, {
  bool income = false,
  bool excluded = false,
}) => Transaction(
  id: id,
  merchant: m,
  amount: a,
  category: SpendCategory.groceries,
  date: d,
  source: TxSource.sms,
  cardId: 'c',
  accountLabel: 'Card',
  isIncome: income,
  excluded: excluded,
);

void main() {
  final txs = [
    _tx('1', 'Spinneys', 100, DateTime(2026, 11, 10, 9)),
    _tx('2', 'Carrefour', 50.5, DateTime(2026, 11, 10, 18)),
    _tx('3', 'Salary', 9000, DateTime(2026, 11, 25), income: true),
    _tx('4', 'Hidden', 70, DateTime(2026, 11, 12), excluded: true),
    _tx('5', 'Noon', 30, DateTime(2026, 10, 31, 23)),
  ];

  test('dailySpend sums per day and skips income and excluded', () {
    final m = dailySpend(txs);
    expect(m[DateTime(2026, 11, 10)], 150.5);
    expect(m.containsKey(DateTime(2026, 11, 25)), isFalse);
    expect(m.containsKey(DateTime(2026, 11, 12)), isFalse);
    expect(m[DateTime(2026, 10, 31)], 30);
  });

  testWidgets('month totals, tap a day, change month', (t) async {
    PulseTheme.useGoogleFonts = false;
    t.view.physicalSize = const Size(360 * 3, 800 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            MockPulseRepository(latency: Duration.zero),
          ),
        ],
        child: MaterialApp(
          theme: PulseTheme.light,
          home: Scaffold(
            body: SpendingCalendar(
              transactions: txs,
              today: DateTime(2026, 11, 28),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('AED 151 spent'), findsOneWidget);
    // Today is selected and empty.
    expect(find.byKey(const Key('cal_day_empty')), findsOneWidget);

    await t.tap(find.byKey(const Key('cal_day_10')));
    await t.pumpAndSettle();
    expect(find.text('Spinneys'), findsOneWidget);
    expect(find.text('Carrefour'), findsOneWidget);
    expect(find.text('AED 150.50'), findsOneWidget);

    await t.tap(find.byKey(const Key('cal_prev')));
    await t.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('AED 30 spent'), findsOneWidget);
    await t.tap(find.byKey(const Key('cal_day_31')));
    await t.pumpAndSettle();
    expect(find.text('Noon'), findsOneWidget);
  });
}
