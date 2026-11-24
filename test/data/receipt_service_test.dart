import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/engine/receipts/receipt_models.dart';
import 'package:pulse/core/engine/receipts/receipt_source.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/receipt_service.dart';

import '../core/engine/receipts/fixture.dart';

class _Sink implements Analytics {
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
}

class _Off implements ReceiptSource {
  @override
  bool get isConfigured => false;
  @override
  Future<List<ReceiptMessage>> fetch({required DateTime since}) async => throw StateError('must not be called');
}

void main() {
  late PulseDatabase db;
  late InMemoryReceiptSource source;
  late _Sink sink;
  late DateTime now;
  late ReceiptService svc;

  Future<void> tx(String id, int amount, String merchant, DateTime at, {String account = 'a1', bool reviewed = false, String? cat}) =>
      db.customStatement(
        'INSERT INTO transactions (id, account_id, amount_minor, direction, posted_at, source, merchant_raw, reviewed, category_id) '
        "VALUES ('$id', '$account', $amount, 'debit', ${at.toUtc().millisecondsSinceEpoch ~/ 1000}, 'sms', '$merchant', ${reviewed ? 1 : 0}, ${cat == null ? 'NULL' : "'$cat'"})",
      );

  Future<int> txCount() async => (await db.customSelect('SELECT COUNT(*) AS n FROM transactions').getSingle()).read<int>('n');

  setUp(() async {
    db = PulseDatabase(NativeDatabase.memory());
    await db.customStatement("INSERT INTO accounts (id, type, name, last4) VALUES ('a1', 'credit_card', 'Card', '1234')");
    await db.customStatement("INSERT INTO accounts (id, type, name, last4) VALUES ('a3', 'credit_card', 'Mart card', '5678')");
    await db.customStatement("INSERT INTO accounts (id, type, name, last4) VALUES ('a2', 'credit_card', 'Other', '9999')");
    source = InMemoryReceiptSource();
    sink = _Sink();
    now = DateTime(2026, 3, 22, 12);
    svc = ReceiptService(db: db, source: source, analytics: sink, now: () => now);
  });
  tearDown(() => db.close());

  test('a matched receipt enriches the charge: notes, groceries category, link; no new row', () async {
    await tx('t1', 7400, 'TALABAT DUBAI AE', DateTime(2026, 3, 14, 10), account: 'a3', cat: 'dining');
    source.messages.add(loadReceipt('synthetic/talabat_mart_confirmed.txt', at: DateTime(2026, 3, 14, 10, 5), id: 'msg-1'));
    // not a talabat sender in this fixture? the fixture carries its own From header.
    final r = await svc.scan();
    expect(r.matched, 1);
    expect(await txCount(), 1);
    final row = await db.customSelect('SELECT category_id, receipt_ref, receipt_notes, amount_minor FROM transactions').getSingle();
    expect(row.read<String>('receipt_ref'), 'msg-1');
    expect(row.read<String>('category_id'), 'groceries');
    expect(row.read<String>('receipt_notes'), allOf(contains('Fresh Milk 2L'), contains('Delivery fee: AED 4.00')));
    expect(row.read<int>('amount_minor'), 7400);
  });

  test('a category the user already confirmed is left alone', () async {
    await tx('t1', 7400, 'TALABAT DUBAI AE', DateTime(2026, 3, 14, 10), account: 'a3', reviewed: true, cat: 'dining');
    source.messages.add(loadReceipt('synthetic/talabat_mart_confirmed.txt', at: DateTime(2026, 3, 14, 10, 5)));
    await svc.scan();
    final row = await db.customSelect('SELECT category_id, receipt_ref FROM transactions').getSingle();
    expect(row.read<String>('category_id'), 'dining');
    expect(row.read<String?>('receipt_ref'), isNotNull);
  });

  test('scanning twice, or a resent email, never links twice or duplicates', () async {
    await tx('t1', 7400, 'TALABAT DUBAI AE', DateTime(2026, 3, 14, 10), account: 'a3');
    final m = loadReceipt('synthetic/talabat_mart_confirmed.txt', at: DateTime(2026, 3, 14, 10, 5), id: 'msg-1');
    source.messages.addAll([m, loadReceipt('synthetic/talabat_mart_confirmed.txt', at: DateTime(2026, 3, 14, 10, 6), id: 'msg-2')]);
    expect((await svc.scan()).matched, 1);
    expect((await svc.scan()).matched, 0);
    expect(await txCount(), 1);
    expect(sink.events.where((e) => e.name == 'receipt_matched'), hasLength(1));
  });

  test('a receipt with no charge is held, never created as spend, then offered for review', () async {
    source.messages.add(loadReceipt('synthetic/careem_food_confirmed.txt', at: DateTime(2026, 3, 21, 20, 30), id: 'msg-c'));
    final r = await svc.scan();
    expect(r.held, 1);
    expect(await txCount(), 0);
    expect(await svc.dueForReview(), isEmpty);
    expect(await svc.waitingCount(), 1);
    now = now.add(const Duration(days: 6));
    expect(await svc.dueForReview(), hasLength(1));
    expect(await txCount(), 0, reason: 'review never creates spend by itself');
    await svc.dismiss('msg-c');
    expect(await svc.dueForReview(), isEmpty);
    await svc.scan();
    expect(await svc.waitingCount(), 0, reason: 'a dismissed receipt is not held again');
  });

  test('a held receipt links once its charge posts', () async {
    source.messages.add(loadReceipt('synthetic/careem_food_confirmed.txt', at: DateTime(2026, 3, 21, 20, 30), id: 'msg-c'));
    await svc.scan();
    await tx('t1', 6600, 'CAREEM FOOD DUBAI', DateTime(2026, 3, 21, 21));
    expect((await svc.scan()).matched, 1);
    expect(await svc.waitingCount(), 0);
  });

  test('two identical charges: held as ambiguous, nothing is linked', () async {
    await tx('t1', 6600, 'CAREEM FOOD DUBAI', DateTime(2026, 3, 21, 21));
    await tx('t2', 6600, 'CAREEM FOOD DUBAI', DateTime(2026, 3, 21, 21, 30));
    source.messages.add(loadReceipt('synthetic/careem_food_confirmed.txt', at: DateTime(2026, 3, 21, 20, 30), id: 'msg-c'));
    final r = await svc.scan();
    expect(r.matched, 0);
    expect(r.held, 1);
    expect(await db.customSelect('SELECT COUNT(*) AS n FROM transactions WHERE receipt_ref IS NOT NULL').getSingle().then((x) => x.read<int>('n')), 0);
    // The user picks one.
    expect(await svc.linkManually('msg-c', 't2'), isTrue);
    expect(await svc.linkManually('msg-c', 't1'), isFalse);
  });

  test('a charge on another card (different last 4) is not linked', () async {
    await tx('t1', 6600, 'CAREEM FOOD DUBAI', DateTime(2026, 3, 21, 21), account: 'a2');
    source.messages.add(loadReceipt('synthetic/careem_food_confirmed.txt', at: DateTime(2026, 3, 21, 20, 30)));
    expect((await svc.scan()).matched, 0);
  });

  test('noon food accepted (no amount) links on time and merchant, keeping the bank amount', () async {
    await tx('t1', 4350, 'NOON FOOD DUBAI AE', DateTime(2026, 3, 14, 11, 5));
    source.messages.add(loadReceipt('noon/noon_food_order_accepted_1.txt', at: DateTime(2026, 3, 14, 11), id: 'f1'));
    expect((await svc.scan()).matched, 1);
    final row = await db.customSelect('SELECT amount_minor, category_id, receipt_notes FROM transactions').getSingle();
    expect(row.read<int>('amount_minor'), 4350);
    expect(row.read<String>('category_id'), 'dining');
    expect(row.read<String>('receipt_notes'), contains("McDonald's"));
  });

  test('delivered emails and promos are ignored; nothing held', () async {
    source.messages.addAll([
      loadReceipt('noon/noon_shipment_delivered.txt', id: 'd1'),
      loadReceipt('synthetic/talabat_promo.txt', id: 'p1'),
    ]);
    final r = await svc.scan();
    expect(r.ignored, 2);
    expect(await svc.waitingCount(), 0);
  });

  test('an unconfigured source is never read', () async {
    final off = ReceiptService(db: db, source: _Off(), analytics: sink, now: () => now);
    expect((await off.scan()).skipped, isTrue);
  });

  test('analytics carry only the merchant kind, nothing private', () async {
    await tx('t1', 7400, 'TALABAT DUBAI AE', DateTime(2026, 3, 14, 10), account: 'a3');
    source.messages.add(loadReceipt('synthetic/talabat_mart_confirmed.txt', at: DateTime(2026, 3, 14, 10, 5)));
    await svc.scan();
    final e = sink.events.single;
    expect(e.name, 'receipt_matched');
    expect(e.properties, {'merchant': 'talabat'});
    expect(AnalyticsSchema.clean(e.name, e.properties), e.properties);
    final dirty = AnalyticsSchema.clean('receipt_matched', {'merchant': "McDonald's", 'order': '900300400', 'amount': 7400});
    expect(dirty, isEmpty);
    expect(AnalyticsSchema.specFor('receipt_matched')!.props['merchant'], isA<EnumProp>());
    expect((AnalyticsSchema.specFor('receipt_matched')!.props['merchant'] as EnumProp).values, ['noon', 'talabat', 'careem', 'other']);
  });
}
