import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/card_upsell_providers.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/cards/card_widgets.dart';
import 'package:pulse/features/cards/upsell_widgets.dart';

class _Rec implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  void screen(String name) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
  int count(String name) => events.where((e) => e.name == name).length;
}

CatalogCard entry(
  String id,
  double dining, {
  int fee = 0,
  int? minSalary,
  String issuer = 'Bank',
}) => CatalogCard(
  id: id,
  issuer: issuer,
  name: id,
  network: 'visa',
  annualFeeMinor: fee,
  minSalaryMinor: minSalary,
  rewardStructure: {
    'unit': 'cashback',
    'point_value_aed': 1,
    'base_rate': 0.01,
    'rules': [
      {
        'name': 'Dining',
        'categories': ['dining'],
        'rate': dining,
      },
    ],
  },
  perks: const {},
);

CreditCard display(String id, {bool owned = false, double dining = 1}) =>
    CreditCard(
      id: owned ? 'acct-$id' : id,
      issuer: 'Bank',
      name: id,
      last4: owned ? '1234' : '----',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF000000), Color(0xFF111111)],
      limit: 10000,
      balance: 0,
      dueDate: DateTime(2026, 12, 1),
      minDue: 0,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: {SpendCategory.dining: dining},
      catalogId: id,
    );

void main() {
  late _Rec rec;
  late MemoryKvStore kv;

  Future<void> open(
    WidgetTester tester, {
    List<CatalogCard>? catalog,
    List<CreditCard>? shown,
    Set<String> unavailable = const {},
  }) async {
    PulseTheme.useGoogleFonts = false;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rec = _Rec();
    kv = MemoryKvStore();
    final cat = catalog ?? [entry('mine', 0.02), entry('cand', 0.06)];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(rec),
          upsellPrefsProvider.overrideWithValue(UpsellPrefs(kv)),
          upsellCatalogProvider.overrideWith((ref) async => cat),
          upsellUnavailableIssuersProvider.overrideWithValue(unavailable),
          myCardsProvider.overrideWith(
            (ref) async => [display('mine', owned: true, dining: 2)],
          ),
          catalogProvider.overrideWith(
            (ref) async =>
                shown ??
                [display('mine', dining: 2), display('cand', dining: 6)],
          ),
          transactionsProvider.overrideWith(
            (ref) async => const <Transaction>[],
          ),
        ],
        child: MaterialApp(
          theme: PulseTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showHiddenSuggestions(context),
                      child: const Text('open hidden'),
                    ),
                  ),
                  const WhichCardSheet(initial: SpendCategory.dining),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets(
    'shows the best owned card first, then one quiet upsell with the figures',
    (tester) async {
      await open(tester);
      expect(find.text('Which card should I use?'), findsOneWidget);
      expect(find.text('Bank mine'), findsWidgets);
      expect(find.text("You'd earn more with..."), findsOneWidget);
      expect(find.text('Bank cand'), findsOneWidget);
      // 6% vs 2% on a typical AED 900 of dining: +36 a month, +432 a year.
      expect(
        find.textContaining('+AED 36 a month, +AED 432 a year'),
        findsOneWidget,
      );
      expect(find.textContaining('(estimate)'), findsOneWidget);
      // Owned answer comes before the upsell on screen.
      expect(
        tester.getTopLeft(find.text('Bank mine').first).dy,
        lessThan(tester.getTopLeft(find.text("You'd earn more with...")).dy),
      );
      expect(rec.count('card_suggestion_shown'), 1);
      expect(rec.events.last.properties, {'surface': 'which_card'});
    },
  );

  testWidgets('the fee is netted off the figure', (tester) async {
    await open(
      tester,
      catalog: [entry('mine', 0.02), entry('cand', 0.06, fee: 12000)],
    );
    // 432 - 120 = 312 a year, 26 a month.
    expect(
      find.textContaining(
        '+AED 26 a month, +AED 312 a year, after the AED 120 annual fee',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'nothing shows when the gain is not meaningful, or the card is out of reach',
    (tester) async {
      await open(tester, catalog: [entry('mine', 0.02), entry('cand', 0.021)]);
      expect(find.text("You'd earn more with..."), findsNothing);
      expect(rec.count('card_suggestion_shown'), 0);

      await open(
        tester,
        catalog: [entry('mine', 0.02), entry('cand', 0.06, minSalary: 3000000)],
      );
      expect(find.text("You'd earn more with..."), findsNothing);

      await open(
        tester,
        catalog: [
          entry('mine', 0.02),
          entry('cand', 0.06, issuer: 'Bank'),
        ],
        unavailable: {'bank'},
      );
      expect(find.text("You'd earn more with..."), findsNothing);
    },
  );

  testWidgets('tapping opens the details and logs the tap', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const Key('upsell_row')));
    await settle(tester);
    expect(find.text('An estimate, not a promise'), findsOneWidget);
    expect(find.text('Extra a year, after fee'), findsOneWidget);
    expect(
      find.textContaining('typical month rather than yours'),
      findsOneWidget,
    );
    expect(rec.count('card_suggestion_tapped'), 1);
  });

  testWidgets(
    'Not interested hides it, remembers it, and Settings can undo it',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Not interested'));
      await settle(tester);
      expect(find.text("You'd earn more with..."), findsNothing);
      expect(await kv.read(UpsellPrefs.dismissedKey), '["cand"]');

      // The hidden list names it and "Show again" brings it back.
      await tester.tap(find.text('open hidden'));
      await settle(tester);
      expect(find.text('Bank cand'), findsOneWidget);
      await tester.tap(find.text('Show again'));
      await settle(tester);
      expect(find.text('Nothing hidden.'), findsOneWidget);
      expect(await kv.read(UpsellPrefs.dismissedKey), isNull);
      expect(await UpsellPrefs(kv).dismissed(), isEmpty);
    },
  );

  testWidgets(
    'a dismissal is persisted for the next launch',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Not interested'));
      await settle(tester);
      final saved = await kv.read(UpsellPrefs.dismissedKey);
      expect(await UpsellPrefs(kv).dismissed(), {'cand'});
      expect(saved, isNotNull);
      // The only candidate is dismissed, so nothing replaces it.
      expect(find.text("You'd earn more with..."), findsNothing);
    },
  );

  test('salary estimate: largest recent month, ignores old, excluded and non-salary', () {
    final now = DateTime(2026, 11, 25);
    Transaction t(
      double amt,
      int daysAgo, {
      SpendCategory cat = SpendCategory.salary,
      bool excluded = false,
    }) => Transaction(
      id: '$amt$daysAgo',
      merchant: 'x',
      amount: amt,
      category: cat,
      date: now.subtract(Duration(days: daysAgo)),
      source: TxSource.sms,
      cardId: 'c',
      accountLabel: 'a',
      isIncome: true,
      excluded: excluded,
    );
    expect(estimateSalaryMinor(const [], now), isNull);
    expect(
      estimateSalaryMinor([t(15000, 3), t(14000, 33), t(99999, 120)], now),
      1500000,
    );
    expect(
      estimateSalaryMinor([
        t(5000, 3, cat: SpendCategory.shopping),
        t(7000, 5, excluded: true),
      ], now),
      isNull,
    );
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}
