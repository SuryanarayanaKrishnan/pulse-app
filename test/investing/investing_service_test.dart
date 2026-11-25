import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/capture_parser.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/investing.dart';
import 'package:pulse/data/investing_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/investing_store.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/data/wealth_service.dart';

import '../engine/capture_parser_test.dart' show brokerage, goldBill;

/// Stock prices without a network.
class _Quotes extends StockQuoteService {
  _Quotes(this.prices) : super(null);
  Map<String, double> prices;
  @override
  bool get available => true;
  @override
  Future<Map<String, StockQuote>> fetch(Iterable<String> symbols) async => {
    for (final s in symbols)
      if (prices[s.toUpperCase()] != null)
        s.toUpperCase(): StockQuote(
          symbol: s.toUpperCase(),
          price: prices[s.toUpperCase()]!,
        ),
  };
}

({
  InvestingService svc,
  MemoryInvestingStore store,
  WealthStore wealthStore,
  _Quotes quotes,
})
build(DateTime now) {
  final ws = MemoryWealthStore();
  final store = MemoryInvestingStore();
  final wealth = WealthService(
    investing: store,
    store: ws,
    prices: PriceService(store: ws, clock: () => now),
    fundLookup: FundLookup(null),
    clock: () => now,
  );
  final quotes = _Quotes({'VOO': 520, 'AAPL': 230});
  final svc = InvestingService(
    store: store,
    wealth: wealth,
    quotes: quotes,
    clock: () => now,
  );
  return (svc: svc, store: store, wealthStore: ws, quotes: quotes);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final now = DateTime.utc(2026, 11, 25, 8);

  test(
    'a gold bill scan becomes a jewellery piece valued from the gold price',
    () async {
      final t = build(now);
      final report = await t.svc.applyCapture(parseCapture(goldBill));
      expect(report.goldAdded, 1);
      final item = (await t.wealthStore.jewellery()).single;
      expect(
        (item.weightGrams, item.karat, item.purchasePriceMinor),
        (20.35, 22, 521850),
      );
      expect(item.purchaseDate, const CalDate(2023, 3, 14));
      expect(item.approximate, isFalse);
    },
  );

  test('an approximate gold entry is saved flagged', () async {
    final t = build(now);
    await t.svc.applyCapture(
      parseApproximate('about 20g 22k gold bought 2023'),
    );
    final item = (await t.wealthStore.jewellery()).single;
    expect(item.approximate, isTrue);
    expect(item.weightGrams, 20);
    expect(item.notes, contains('2023'));
  });

  test(
    'a portfolio scan saves positions priced from the live quote, P&L included',
    () async {
      final t = build(now);
      final report = await t.svc.applyCapture(parseCapture(brokerage));
      expect((report.holdingsAdded, report.skipped), (3, 0));
      final views = await t.svc.holdingViews();
      final voo = views.firstWhere((v) => v.holding.symbol == 'VOO');
      expect(
        voo.holding.lastPrice,
        520,
      ); // refreshed, not the screenshot's 512.30
      expect(voo.value.valueNativeMinor, 130000); // 2.5 x 520
      expect(voo.value.gainPct, closeTo((520 - 410.20) / 410.20 * 100, 0.01));
      expect(voo.value.valueAedMinor, isNotNull);
      // TSLA has no quote in the fake: keeps the screenshot's implied price.
      final tsla = views.firstWhere((v) => v.holding.symbol == 'TSLA');
      expect(tsla.holding.lastPrice, 240);
      expect(tsla.value.gainPct, isNull); // no cost seen -> no made-up P&L
    },
  );

  test('scanning the same ticker again replaces the position instead of doubling it', () async {
    final t = build(now);
    await t.svc.applyCapture(parseApproximate('50 shares of VOO avg 400'));
    final r = await t.svc.applyCapture(
      parseApproximate('60 shares of VOO avg 410'),
    );
    expect((r.holdingsAdded, r.holdingsUpdated), (0, 1));
    final all = await t.store.holdings();
    expect(all, hasLength(1));
    expect(
      (all.single.quantity, all.single.avgCost, all.single.approximate),
      (60, 410, true),
    );
  });

  test('drafts without a quantity are skipped, never invented', () async {
    final t = build(now);
    final r = await t.svc.applyCapture(
      parseApproximate('some VTI from years ago'),
    );
    expect((r.saved, r.skipped), (0, 1));
    expect(await t.store.holdings(), isEmpty);
  });

  test('refresh keeps the old price when the source is down', () async {
    final t = build(now);
    await t.svc.applyCapture(parseApproximate('2 shares of VOO avg 400'));
    t.quotes.prices = {};
    expect(await t.svc.refreshPrices(), 0);
    expect((await t.store.holdings()).single.lastPrice, 520);
  });

  group('rules', () {
    test(
      'past-due buys appear once, as pending, and stay idempotent',
      () async {
        final t = build(now);
        final rule = InvestRule(
          id: 'r',
          symbol: 'VOO',
          amountMinor: 20000,
          day: 5,
          startDate: const CalDate(2026, 9, 1),
        );
        await t.svc.saveRule(rule);
        var pending = await t.svc.pendingBuys();
        expect(pending.map((p) => p.occurrence.due), [
          const CalDate(2026, 10, 5),
          const CalDate(2026, 11, 5),
        ]);
        pending = await t.svc.pendingBuys(); // again
        expect(pending, hasLength(2));
      },
    );

    test(
      'confirming adds units at a weighted cost and counts toward adherence',
      () async {
        final t = build(now);
        await t.svc.applyCapture(parseApproximate('10 shares of VOO avg 400'));
        await t.svc.saveRule(
          InvestRule(
            id: 'r',
            symbol: 'VOO',
            amountMinor: 52000,
            day: 5,
            startDate: const CalDate(2026, 10, 1),
          ),
        );
        final first = (await t.svc.pendingBuys()).first.occurrence;
        expect(
          await t.svc.confirmBuy(first.id),
          isTrue,
        ); // at the 520 last price
        final h = (await t.store.holdings()).single;
        expect(h.quantity, closeTo(11, 1e-9)); // $520 / 520
        expect(h.avgCost, closeTo((4000 + 520) / 11, 1e-9));
        final v = (await t.svc.ruleViews()).single;
        expect(v.adherence.confirmed, 1);
        expect(v.adherence.investedMinor, 52000);
        expect(v.pending, hasLength(1));
        expect(v.next, const CalDate(2026, 12, 5));
      },
    );

    test(
      'a rule with no holding yet creates it on the first confirmed buy',
      () async {
        final t = build(now);
        await t.svc.saveRule(
          InvestRule(
            id: 'r',
            symbol: 'VOO',
            amountMinor: 20000,
            day: 5,
            startDate: const CalDate(2026, 11, 1),
          ),
        );
        final o = (await t.svc.pendingBuys()).single.occurrence;
        expect(await t.svc.confirmBuy(o.id), isFalse); // no price known yet
        expect(await t.svc.confirmBuy(o.id, price: 500), isTrue);
        final h = (await t.store.holdings()).single;
        expect(
          (h.symbol, h.quantity, h.avgCost, h.source),
          ('VOO', 0.4, 500, 'rule'),
        );
      },
    );

    test('skipping ends the streak and is remembered', () async {
      final t = build(now);
      await t.svc.saveRule(
        InvestRule(
          id: 'r',
          symbol: 'VOO',
          amountMinor: 20000,
          day: 5,
          startDate: const CalDate(2026, 10, 1),
        ),
      );
      final p = await t.svc.pendingBuys();
      await t.svc.skipBuy(p.first.occurrence.id);
      await t.svc.confirmBuy(p.last.occurrence.id, price: 500);
      final v = (await t.svc.ruleViews()).single;
      expect(
        (v.adherence.confirmed, v.adherence.skipped, v.adherence.streak),
        (1, 1, 1),
      );
      expect(await t.svc.pendingBuys(), isEmpty);
    });
  });

  test('stock holdings count in net worth assets', () async {
    final t = build(now);
    await t.svc.applyCapture(parseApproximate('2 shares of VOO avg 400'));
    final book = await t.svc.wealth.book();
    final assets = await t.svc.assets(book);
    expect(assets.single.kind, AssetKind.stocks);
    expect(assets.single.value, closeTo(2 * 520 * 3.6725, 0.01));
    expect(assets.single.note, contains('approx'));
  });

  test('net worth sees stock holdings through the wealth service', () async {
    final t = build(now);
    await t.svc.applyCapture(parseApproximate('2 shares of VOO avg 400'));
    final all = await t.svc.wealth.assets();
    expect(all.where((a) => a.id.startsWith('stock:')), hasLength(1));
  });

  group('quote payload', () {
    test('parses, strips .us, skips unknowns', () {
      final q = parseStockQuotes({
        'quotes': [
          {
            'ticker': 'voo.us',
            'usd': '500.25',
            'status': 'live',
            'source': 'stooq.com',
            'last_updated': '2026-11-25T07:00:00Z',
          },
          {'ticker': 'zzzz.us', 'usd': null, 'status': 'unavailable'},
        ],
      });
      expect(q.keys, ['VOO']);
      expect(q['VOO']!.price, 500.25);
      expect(parseStockQuotes('nope'), isEmpty);
    });
  });

  test('the drift store round-trips holdings, rules and occurrences', () async {
    final db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = LocalInvestingStore(db);
    await store.saveHolding(
      StockHolding(
        id: 'h',
        symbol: 'VOO',
        quantity: 2.5,
        avgCost: 400,
        approximate: true,
        purchaseDate: const CalDate(2022, 7, 1),
        createdAt: now,
      ),
    );
    await store.saveRule(
      InvestRule(
        id: 'r',
        symbol: 'VOO',
        amountMinor: 20000,
        frequency: RuleFrequency.weekly,
        day: 5,
        startDate: const CalDate(2026, 1, 1),
      ),
    );
    await store.saveOccurrence(
      RuleOccurrence(
        id: 'r:2026-11-06',
        ruleId: 'r',
        due: const CalDate(2026, 11, 6),
        amountMinor: 20000,
        status: OccurrenceStatus.confirmed,
        price: 500,
        units: 0.4,
      ),
    );
    final h = (await store.holdings()).single;
    expect(
      (h.quantity, h.avgCost, h.approximate, h.purchaseDate),
      (2.5, 400, true, const CalDate(2022, 7, 1)),
    );
    final r = (await store.rules()).single;
    expect((r.frequency, r.day), (RuleFrequency.weekly, 5));
    final o = (await store.occurrences(ruleId: 'r')).single;
    expect(
      (o.status, o.price, o.units),
      (OccurrenceStatus.confirmed, 500, 0.4),
    );
    await store.deleteHolding('h');
    await store.deleteRule('r');
    expect(await store.holdings(), isEmpty);
    expect(await store.rules(), isEmpty);
    expect(await store.occurrences(), hasLength(1)); // history stays
  });
}
