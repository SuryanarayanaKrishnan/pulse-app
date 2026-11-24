import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/split_settle.dart';
import 'package:pulse/core/engine/statement_transfers.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';

class _Text implements PdfTextExtractor {
  _Text(this.text);
  String text;
  @override
  Future<PdfReadResult> extract(Uint8List bytes, List<String> passwords) async =>
      PdfReadResult(PdfReadStatus.read, text);
}

const _head = 'EMIRATES NBD\nCredit Card Statement\nCard Number: 4111 11XX XXXX 1234\n'
    'Statement Period: 25 Feb 2026 to 25 Mar 2026\nStatement Date: 25 Mar 2026\n'
    'Payment Due Date: 19 Apr 2026\nCredit Limit AED 20,000.00\nPrevious Balance 0.00\n'
    'Payments / Credits 80.00\nPurchases / Charges 70.00\nTotal Amount Due AED 0.00\n'
    'Minimum Payment Due 0.00\n\nDate Description Amount (AED)\n';

void main() {
  group('transferCounterparty', () {
    test('names the person and keeps phone and IBAN tail', () {
      final c = transferCounterparty('IPI TRANSFER TO TARIQ EXAMPLE 0500000001', Direction.debit)!;
      expect(c.name, 'TARIQ EXAMPLE');
      expect(c.phone, '0500000001');
      final i = transferCounterparty('FUND TRANSFER FROM SARA SAMPLE IBAN AE070331234567890123456', Direction.credit)!;
      expect(i.name, 'SARA SAMPLE');
      expect(i.ibanTail, '3456');
    });
    test('shops, salary, card payments and nameless lines are not people', () {
      expect(transferCounterparty('CARREFOUR DUBAI AE', Direction.debit), isNull);
      expect(transferCounterparty('SALARY TRANSFER ACME LLC', Direction.credit), isNull);
      expect(transferCounterparty('CREDIT CARD PAYMENT TRANSFER', Direction.debit), isNull);
      expect(transferCounterparty('FUND TRANSFER', Direction.debit), isNull);
    });
  });

  group('statement import offers transfers to auto-settle', () {
    late PulseDatabase db;
    late List<(Counterparty, int)> calls;
    late _Text extractor;
    late LocalStatementService svc;

    setUp(() {
      db = PulseDatabase(NativeDatabase.memory());
      calls = [];
      extractor = _Text('${_head}02 Mar 2026 03 Mar 2026 CARREFOUR DUBAI AE 20.00\n'
          '05 Mar 2026 06 Mar 2026 IPI TRANSFER TO TARIQ EXAMPLE 0500000001 50.00\n'
          '07 Mar 2026 08 Mar 2026 TRANSFER FROM SARA SAMPLE 80.00 Cr\n\nTotal 70.00\n');
      svc = LocalStatementService(
        db: db,
        passwords: MemoryStatementPasswordStore(),
        extractor: extractor,
        onTransfer: (c, m) async => calls.add((c, m)),
      );
    });
    tearDown(() => db.close());

    test('each transfer line with a person is offered once, others are not', () async {
      await svc.upload(bytes: Uint8List.fromList([1]), filename: 'a.pdf');
      expect(calls.map((c) => (c.$1.name, c.$1.direction, c.$2)), [
        ('TARIQ EXAMPLE', Direction.debit, 5000),
        ('SARA SAMPLE', Direction.credit, 8000),
      ]);
    });

    test('a re-read or an overlapping statement does not settle twice', () async {
      await svc.upload(bytes: Uint8List.fromList([1]), filename: 'a.pdf');
      await svc.upload(bytes: Uint8List.fromList([2]), filename: 'b.pdf'); // same lines, other file
      expect(calls, hasLength(2));
    });

    test('a line a live capture already saw is not offered again', () async {
      await db.customStatement("INSERT INTO accounts (id, type, name) VALUES ('a1', 'credit_card', 'Card')");
      await db.customStatement(
        "INSERT INTO transactions (id, account_id, amount_minor, direction, posted_at, source) "
        "VALUES ('t1', 'a1', 5000, 'debit', ${DateTime.utc(2026, 3, 5).millisecondsSinceEpoch ~/ 1000}, 'sms')",
      );
      await svc.upload(bytes: Uint8List.fromList([1]), filename: 'a.pdf');
      expect(calls.map((c) => c.$1.name), ['SARA SAMPLE']);
    });
  });
}
