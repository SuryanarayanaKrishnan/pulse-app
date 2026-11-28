import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/capture_parser.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/investing.dart';
import 'package:pulse/data/fund_match.dart';
import 'package:pulse/data/investing_service.dart';
import 'package:pulse/data/local/investing_store.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/reminders.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/data/wealth_service.dart';

class _Quotes extends StockQuoteService {
  _Quotes(this.got) : super(null);
  final Map<String, StockQuote> got;
  final asked = <String>[];
  @override
  bool get available => true;
  @override
  Future<Map<String, StockQuote>> fetch(Iterable<String> symbols) async {
    asked.addAll(symbols);
    return got;
  }
}

class _Funds extends FundLookup {
  _Funds() : super(null);
  double nav = 82.5;
  @override
  bool get available => true;
  @override
  Future<List<FundScheme>> search(String q) async {
    final l = q.toLowerCase();
    return [
      for (final s in _all)
        if (l.split(' ').every(s.name.toLowerCase().contains)) s,
    ];
  }

  @override
  Future<FundNav?> latest(String code) async =>
      FundNav(code: code, navDate: '2026-11-24', nav: nav);

  static const _all = [
    FundScheme('122639', 'Parag Parikh Flexi Cap Fund - Direct Plan - Growth'),
    FundScheme('122640', 'Parag Parikh Flexi Cap Fund - Regular Plan - Growth'),
    FundScheme('122641', 'Parag Parikh Flexi Cap Fund - Direct Plan - IDCW'),
    FundScheme('999', 'HDFC Index Fund Nifty 50 Plan - Direct Plan - Growth'),
  ];
}

({
  InvestingService svc,
  MemoryInvestingStore store,
  WealthStore ws,
  _Quotes quotes,
  _Funds funds,
  RecordingReminders reminders,
  WealthService wealth,
})
build(DateTime now, {Map<String, StockQuote>? quotes}) {
  final ws = MemoryWealthStore();
  final store = MemoryInvestingStore();
  final funds = _Funds();
  final reminders = RecordingReminders();
  final wealth = WealthService(
    investing: store,
    store: ws,
    prices: PriceService(store: ws, clock: () => now),
    fundLookup: funds,
    reminders: reminders,
    clock: () => now,
  );
  final q = _Quotes(quotes ?? {});
  return (
    svc: InvestingService(
      store: store,
      wealth: wealth,
      quotes: q,
      clock: () => now,
    ),
    store: store,
    ws: ws,
    quotes: q,
    funds: funds,
    reminders: reminders,
    wealth: wealth,
  );
}

const _app = '''
Mutual Funds
Parag Parikh Flexi Cap Fund -
Direct Plan - Growth
Invested ₹1,20,000
Current value ₹1,48,250.40
Units 1,820.455
NAV ₹81.43
SIP ₹5,000 on the 5th
''';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final now = DateTime(2026, 11, 25, 8);

  typedFundServiceTests();

  group('quotes', () {
    test('parse keeps the exchange and the currency', () {
      final m = parseStockQuotes({
        'quotes': [
          {
            'ticker': 'voo.us',
            'usd': '500.25',
            'price': '500.25',
            'currency': 'USD',
            'status': 'live',
          },
          {
            'ticker': 'reliance.ns',
            'usd': null,
            'price': '1412.35',
            'currency': 'INR',
            'status': 'live',
          },
          {
            'ticker': 'emaar.dfm',
            'usd': null,
            'price': null,
            'status': 'unavailable',
          },
          {'ticker': 'aapl.us', 'usd': 200, 'status': 'live'}, // older server
        ],
      });
      expect(m.keys, containsAll(['VOO', 'RELIANCE.NS', 'AAPL']));
      expect(m['RELIANCE.NS']!.currency, 'INR');
      expect(m['RELIANCE.NS']!.price, 1412.35);
      expect(m['AAPL']!.currency, 'USD');
      expect(m.containsKey('EMAAR.DFM'), isFalse);
    });

    test(
      'NSE holdings refresh in rupees; Dubai holdings keep the typed price',
      () async {
        final t = build(
          now,
          quotes: {
            'RELIANCE.NS': const StockQuote(
              symbol: 'RELIANCE.NS',
              price: 1412.35,
              currency: 'INR',
            ),
            'EMAAR.DFM': const StockQuote(
              symbol: 'EMAAR.DFM',
              price: 99,
              currency: 'AED',
            ),
          },
        );
        await t.svc.applyCapture(
          parseApproximate('10 shares of RELIANCE.NS avg 1200'),
        );
        await t.svc.saveHolding(
          StockHolding(
            id: 'e',
            symbol: 'EMAAR.DFM',
            currency: 'AED',
            quantity: 100,
            lastPrice: 13.2,
            priceSource: 'manual',
            createdAt: now,
          ),
        );
        await t.svc.refreshPrices();
        final all = {for (final h in await t.store.holdings()) h.symbol: h};
        expect(all['RELIANCE.NS']!.lastPrice, 1412.35);
        expect(all['RELIANCE.NS']!.currency, 'INR');
        expect(all['EMAAR.DFM']!.lastPrice, 13.2);
        expect(t.quotes.asked, isNot(contains('EMAAR.DFM')));
      },
    );

    test(
      'a quote in another currency than the holding is never mixed in',
      () async {
        final t = build(
          now,
          quotes: {
            'VOO': const StockQuote(symbol: 'VOO', price: 500, currency: 'INR'),
          },
        );
        await t.svc.saveHolding(
          StockHolding(
            id: 'v',
            symbol: 'VOO',
            quantity: 1,
            lastPrice: 450,
            createdAt: now,
          ),
        );
        expect(await t.svc.refreshPrices(), 0);
      },
    );
  });

  group('fund matching', () {
    test('keywords drop plan words; direct growth is preferred', () {
      expect(
        fundKeywords('Parag Parikh Flexi Cap Fund - Direct Plan - Growth'),
        ['parag', 'parikh', 'flexi', 'cap'],
      );
      final pick = pickScheme('Parag Parikh Flexi Cap Fund', _Funds._all);
      expect(pick!.code, '122639');
      expect(
        pickScheme(
          'Parag Parikh Flexi Cap Fund Regular Growth',
          _Funds._all,
        )!.code,
        '122640',
      );
      expect(
        pickScheme('Parag Parikh Flexi Cap IDCW', _Funds._all)!.code,
        '122641',
      );
      expect(pickScheme('Totally Other Scheme', _Funds._all), isNull);
    });
  });

  group('mutual fund screenshots', () {
    test('become an Indian fund with live NAV and a tracked SIP', () async {
      final t = build(now);
      final r = await t.svc.applyCapture(parseCapture(_app));
      expect((r.fundsAdded, r.sipsAdded, r.fundsUnmatched), (1, 1, 0));
      final f = (await t.wealth.fundViews()).single.holding;
      expect(f.kind, 'india_mf');
      expect(f.schemeCode, '122639');
      expect(f.units, 1820.455);
      expect(f.nav, 82.5); // official NAV, not the screenshot's 81.43
      expect(f.avgCostNav, closeTo(120000 / 1820.455, 1e-9));
      expect(f.sipAmountMinor, 500000);
      expect(f.sipDay, 5);
      final rule = (await t.store.rules()).single;
      expect(rule.isFund, isTrue);
      expect(rule.fundId, f.id);
      expect(rule.amountMinor, 500000);
      expect((rule.currency, rule.day), ('INR', 5));
    });

    test(
      'scanning again updates the fund and does not duplicate the SIP rule',
      () async {
        final t = build(now);
        await t.svc.applyCapture(parseCapture(_app));
        final r = await t.svc.applyCapture(parseCapture(_app));
        expect((r.fundsAdded, r.fundsUpdated, r.sipsAdded), (0, 1, 0));
        expect(await t.store.rules(), hasLength(1));
        expect(await t.wealth.fundViews(), hasLength(1));
      },
    );

    test(
      'an unknown scheme is saved by hand with the screenshot NAV',
      () async {
        final t = build(now);
        final r = await t.svc.applyCapture(
          parseCapture('''
Zzz Obscure Opportunities Fund Direct Growth
Invested ₹10,000
Current value ₹11,000
Units 100.0
NAV ₹110.00
'''),
        );
        expect((r.fundsAdded, r.fundsUnmatched), (1, 1));
        final f = (await t.wealth.fundViews()).single.holding;
        expect((f.kind, f.nav, f.navSource), ('manual', 110, 'manual'));
      },
    );
  });

  group('SIP rules like the VOO one', () {
    test('typed sentence', () {
      final d = parseSipText('SIP 5000 monthly in Parag Parikh Flexi Cap')!;
      expect(d.fundQuery, 'Parag Parikh Flexi Cap');
      expect(
        (d.amountMinor, d.currency, d.frequency, d.day),
        (500000, 'INR', RuleFrequency.monthly, 1),
      );
      final e = parseSipText(
        'invest ₹10,000 every month on the 7th into HDFC Index Fund Nifty 50',
      )!;
      expect((e.amountMinor, e.day), (1000000, 7));
      expect(e.fundQuery, 'HDFC Index Fund Nifty 50');
      expect(parseSipText('SIP monthly in something'), isNull);
    });

    test(
      'a confirmed instalment buys units at the NAV and averages the cost',
      () async {
        final t = build(now);
        await t.svc.applyCapture(parseCapture(_app));
        t.funds.nav = 100;
        // Eleven days later the 5th has come and gone.
        final later = InvestingService(
          store: t.store,
          wealth: t.wealth,
          quotes: t.quotes,
          clock: () => DateTime(2026, 12, 6, 9),
        );
        final pending = await later.pendingBuys();
        expect(pending, isNotEmpty);
        final before = (await t.wealth.fundViews()).single.holding;
        final ok = await later.confirmBuy(pending.first.occurrence.id);
        expect(ok, isTrue);
        final after = (await t.wealth.fundViews()).single.holding;
        expect(after.units, closeTo(before.units + 5000 / 100, 1e-9));
        expect(after.nav, 100);
        expect(
          after.avgCostNav,
          closeTo(
            (before.units * before.avgCostNav! + 5000) / after.units,
            1e-9,
          ),
        );
        final occ = (await t.store.occurrences()).firstWhere(
          (o) => o.id == pending.first.occurrence.id,
        );
        expect(
          (occ.status, occ.price, occ.units),
          (OccurrenceStatus.confirmed, 100, 50),
        );
      },
    );

    test(
      'starting a SIP on a fund you do not hold yet adds it with no units',
      () async {
        final t = build(now);
        final f = await t.svc.startFundSip(
          const FundScheme(
            '999',
            'HDFC Index Fund Nifty 50 Plan - Direct Plan - Growth',
          ),
          amountMinor: 200000,
          day: 10,
        );
        expect(f.units, 0);
        expect(f.nav, 82.5);
        final rule = (await t.store.rules()).single;
        expect(rule.label, contains('HDFC'));
        final later = InvestingService(
          store: t.store,
          wealth: t.wealth,
          quotes: t.quotes,
          clock: () => DateTime(2026, 12, 11),
        );
        final p = await later.pendingBuys();
        expect(p, hasLength(1));
        await later.confirmBuy(p.first.occurrence.id, price: 80, amount: 2000);
        final h = (await t.wealth.fundViews()).single.holding;
        expect((h.units, h.avgCostNav), (25, 80));
      },
    );

    test('deleting the rule clears the fund SIP', () async {
      final t = build(now);
      await t.svc.applyCapture(parseCapture(_app));
      await t.svc.deleteRule((await t.store.rules()).single.id);
      final f = (await t.wealth.fundViews()).single.holding;
      expect(f.hasSip, isFalse);
    });
  });

  group('coming-up reminders and the upcoming list', () {
    test(
      'a VOO rule reminds the day before and on the day, and lists as upcoming',
      () async {
        final t = build(now);
        final rule = t.svc.newRule(
          const RuleDraft(
            symbol: 'VOO',
            amountMinor: 20000,
            currency: 'USD',
            frequency: RuleFrequency.monthly,
            day: 28,
          ),
        );
        await t.svc.saveRule(rule);
        final titles = t.reminders.scheduled.values.map((e) => e.$1).toList();
        expect(titles, containsAll(['Coming up tomorrow', 'Time to buy VOO']));
        final ahead = t.reminders.scheduled.values.firstWhere(
          (e) => e.$1 == 'Coming up tomorrow',
        );
        expect(ahead.$3, DateTime(2026, 11, 27, 9));
        final up = await t.wealth.upcoming();
        final buy = up.firstWhere((u) => u.kind == UpcomingKind.buy);
        expect(buy.title, 'Buy VOO');
        expect(buy.date, const CalDate(2026, 11, 28));
        expect(buy.detail, contains('USD 200'));
        await t.svc.deleteRule(rule.id);
        expect(t.reminders.scheduled, isEmpty);
      },
    );

    test('a paused rule schedules nothing', () async {
      final t = build(now);
      final rule = t.svc.newRule(
        const RuleDraft(
          symbol: 'VOO',
          amountMinor: 20000,
          currency: 'USD',
          frequency: RuleFrequency.monthly,
          day: 28,
        ),
      );
      await t.svc.saveRule(rule.copyWith(active: false));
      expect(t.reminders.scheduled, isEmpty);
    });
  });
}

void typedFundServiceTests() {
  final now = DateTime(2026, 11, 25, 8);
  test(
    'a typed "about 1 lakh" entry becomes units at the official NAV',
    () async {
      final t = build(now);
      final r = await t.svc.applyCapture(
        parseApproximate('about ₹1 lakh in Parag Parikh Flexi Cap'),
      );
      expect((r.fundsAdded, r.fundsUnmatched), (1, 0));
      final f = (await t.wealth.fundViews()).single.holding;
      expect(f.schemeCode, '122639');
      expect(f.units, closeTo(100000 / 82.5, 1e-9));
      expect(f.avgCostNav, isNull); // cost unknown: no invented P&L
    },
  );
}
