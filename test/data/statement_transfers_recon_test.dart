import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';

/// A bank statement lists the card bill payment and an own-account transfer
/// next to real purchases. The first two are not spending and not "missing".
void main() {
  late PulseDatabase db;
  late LocalStatementService svc;

  Uint8List csv() => utf8.encode('''Sample Bank - Account statement
Account Number,XXXX1234

Date,Description,Debit,Credit,Balance
01/03/2026,Salary ACME LLC,,5000.00,6000.00
03/03/2026,Carrefour Marina,120.50,,5879.50
05/03/2026,Credit card payment 4455,1500.00,,4379.50
06/03/2026,IPI transfer own account,2000.00,,2379.50
09/03/2026,Ahmed Khan IPI transfer,50.00,,2329.50
''');

  setUp(() async {
    db = PulseDatabase(NativeDatabase.memory());
    svc = LocalStatementService(
      db: db,
      passwords: MemoryStatementPasswordStore(),
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
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
  });
  tearDown(() => db.close());

  test('own transfers get their own list, not "missing spend"', () async {
    final up = await svc.upload(bytes: csv(), filename: 'march.csv');
    final rec = await svc.reconciliation(up.id);
    expect(rec.ownTransfers.map((l) => l.description), [
      'Credit card payment 4455',
      'IPI transfer own account',
    ]);
    expect(rec.ownTransfers.first.reason, contains('Sample Card'));
    // Salary, groceries and a friend's transfer are still plain lines.
    expect(rec.statementOnly.map((l) => l.description), [
      'Salary ACME LLC',
      'Carrefour Marina',
      'Ahmed Khan IPI transfer',
    ]);
  });

  test('a captured leg of the payment still links to its line', () async {
    await db
        .into(db.transactions)
        .insert(
          TransactionsCompanion.insert(
            id: 'cap',
            accountId: 'bank',
            amountMinor: 150000,
            direction: 'debit',
            postedAt: DateTime.utc(2026, 3, 5, 9),
            source: 'sms',
          ),
        );
    final up = await svc.upload(bytes: csv(), filename: 'march.csv');
    final rec = await svc.reconciliation(up.id);
    expect(rec.linked, 1);
    expect(rec.ownTransfers.map((l) => l.description), [
      'IPI transfer own account',
    ]);
  });

  test('an own transfer is never offered to auto-settle', () async {
    final offered = <String>[];
    svc = LocalStatementService(
      db: db,
      passwords: MemoryStatementPasswordStore(),
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
      onTransfer: (c, minor) async => offered.add(c.name),
    );
    await svc.upload(bytes: csv(), filename: 'march.csv');
    expect(offered.any((n) => n.toLowerCase().contains('own')), isFalse);
    expect(offered, ['Ahmed Khan']);
  });
}
