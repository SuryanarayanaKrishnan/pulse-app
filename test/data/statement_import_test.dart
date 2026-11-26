import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/core/engine/statement_import.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';
import 'package:pulse/data/statements.dart';

/// Every way a statement file can be read or refused, with small synthetic
/// fixtures (invented merchants, amounts and password; no personal data).
Uint8List _fx(String name) {
  final f = File('test/fixtures/statement_import/$name');
  return f.existsSync()
      ? f.readAsBytesSync()
      : File('test/fixtures/statements/$name').readAsBytesSync();
}

Future<StatementImportException> _refused(
  Future<Object?> Function() run,
) async {
  try {
    await run();
  } on StatementImportException catch (e) {
    return e;
  }
  fail('expected the file to be refused');
}

void main() {
  late PulseDatabase db;
  late MemoryStatementPasswordStore passwords;
  late LocalStatementService svc;

  setUp(() {
    db = PulseDatabase(NativeDatabase.memory());
    passwords = MemoryStatementPasswordStore();
    svc = LocalStatementService(
      db: db,
      passwords: passwords,
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
    );
  });
  tearDown(() => db.close());

  group('reads', () {
    test('a text PDF', () async {
      await svc.upload(
        bytes: _fx('synthetic_card_open.pdf'),
        filename: 'card.pdf',
      );
      final s = (await svc.statements()).single;
      expect(s.state, CloseState.matched);
      expect(await db.select(db.statementLines).get(), hasLength(7));
    });

    test('a CSV with balances, and it reconciles', () async {
      await svc.upload(bytes: _fx('bank_account.csv'), filename: 'march.csv');
      final s = (await svc.statements()).single;
      expect(s.parse, ParseStatus.parsed);
      expect(s.recon, ReconStatus.matched);
      final lines = await db.select(db.statementLines).get();
      expect(lines, hasLength(4));
      expect(
        lines.where((l) => l.direction == 'credit').single.amountMinor,
        500000,
      );
      expect(s.periodStart, DateTime(2026, 3, 1));
      expect(s.periodEnd, DateTime(2026, 3, 9));
    });

    test('an Excel workbook (.xlsx) with signed amounts', () async {
      await svc.upload(bytes: _fx('bank_account.xlsx'), filename: 'march.xlsx');
      final s = (await svc.statements()).single;
      expect(s.state, CloseState.matched);
      final lines = await db.select(db.statementLines).get();
      expect(lines, hasLength(4));
      expect(
        lines
            .where((l) => l.direction == 'debit')
            .fold<int>(0, (a, l) => a + l.amountMinor),
        21050,
      );
    });

    test('a text export in a known bank layout', () async {
      final text = File('test/fixtures/statements/layouts/enbd_card.txt')
          .readAsBytesSync();
      await svc.upload(bytes: text, filename: 'enbd.txt');
      expect((await svc.statements()).single.parse, ParseStatus.parsed);
    });

    test('a CSV with unknown columns once the columns are chosen', () async {
      final bytes = _fx('unknown_columns.csv');
      final e = await _refused(
        () => svc.upload(bytes: bytes, filename: 'x.csv'),
      );
      expect(e.problem, StatementProblem.unrecognisedLayout);
      expect(e.canMapColumns, isTrue);
      expect(e.canSendSample, isTrue);
      expect(await svc.statements(), isEmpty);

      await svc.upload(
        bytes: bytes,
        filename: 'x.csv',
        rows: e.rows,
        columns: const StatementColumns(
          date: 0,
          description: 1,
          amount: 2,
          firstRow: 1,
          positiveIsDebit: false,
        ),
      );
      final lines = await (db.select(db.statementLines)).get();
      expect(lines, hasLength(3));
      expect(
        lines.where((l) => l.direction == 'credit').single.amountMinor,
        2000,
      );
      // No balances in the file: imported, not stuck on "Reading".
      expect((await svc.statements()).single.state, CloseState.imported);
    });

    test('the reconciliation sheet loads on this phone', () async {
      final r = await svc.upload(
        bytes: _fx('bank_account.csv'),
        filename: 'march.csv',
      );
      final rec = await svc.reconciliation(r.id);
      expect(rec.status, ReconStatus.matched);
      expect(rec.opening, 1000);
      expect(rec.closing, 5789.5);
      expect(rec.statementOnly, hasLength(4));
    });
  });

  group('refuses with a specific reason', () {
    test('an empty file', () async {
      final e = await _refused(
        () => svc.upload(bytes: Uint8List(0), filename: 'a.pdf'),
      );
      expect(e.problem, StatementProblem.emptyFile);
      expect(e.nextStep, contains('iCloud'));
    });

    test('a CSV with a header and no rows', () async {
      final e = await _refused(
        () => svc.upload(bytes: _fx('empty_rows.csv'), filename: 'a.csv'),
      );
      expect(e.problem, StatementProblem.unrecognisedLayout);
    });

    test('a picture', () async {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        1,
        2,
        3,
      ]);
      final e = await _refused(
        () => svc.upload(bytes: png, filename: 'shot.pdf'),
      );
      expect(e.problem, StatementProblem.wrongFormat);
      expect(e.nextStep, contains('screenshot'));
    });

    test('an old .xls workbook', () async {
      final xls = Uint8List.fromList([
        0xD0,
        0xCF,
        0x11,
        0xE0,
        0xA1,
        0xB1,
        0x1A,
        0xE1,
        0,
        0,
      ]);
      final e = await _refused(
        () => svc.upload(bytes: xls, filename: 'old.xls'),
      );
      expect(e.problem, StatementProblem.legacyExcel);
      expect(e.nextStep, contains('.xlsx'));
    });

    test('a zip that is not a workbook', () async {
      final zip = Uint8List.fromList([
        0x50,
        0x4B,
        0x03,
        0x04,
        0,
        0,
        0,
        0,
        0,
        0,
      ]);
      final e = await _refused(
        () => svc.upload(bytes: zip, filename: 'a.xlsx'),
      );
      expect(e.problem, StatementProblem.wrongFormat);
    });

    test('a binary file with no known type', () async {
      final e = await _refused(
        () => svc.upload(
          bytes: Uint8List.fromList([1, 0, 2, 0, 3]),
          filename: 'x.bin',
        ),
      );
      expect(e.problem, StatementProblem.wrongFormat);
    });

    test('a PDF that is a scan', () async {
      final e = await _refused(
        () => svc.upload(bytes: _fx('scanned.pdf'), filename: 'scan.pdf'),
      );
      expect(e.problem, StatementProblem.scannedPdf);
      expect(e.nextStep, contains('screenshot'));
      expect(await svc.statements(), isEmpty);
    });

    test('a damaged PDF', () async {
      final bad = Uint8List.fromList('%PDF-1.4\nnot really a pdf'.codeUnits);
      final e = await _refused(() => svc.upload(bytes: bad, filename: 'a.pdf'));
      expect(e.problem, StatementProblem.damaged);
    });

    test('a bank or layout Pulse does not know', () async {
      final e = await _refused(
        () => svc.upload(
          bytes: _fx('unknown_layout.pdf'),
          filename: 'letter.pdf',
        ),
      );
      expect(e.problem, StatementProblem.unsupportedBank);
      expect(e.canSendSample, isTrue);
      expect(e.canMapColumns, isFalse);
      expect(await svc.statements(), isEmpty);
    });

    test(
      'a locked PDF asks for the password and keeps the file for a retry',
      () async {
        final e = await _refused(
          () => svc.upload(
            bytes: _fx('synthetic_card_locked.pdf'),
            filename: 's.pdf',
          ),
        );
        expect(e.problem, StatementProblem.passwordNeeded);
        expect(e.statementId, isNotNull);
        expect((await svc.statements()).single.state, CloseState.needsPassword);

        await passwords.save('enbd', '19804567');
        expect(await svc.retryLocked(), 1);
        expect((await svc.statements()).single.state, CloseState.matched);
      },
    );

    test('a locked PDF whose saved password is wrong says so', () async {
      await passwords.save('enbd', 'nope');
      final e = await _refused(
        () => svc.upload(
          bytes: _fx('synthetic_card_locked.pdf'),
          filename: 's.pdf',
        ),
      );
      expect(e.problem, StatementProblem.wrongPassword);
    });
  });

  group('file kind', () {
    test('is decided by the bytes, not the name', () {
      expect(
        sniffFormat(_fx('bank_account.csv'), 'noext'),
        StatementFormat.csv,
      );
      expect(
        sniffFormat(_fx('bank_account.xlsx'), 'a.pdf'),
        StatementFormat.xlsx,
      );
      expect(sniffFormat(_fx('scanned.pdf'), 'a.csv'), StatementFormat.pdf);
    });
  });
}
