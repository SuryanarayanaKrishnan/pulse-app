import 'dart:typed_data';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/core/engine/statement_import.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/statement_password_store.dart';
import 'package:pulse/data/statements.dart';

/// Synthetic statement (invented merchants, amounts and password) rendered to
/// a real PDF; the locked copy is encrypted with the password below.
const _password = '19804567';
Uint8List _bytes(String name) =>
    File('test/fixtures/statements/$name').readAsBytesSync();

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

  test('an open PDF is read and reconciles with its printed balance', () async {
    final r = await svc.upload(
      bytes: _bytes('synthetic_card_open.pdf'),
      filename: 's.pdf',
    );
    final s = (await svc.statements()).single;
    expect(s.id, r.id);
    expect(s.parse, ParseStatus.parsed);
    expect(s.recon, ReconStatus.matched);
    expect(s.state, CloseState.matched);
    expect(s.institution, 'enbd');
    final lines = await db.select(db.statementLines).get();
    expect(lines.length, 7);
  });

  test(
    'a locked PDF waits, then opens by itself once the password is saved',
    () async {
      await expectLater(
        svc.upload(
          bytes: _bytes('synthetic_card_locked.pdf'),
          filename: 's.pdf',
        ),
        throwsA(isA<StatementImportException>()),
      );
      expect((await svc.statements()).single.state, CloseState.needsPassword);

      await passwords.save('enbd', 'not-the-password');
      expect(await svc.retryLocked(), 0);
      expect((await svc.statements()).single.state, CloseState.needsPassword);

      await passwords.save('enbd', _password);
      expect(await svc.retryLocked(), 1);
      final s = (await svc.statements()).single;
      expect(s.state, CloseState.matched);
      expect(await db.select(db.statementLines).get(), hasLength(7));
    },
  );

  test(
    'a saved password for another bank still opens a statement of unknown bank',
    () async {
      await passwords.save('fab', _password);
      await svc.upload(
        bytes: _bytes('synthetic_card_locked.pdf'),
        filename: 's.pdf',
      );
      expect((await svc.statements()).single.state, CloseState.matched);
    },
  );

  test('the same file is not imported twice', () async {
    final a = await svc.upload(
      bytes: _bytes('synthetic_card_open.pdf'),
      filename: 'a.pdf',
    );
    final b = await svc.upload(
      bytes: _bytes('synthetic_card_open.pdf'),
      filename: 'b.pdf',
    );
    expect(b.duplicate, isTrue);
    expect(b.id, a.id);
    expect(await svc.statements(), hasLength(1));
  });

  test('a file that is not a statement fails with a message', () async {
    await expectLater(
      svc.upload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'x.pdf'),
      throwsA(isA<StatementImportException>()),
    );
    expect(await svc.statements(), isEmpty);
  });
}
