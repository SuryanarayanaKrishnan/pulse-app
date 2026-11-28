import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show OrderingTerm, Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/core/engine/own_transfers.dart';
import 'package:pulse/core/engine/types.dart' show TxnSource;
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';

/// A statement's lines become transactions without ever duplicating what an
/// SMS, a tap or an earlier statement already produced.
void main() {
  late PulseDatabase db;
  late IngestPipeline pipeline;
  late LocalStatementService svc;

  Uint8List csv(List<String> rows, {String account = 'XXXX1234'}) =>
      utf8.encode(
        'Sample Bank - Account statement\nAccount Number,$account\n\n'
        'Date,Description,Debit,Credit,Balance\n${rows.join('\n')}\n',
      );
  const salary = '01/03/2026,Salary ACME LLC,,5000.00,6000.00';
  const carrefour = '03/03/2026,Carrefour Marina,120.50,,5879.50';
  const careem = '05/03/2026,Careem Ride,35.00,,5844.50';
  const netflix = '09/03/2026,Netflix,55.00,,5789.50';

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    pipeline = IngestPipeline(db, clock: () => DateTime.utc(2026, 3, 20));
    addTearDown(pipeline.dispose);
    svc = LocalStatementService(
      db: db,
      passwords: MemoryStatementPasswordStore(),
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
      pipeline: pipeline,
    );
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'bank',
            type: 'bank',
            name: 'Sample Current',
            institution: const Value('Sample Bank'),
            last4: const Value('1234'),
          ),
        );
  });

  Future<List<TxRow>> live() =>
      (db.select(db.transactions)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.postedAt)]))
          .get();

  Future<IngestOutcome> sms(
    int minor,
    String merchant,
    DateTime at, {
    String direction = 'debit',
    String last4 = '1234',
  }) => pipeline.ingest(
    IngestInput(
      channel: TxnSource.sms,
      externalId: 'sms-$minor-${at.millisecondsSinceEpoch}',
      receivedAt: at,
      fields: IngestFields(
        amountMinor: minor,
        merchant: merchant,
        last4: last4,
        direction: direction,
        postedAt: at,
      ),
    ),
  );

  test('lines nothing captured become statement transactions', () async {
    await svc.upload(
      bytes: csv([salary, carrefour, careem, netflix]),
      filename: 'march.csv',
    );
    final rows = await live();
    expect(rows, hasLength(4));
    expect(rows.every((r) => r.source == 'statement'), isTrue);
    expect(rows.every((r) => r.statementLocked), isTrue);
    expect(rows.every((r) => r.accountId == 'bank'), isTrue);
    expect(
      rows.firstWhere((r) => r.merchantRaw == 'Salary ACME LLC').categoryId,
      'salary',
    );
    expect(
      rows.firstWhere((r) => r.merchantRaw == 'Netflix').amountMinor,
      5500,
    );
  });

  test('a captured purchase is merged into, never duplicated', () async {
    await sms(12050, 'CARREFOUR MARINA', DateTime.utc(2026, 3, 3, 14, 20));
    await svc.upload(
      bytes: csv([salary, carrefour, careem]),
      filename: 'march.csv',
    );
    final rows = await live();
    expect(rows, hasLength(3), reason: 'salary, careem and one carrefour');
    final c = rows.firstWhere((r) => r.amountMinor == 12050);
    expect(c.source, 'sms');
    expect(jsonDecode(c.sources), containsAll(['sms', 'statement']));
    expect(c.statementLocked, isTrue);
    // The captured time of day is kept.
    expect(c.postedAt.toUtc(), DateTime.utc(2026, 3, 3, 14, 20));
  });

  test(
    'the same statement twice, or an overlapping one, adds nothing',
    () async {
      await svc.upload(bytes: csv([carrefour, careem]), filename: 'a.csv');
      expect(await live(), hasLength(2));
      await svc.upload(bytes: csv([carrefour, careem]), filename: 'b.csv');
      // Overlap: the same two lines plus a new one.
      await svc.upload(
        bytes: csv([carrefour, careem, netflix]),
        filename: 'c.csv',
      );
      final rows = await live();
      expect(rows, hasLength(3));
    },
  );

  test('two identical lines on one day stay two transactions', () async {
    await svc.upload(
      bytes: csv([
        '03/03/2026,Coffee Corner,18.00,,5000.00',
        '03/03/2026,Coffee Corner,18.00,,4982.00',
      ]),
      filename: 'two.csv',
    );
    expect(await live(), hasLength(2));
    // Read again: still two.
    await svc.upload(
      bytes: csv([
        '03/03/2026,Coffee Corner,18.00,,5000.00',
        '03/03/2026,Coffee Corner,18.00,,4982.00',
        careem,
      ]),
      filename: 'two-b.csv',
    );
    expect(await live(), hasLength(3));
  });

  test(
    'a later SMS for a statement purchase merges into the statement row',
    () async {
      await svc.upload(bytes: csv([careem]), filename: 'march.csv');
      final o = await sms(3500, 'CAREEM', DateTime.utc(2026, 3, 5, 18, 0));
      expect(o.status, IngestStatus.merged);
      final rows = await live();
      expect(rows, hasLength(1));
      expect(
        jsonDecode(rows.single.sources),
        containsAll(['statement', 'sms']),
      );
    },
  );

  test(
    'a card bill line is flagged, kept out of spending and paired',
    () async {
      await db
          .into(db.accounts)
          .insert(
            AccountsCompanion.insert(
              id: 'card',
              type: 'credit_card',
              name: 'Sample Card',
              institution: const Value('Sample Bank'),
              last4: const Value('4455'),
            ),
          );
      // The card's own SMS already saw the payment arrive.
      await sms(
        150000,
        'PAYMENT RECEIVED',
        DateTime.utc(2026, 3, 5, 9),
        direction: 'credit',
        last4: '4455',
      );
      await svc.upload(
        bytes: csv(['05/03/2026,Credit card payment 4455,1500.00,,4379.50']),
        filename: 'march.csv',
      );
      final rows = await live();
      expect(rows, hasLength(2));
      final bill = rows.firstWhere((r) => r.accountId == 'bank');
      expect(bill.excludeFromBudget, isTrue);
      expect(jsonDecode(bill.tags), contains(ownTransferTag));
      expect(bill.categoryId, 'cc_payment');
      expect(bill.reviewed, isFalse);
      final card = rows.firstWhere((r) => r.accountId == 'card');
      expect(jsonDecode(card.tags), contains('$linkTagPrefix${bill.id}'));
    },
  );

  test('a statement for an unknown account imports nothing', () async {
    await db.delete(db.accounts).go();
    await svc.upload(bytes: csv([carrefour]), filename: 'march.csv');
    expect(await live(), isEmpty);
  });

  test('the reconciliation sheet counts imported lines as matched', () async {
    final up = await svc.upload(
      bytes: csv([salary, carrefour, careem, netflix]),
      filename: 'march.csv',
    );
    final rec = await svc.reconciliation(up.id);
    expect(rec.linked, 4);
    expect(rec.statementOnly, isEmpty);
    expect(rec.capturedOnly, isEmpty);
  });
}
