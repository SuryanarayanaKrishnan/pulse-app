import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/prices.dart';
import 'package:pulse/core/engine/valuation.dart';
import 'package:pulse/data/local/attachments.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/reminders.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/data/wealth_service.dart';

import '../support/fake_adapter.dart';

final _now = DateTime(2026, 11, 24, 10);

Map<String, Object?> snapshot({String gold24 = '480.00'}) => {
  'generated_at': '2026-11-24T06:00:00Z',
  'ttl_seconds': 900,
  'status': 'live',
  'gold': {
    'status': 'live',
    'source': 'gold-api.com',
    'last_updated': '2026-11-24T06:00:00Z',
    'per_gram': {
      '24k': {'aed': gold24, 'usd': '130'},
      '22k': {'aed': '440.00', 'usd': '120'},
    },
  },
  'fx': [
    {'currency': 'INR', 'aed_per_unit': '0.0430', 'status': 'live', 'source': 'open.er-api.com', 'last_updated': '2026-11-24T06:00:00Z'},
  ],
  'notes': [],
};

Dio dioWith(Map<String, Object?> routes) => Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = FakeAdapter(routes);

class _Env {
  _Env(this.store, this.service, this.reminders, this.storage);
  final WealthStore store;
  final WealthService service;
  final RecordingReminders reminders;
  final MemoryAttachmentStorage storage;
}

_Env env({WealthStore? store, Dio? dio}) {
  final s = store ?? MemoryWealthStore();
  final rem = RecordingReminders();
  final storage = MemoryAttachmentStorage();
  return _Env(
    s,
    WealthService(
      store: s,
      prices: PriceService(store: s, dio: dio, clock: () => _now),
      fundLookup: FundLookup(dio),
      reminders: rem,
      storage: storage,
      clock: () => _now,
    ),
    rem,
    storage,
  );
}

JewelleryItem ring({String id = 'j1', double g = 10, int karat = 22, int? price = 340000}) => JewelleryItem(
  id: id, name: 'Ring', weightGrams: g, karat: karat, purchasePriceMinor: price, createdAt: _now,
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('PriceService', () {
    test('without a backend it serves the bundled fallback', () async {
      final e = env();
      final b = await e.service.prices.current();
      expect(b.origin, PriceOrigin.bundled);
      expect(b.gold24, isNotNull);
      expect(b.isStale, isTrue);
      expect(e.service.prices.canFetch, isFalse);
      expect((await e.service.prices.refresh()).origin, PriceOrigin.bundled);
    });

    test('refresh stores the snapshot with fetched_at and later works offline', () async {
      final store = MemoryWealthStore();
      final online = env(store: store, dio: dioWith({'GET /v1/prices/snapshot': snapshot()}));
      final fresh = await online.service.prices.refresh();
      expect(fresh.gold24, 480);
      expect(fresh.origin, PriceOrigin.fetched);
      expect(fresh.isStale, isFalse);
      expect(fresh.fx('INR'), 0.043);
      final cached = await store.priceQuotes();
      expect(cached.map((q) => q.symbol), containsAll(['XAU_AED_G_24K', 'XAU_AED_G_22K', 'FX_INR_AED']));
      expect(cached.first.fetchedAt, _now.toUtc());

      // A new session with the network down reads the same prices from the cache.
      final offline = env(store: store, dio: dioWith({'GET /v1/prices/snapshot': (503, {'error': {'code': 'down', 'message': 'down'}})}));
      final book = await offline.service.prices.refresh(force: true);
      expect(offline.service.prices.lastError, isNotNull);
      expect(book.gold24, 480);
      expect(book.origin, PriceOrigin.cached);
      expect((await offline.service.prices.current()).gold24, 480);
    });

    test('a fresh cache is not refetched inside the TTL, but force fetches', () async {
      final store = MemoryWealthStore();
      var calls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = FakeAdapter({'GET /v1/prices/snapshot': (_) { calls++; return snapshot(); }});
      final e = env(store: store, dio: dio);
      await e.service.prices.refresh();
      await e.service.prices.refresh();
      expect(calls, 1);
      await e.service.prices.refresh(force: true);
      expect(calls, 2);
    });

    test('a broken payload keeps the previous prices', () async {
      final store = MemoryWealthStore();
      await env(store: store, dio: dioWith({'GET /v1/prices/snapshot': snapshot()})).service.prices.refresh();
      final bad = env(store: store, dio: dioWith({'GET /v1/prices/snapshot': {'gold': 'oops'}}));
      expect((await bad.service.prices.refresh(force: true)).gold24, 480);
    });
  });

  group('jewellery', () {
    test('values from the cached price and records a snapshot per day', () async {
      final e = env(store: MemoryWealthStore(), dio: dioWith({'GET /v1/prices/snapshot': snapshot()}));
      await e.service.prices.refresh();
      final saved = await e.service.saveJewellery(ring());
      final v = (await e.service.jewelleryViews()).single.value;
      expect(v.valueMinor, 440000); // 10 g x 22/24 x 480 = 4,400.00
      expect(v.gainMinor, 100000);
      final h = await e.service.jewelleryHistory(saved.id);
      expect(h.single.valueMinor, 440000);
      expect(h.single.date, const CalDate(2026, 11, 24));
      // Saving again the same day replaces the point rather than adding one.
      await e.service.saveJewellery(saved.copyWith(weightGrams: 5));
      final h2 = await e.service.jewelleryHistory(saved.id);
      expect(h2.length, 1);
      expect(h2.single.valueMinor, 220000);
    });

    test('photos are copied in, kept on edit, and deleted with the item', () async {
      final e = env();
      final saved = await e.service.saveJewellery(ring(), newPhotoSources: ['/tmp/a.jpg', '/tmp/b.jpg']);
      expect(saved.photoPaths, ['/tmp/a.jpg', '/tmp/b.jpg']);
      final edited = await e.service.saveJewellery(saved, newPhotoSources: ['/tmp/c.jpg'], removedPhotos: ['/tmp/a.jpg']);
      expect(edited.photoPaths, ['/tmp/b.jpg', '/tmp/c.jpg']);
      await e.service.deleteJewellery(saved.id);
      expect(await e.service.jewelleryViews(), isEmpty);
    });

    test('revaluation follows a new price without touching the stored item', () async {
      final store = MemoryWealthStore();
      await env(store: store, dio: dioWith({'GET /v1/prices/snapshot': snapshot()})).service.prices.refresh();
      final e1 = env(store: store);
      await e1.service.saveJewellery(ring());
      await env(store: store, dio: dioWith({'GET /v1/prices/snapshot': snapshot(gold24: '510.00')})).service.prices.refresh(force: true);
      final e2 = env(store: store);
      expect((await e2.service.jewelleryViews()).single.value.valueMinor, 467500);
      await e2.service.recordValuations();
      expect((await e2.service.jewelleryHistory('j1')).single.valueMinor, 467500);
    });
  });

  group('documents and reminders', () {
    WealthDocument doc({CalDate? due, int? days = 30, String id = 'd1'}) => WealthDocument(
      id: id, title: 'Passport', category: DocCategory.passport, dueOn: due, remindDaysBefore: days, createdAt: _now,
    );

    test('a future date schedules a notification at 09:00, N days before', () async {
      final e = env();
      final saved = await e.service.saveDocument(doc(due: const CalDate(2027, 3, 1)));
      expect(e.reminders.scheduled[saved.notificationId], isNotNull);
      final (title, body, at) = e.reminders.scheduled[saved.notificationId]!;
      expect(title, 'Passport');
      expect(body, contains('Expires in 30 days'));
      expect(at, DateTime(2027, 1, 30, 9));
    });

    test('no date, no reminder, or a past reminder time schedules nothing', () async {
      final e = env();
      await e.service.saveDocument(doc());
      await e.service.saveDocument(doc(due: const CalDate(2027, 3, 1), days: null, id: 'd2'));
      await e.service.saveDocument(doc(due: const CalDate(2026, 12, 1), id: 'd3'));
      expect(e.reminders.scheduled, isEmpty);
    });

    test('editing replaces the reminder and deleting cancels it', () async {
      final e = env();
      final saved = await e.service.saveDocument(doc(due: const CalDate(2027, 3, 1)));
      await e.service.saveDocument(WealthDocument(
        id: saved.id, title: 'Passport', category: saved.category, dueOn: const CalDate(2027, 6, 1), remindDaysBefore: 7,
        notificationId: saved.notificationId, createdAt: _now,
      ));
      expect(e.reminders.scheduled.length, 1);
      expect(e.reminders.scheduled.values.single.$3, DateTime(2027, 5, 25, 9));
      await e.service.deleteDocument(saved.id);
      expect(e.reminders.scheduled, isEmpty);
      expect(await e.service.documents(), isEmpty);
    });

    test('rescheduleReminders re-registers everything after a reset', () async {
      final e = env();
      await e.service.saveDocument(doc(due: const CalDate(2027, 3, 1)));
      e.reminders.scheduled.clear();
      await e.service.rescheduleReminders();
      expect(e.reminders.scheduled.length, 1);
    });

    test('upcoming merges dated documents and SIPs, soonest first', () async {
      final e = env();
      await e.service.saveDocument(doc(due: const CalDate(2026, 12, 20)));
      await e.service.saveDocument(doc(id: 'nodate'));
      await e.service.saveDocument(doc(id: 'overdue', due: const CalDate(2026, 11, 20)));
      await e.service.saveFund(FundHolding(
        id: 'f', kind: 'manual', name: 'MM Fund', currency: 'AED', units: 10, nav: 1, sipAmountMinor: 50000, sipDay: 28, createdAt: _now,
      ));
      final up = await e.service.upcoming();
      expect(up.map((u) => u.refId), ['overdue', 'f', 'd1']);
      expect(up.first.status, DueStatus.overdue);
      expect(up[1].kind, UpcomingKind.sip);
      expect(up[1].detail, contains('AED 500'));
    });
  });

  group('funds', () {
    test('search and NAV refresh go through the backend; manual funds are untouched', () async {
      final e = env(dio: dioWith({
        'GET /v1/funds/search': [
          {'scheme_code': 122639, 'name': 'Parag Parikh Flexi Cap Fund - Direct Growth'},
          {'scheme_code': '999', 'name': 'Other'},
          {'bad': true},
        ],
        'GET /v1/funds/schemes/122639/latest': {'scheme_code': '122639', 'name': 'PPFAS', 'nav_date': '2026-11-23', 'nav': '81.5000'},
      }));
      final hits = await e.service.searchFunds('parag');
      expect(hits.map((h) => h.code), ['122639', '999']);
      await e.service.saveFund(FundHolding(id: 'f1', kind: 'india_mf', schemeCode: '122639', name: hits.first.name, units: 100, avgCostNav: 60, nav: 70, createdAt: _now));
      await e.service.saveFund(FundHolding(id: 'f2', kind: 'manual', name: 'Manual', currency: 'AED', units: 1, nav: 5, createdAt: _now));
      expect(await e.service.refreshNavs(), 1);
      final views = await e.service.fundViews();
      final f1 = views.firstWhere((v) => v.holding.id == 'f1');
      expect(f1.holding.nav, 81.5);
      expect(f1.holding.navSource, 'market');
      expect(f1.holding.navDate, '2026-11-23');
      expect(views.firstWhere((v) => v.holding.id == 'f2').holding.nav, 5);
    });

    test('without a backend there is no search and no refresh', () async {
      final e = env();
      expect(e.service.fundLookup.available, isFalse);
      expect(await e.service.searchFunds('x'), isEmpty);
      expect(await e.service.refreshNavs(), 0);
    });

    test('value in AED uses the cached FX rate and flows into net worth assets', () async {
      final store = MemoryWealthStore();
      final e = env(store: store, dio: dioWith({'GET /v1/prices/snapshot': snapshot()}));
      await e.service.prices.refresh();
      await e.service.saveFund(FundHolding(id: 'f1', kind: 'india_mf', schemeCode: '1', name: 'Fund', units: 1000, avgCostNav: 50, nav: 60, createdAt: _now));
      await e.service.saveFund(FundHolding(id: 'f2', kind: 'manual', name: 'Yen fund', currency: 'JPY', units: 1, nav: 1, createdAt: _now));
      await e.service.saveJewellery(ring());
      final v = (await e.service.fundViews()).first.value;
      expect(v.valueAedMinor, 258000); // INR 60,000 x 0.043 = AED 2,580
      expect(v.gainPct, closeTo(20, 1e-9));
      final assets = await e.service.assets();
      final fund = assets.firstWhere((a) => a.kind == AssetKind.funds);
      expect(fund.value, 2580);
      expect(assets.where((a) => a.kind == AssetKind.funds).length, 1); // JPY has no rate: left out, not guessed
      expect(assets.firstWhere((a) => a.kind == AssetKind.gold).value, 4400);
    });
  });

  group('drift store', () {
    test('everything round-trips through the database', () async {
      final db = PulseDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final store = LocalWealthStore(db);
      final e = env(store: store);
      await e.service.saveJewellery(
        JewelleryItem(
          id: 'j1', name: 'Chain', weightGrams: 12.345, karat: 21, purchasePriceMinor: 123456,
          purchaseDate: const CalDate(2024, 1, 2), makingChargesMinor: 5000, notes: 'gift',
          photoPaths: const [], createdAt: _now,
        ),
        newPhotoSources: ['/p/1.jpg'],
      );
      final back = (await store.jewellery()).single;
      expect(back.weightGrams, 12.345);
      expect(back.karat, 21);
      expect(back.purchaseDate, const CalDate(2024, 1, 2));
      expect(back.photoPaths, ['/p/1.jpg']);
      expect(back.notes, 'gift');

      await e.service.saveDocument(WealthDocument(
        id: 'd1', title: 'Deed', category: DocCategory.titleDeed, dueOn: const CalDate(2027, 5, 5), dueKind: 'renewal',
        remindDaysBefore: 14, filePaths: const ['/f.jpg'], createdAt: _now,
      ));
      final d = (await store.documents()).single;
      expect(d.category, DocCategory.titleDeed);
      expect(d.dueOn, const CalDate(2027, 5, 5));
      expect(d.dueKind, 'renewal');
      expect(d.notificationId, isNotNull);

      await e.service.saveFund(FundHolding(id: 'f1', kind: 'manual', name: 'F', currency: 'USD', units: 3.5, avgCostNav: 9, nav: 10, sipAmountMinor: 10000, sipDay: 5, createdAt: _now));
      final f = (await store.funds()).single;
      expect((f.units, f.currency, f.sipDay, f.hasSip), (3.5, 'USD', 5, true));

      await store.savePriceQuotes([PriceQuote(symbol: 'XAU_AED_G_24K', price: 1, fetchedAt: _now.toUtc())]);
      await store.savePriceQuotes([PriceQuote(symbol: 'XAU_AED_G_24K', price: 2, fetchedAt: _now.toUtc())]);
      expect((await store.priceQuotes()).single.price, 2);

      await e.service.deleteJewellery('j1');
      await e.service.deleteDocument('d1');
      await e.service.deleteFund('f1');
      expect(await store.jewellery(), isEmpty);
      expect(await store.documents(), isEmpty);
      expect(await store.funds(), isEmpty);
      expect(await store.valuationHistory('jewellery', 'j1'), isEmpty);
    });
  });
}
