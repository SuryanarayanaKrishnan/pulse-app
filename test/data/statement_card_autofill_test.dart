import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/core/engine/statement_parser.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';

/// A card added with only its name gets limit, statement day and due day from
/// its first statement, and never overwrites what the person typed.
void main() {
  late PulseDatabase db;
  late LocalStatementService svc;

  setUp(() {
    db = PulseDatabase(NativeDatabase.memory());
    svc = LocalStatementService(
      db: db,
      passwords: MemoryStatementPasswordStore(),
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
    );
  });
  tearDown(() => db.close());

  Future<void> card(String id, {String? last4, int? limit, int? statementDay}) => db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          id: id,
          type: 'credit_card',
          name: 'Card',
          institution: const Value('Emirates NBD'),
          last4: Value(last4),
          creditLimitMinor: Value(limit),
          statementDay: Value(statementDay),
        ),
      );

  Future<void> upload() => svc.upload(
    bytes: File('test/fixtures/statements/synthetic_card_open.pdf').readAsBytesSync(),
    filename: 's.pdf',
  );

  Future<AccountRow> row(String id) => (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  test('matching digits: empty limit and days are filled from the statement', () async {
    await card('a', last4: '1234');
    await upload();
    final a = await row('a');
    expect(a.creditLimitMinor, 2000000);
    expect(a.statementDay, 25);
    expect(a.dueDay, 19);
  });

  test('a value the person entered is kept', () async {
    await card('a', last4: '1234', limit: 5000000, statementDay: 3);
    await upload();
    final a = await row('a');
    expect(a.creditLimitMinor, 5000000);
    expect(a.statementDay, 3);
    expect(a.dueDay, 19);
  });

  test('the only card of that bank without digits gets the digits too', () async {
    await card('a');
    await upload();
    final a = await row('a');
    expect(a.last4, '1234');
    expect(a.creditLimitMinor, 2000000);
  });

  test('two digit-less cards of the bank: nothing is guessed', () async {
    await card('a');
    await card('b');
    await upload();
    expect((await row('a')).creditLimitMinor, isNull);
    expect((await row('b')).creditLimitMinor, isNull);
  });

  test('a card with other digits is left alone', () async {
    await card('a', last4: '9999');
    await upload();
    expect((await row('a')).creditLimitMinor, isNull);
  });

  test('SIB summary row carries the limit', () {
    final text = File('test/fixtures/statements/layouts/sib_card.txt').readAsStringSync();
    expect(parseStatement(text, institution: 'sib')!.creditLimitMinor, 1000000);
  });
}
