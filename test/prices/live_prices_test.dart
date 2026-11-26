import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/engine/live_quote.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/investing_store.dart';
import 'package:pulse/data/local/live_prices.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/features/wealth/live_widgets.dart';

/// Answers by URL substring; throws when [fail] is set.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);
  final Map<String, String> routes;
  bool fail = false;
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    calls++;
    if (fail)
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    final hit = routes.entries
        .where((e) => o.uri.toString().contains(e.key))
        .firstOrNull;
    if (hit == null) return ResponseBody.fromString('', 404);
    return ResponseBody.fromString(hit.value, 200);
  }

  @override
  void close({bool force = false}) {}
}

FundHolding fund({String? navDate = '2026-11-24', double nav = 210}) =>
    FundHolding(
      id: 'f1',
      kind: 'india_mf',
      schemeCode: '100001',
      name: 'Example Flexi Cap',
      units: 10,
      nav: nav,
      navDate: navDate,
      createdAt: DateTime.utc(2026),
    );

void main() {
  final navall = File('test/fixtures/navall_sample.txt').readAsStringSync();
  final now = DateTime.utc(2026, 11, 26, 9);

  group('mergeQuote', () {
    test('a newer date shifts the old price to previous', () {
      final a = mergeQuote(
        null,
        price: 100,
        date: '2026-11-24',
        now: now,
      ).quote!;
      final b = mergeQuote(a, price: 103, date: '2026-11-25', now: now);
      expect(b.result, MergeResult.updated);
      expect(b.quote!.dayChange, 3);
      expect(b.quote!.dayChangePct, closeTo(3, 1e-9));
    });
    test('never goes back in time, never accepts junk or wild jumps', () {
      final a = mergeQuote(
        null,
        price: 100,
        date: '2026-11-25',
        now: now,
      ).quote!;
      expect(
        mergeQuote(a, price: 90, date: '2026-11-20', now: now).result,
        MergeResult.rejected,
      );
      expect(
        mergeQuote(a, price: 0, date: '2026-11-26', now: now).result,
        MergeResult.rejected,
      );
      expect(
        mergeQuote(a, price: double.nan, date: '2026-11-26', now: now).result,
        MergeResult.rejected,
      );
      expect(
        mergeQuote(a, price: 300, date: '2026-11-26', now: now).result,
        MergeResult.rejected,
      );
      expect(
        mergeQuote(a, price: 100, date: '2026-11-25', now: now).result,
        MergeResult.unchanged,
      );
    });
    test('no previous price means no day change, not zero', () {
      final a = mergeQuote(
        null,
        price: 100,
        date: '2026-11-25',
        now: now,
      ).quote!;
      expect(a.dayChange, isNull);
    });
    test('json round trip; corrupt cache is empty', () {
      final a = mergeQuote(
        null,
        price: 1.5,
        date: '2026-11-25',
        now: now,
        seedPrev: 1.4,
        seedPrevDate: '2026-11-24',
      ).quote!;
      final back = decodeQuotes(encodeQuotes({'k': a}));
      expect(back['k']!.prevPrice, 1.4);
      expect(decodeQuotes('{oops'), isEmpty);
    });
    test('freshness labels', () {
      expect(asOfLabel('2026-11-25', now, fund: true), 'NAV 25 Nov');
      expect(
        asOfLabel('2026-11-25', now, fund: false),
        'Last close 25 Nov · delayed',
      );
      expect(asOfLabel('2026-11-01', now, fund: true), 'Stale: NAV 1 Nov');
      expect(asOfLabel(null, now, fund: true), 'NAV date unknown');
    });
  });

  group('AmfiService', () {
    AmfiService svc(_Adapter a, KvStore kv, TextCache c) => AmfiService(
      dio: Dio()..httpClientAdapter = a,
      cache: c,
      kv: kv,
      clock: () => now,
      minSchemes: 1,
    );

    test('downloads once, then serves the cache within the ttl', () async {
      final a = _Adapter({'NAVAll': navall});
      final s = svc(a, MemoryKvStore(), MemoryTextCache());
      expect((await s.book()).book!.schemes, isNotEmpty);
      final second = await s.book();
      expect(second.fromCache, isTrue);
      expect(a.calls, 1);
    });
    test('offline falls back to the last file; no file means null', () async {
      final cache = MemoryTextCache(), kv = MemoryKvStore();
      final a = _Adapter({'NAVAll': navall});
      await svc(a, kv, cache).book();
      a.fail = true;
      final r = await svc(a, kv, cache).book(force: true);
      expect(r.fromCache, isTrue);
      expect(r.book!.byCode('100001'), isNotNull);
      final none = await svc(
        _Adapter({})..fail = true,
        MemoryKvStore(),
        MemoryTextCache(),
      ).book();
      expect(none.book, isNull);
    });
    test('an HTML block page never replaces a good cache', () async {
      final cache = MemoryTextCache(), kv = MemoryKvStore();
      await svc(_Adapter({'NAVAll': navall}), kv, cache).book();
      final r = await svc(
        _Adapter({'NAVAll': '<html>Access denied</html>'}),
        kv,
        cache,
      ).book(force: true);
      expect(r.fromCache, isTrue);
      expect(await cache.read('amfi_navall.txt'), navall);
    });
  });

  group('LivePriceService', () {
    LivePriceService build(
      _Adapter a,
      MemoryWealthStore w,
      MemoryInvestingStore i,
      KvStore kv, {
      Duration interval = const Duration(hours: 3),
    }) {
      final dio = Dio()..httpClientAdapter = a;
      return LivePriceService(
        wealth: w,
        investing: i,
        amfi: AmfiService(
          dio: dio,
          cache: MemoryTextCache(),
          kv: kv,
          clock: () => now,
          minSchemes: 1,
        ),
        stooq: StooqService(dio, clock: () => now),
        kv: kv,
        clock: () => now,
        minInterval: interval,
      );
    }

    test(
      'updates a fund NAV from AMFI, seeds the day change, and throttles',
      () async {
        final w = MemoryWealthStore(funds: [fund()]);
        final kv = MemoryKvStore();
        final a = _Adapter({'NAVAll': navall});
        final s = build(a, w, MemoryInvestingStore(), kv);
        final r = await s.refresh();
        expect(r.fundsUpdated, 1);
        final f = (await w.funds()).single;
        expect(f.nav, 215.1);
        expect(f.navDate, '2026-11-25');
        final q = (await s.quotes())[LivePriceService.fundKey('100001')]!;
        expect(q.dayChange, closeTo(5.1, 1e-9));
        expect((await s.refresh()).skipped, isTrue);
        expect(a.calls, 1);
      },
    );

    test('an older AMFI date never overwrites a newer holding NAV', () async {
      final w = MemoryWealthStore(
        funds: [fund(navDate: '2026-11-26', nav: 216)],
      );
      final s = build(
        _Adapter({'NAVAll': navall}),
        w,
        MemoryInvestingStore(),
        MemoryKvStore(),
      );
      await s.refresh(force: true);
      expect((await w.funds()).single.nav, 216);
    });

    test('failure keeps the last NAV and reports an error', () async {
      final w = MemoryWealthStore(funds: [fund()]);
      final r = await build(
        _Adapter({})..fail = true,
        w,
        MemoryInvestingStore(),
        MemoryKvStore(),
      ).refresh();
      expect(r.errors, isNotEmpty);
      expect((await w.funds()).single.nav, 210);
    });

    test('US stock close from Stooq with previous close; NSE is left alone', () async {
      final i = MemoryInvestingStore(
        holdings: [
          StockHolding(
            id: 's1',
            symbol: 'VOO',
            quantity: 2,
            avgCost: 400,
            lastPrice: 500,
            createdAt: DateTime.utc(2026),
          ),
          StockHolding(
            id: 's2',
            symbol: 'RELIANCE.NS',
            currency: 'INR',
            quantity: 5,
            lastPrice: 1200,
            createdAt: DateTime.utc(2026),
          ),
        ],
      );
      const csv =
          'Date,Open,High,Low,Close,Volume\n2026-11-24,1,1,1,505.0,1\n2026-11-25,1,1,1,510.0,1\n';
      final s = build(
        _Adapter({'stooq.com': csv}),
        MemoryWealthStore(),
        i,
        MemoryKvStore(),
      );
      final r = await s.refresh();
      expect(r.stocksUpdated, 1);
      final h = (await i.holdings()).firstWhere((h) => h.symbol == 'VOO');
      expect(h.lastPrice, 510);
      expect(h.priceSource, 'last close 2026-11-25');
      expect(
        (await i.holdings())
            .firstWhere((h) => h.symbol == 'RELIANCE.NS')
            .lastPrice,
        1200,
      );
      expect(
        (await s.quotes())[LivePriceService.stockKey('VOO')]!.dayChange,
        5,
      );
    });

    test('Stooq CSV parser skips junk (e.g. an API-key notice)', () {
      expect(parseStooqCsv('Get your apikey: ...'), isEmpty);
      expect(
        parseStooqCsv('Date,Open\n2026-11-25,1,2,3,4.5,9\n').single.close,
        4.5,
      );
    });
  });

  testWidgets(
    'DayChangeText shows signed change, and nothing without a previous price',
    (t) async {
      final q = mergeQuote(
        mergeQuote(null, price: 100, date: '2026-11-24', now: now).quote,
        price: 102,
        date: '2026-11-25',
        now: now,
      ).quote;
      await t.pumpWidget(
        MaterialApp(
          theme: PulseTheme.light,
          home: Scaffold(
            body: DayChangeText(quote: q, quantity: 10, currency: 'INR'),
          ),
        ),
      );
      expect(find.text('Today +INR 20 (+2.0%)'), findsOneWidget);
      final none = mergeQuote(
        null,
        price: 100,
        date: '2026-11-24',
        now: now,
      ).quote;
      await t.pumpWidget(
        MaterialApp(
          theme: PulseTheme.light,
          home: Scaffold(
            body: DayChangeText(quote: none, quantity: 10, currency: 'INR'),
          ),
        ),
      );
      expect(find.byKey(const Key('day-change')), findsNothing);
    },
  );
}
