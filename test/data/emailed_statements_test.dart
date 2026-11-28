import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/emailed_statements.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/repository.dart';
import 'package:pulse/data/statement_password_store.dart';
import 'package:pulse/data/statements.dart';

class _Files implements StatementFileSource {
  _Files(this.files);
  final Map<String, Uint8List> files;
  final fetched = <String>[];
  bool offline = false;

  @override
  Future<Uint8List> statementFile(String id) async {
    if (offline) throw StateError('offline');
    fetched.add(id);
    return files[id]!;
  }
}

Statement _remote(String id, {String source = 'gmail', String? sha}) =>
    Statement(
      id: id,
      institution: null,
      accountLabel: 'x',
      parse: ParseStatus.parsed,
      recon: ReconStatus.pending,
      source: source,
      filename: 'march.csv',
      fileSha256: sha,
    );

void main() {
  late PulseDatabase db;
  late LocalStatementService svc;
  late _Files files;

  final csv = Uint8List.fromList(
    utf8.encode(
      'Sample Bank - Account statement\nAccount Number,XXXX1234\n\n'
      'Date,Description,Debit,Credit,Balance\n'
      '01/03/2026,Salary ACME LLC,,5000.00,6000.00\n'
      '03/03/2026,Carrefour Marina,120.50,,5879.50\n',
    ),
  );

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final pipeline = IngestPipeline(db, clock: () => DateTime.utc(2026, 3, 20));
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
    files = _Files({'s1': csv});
  });

  Future<int> run(List<Statement> remote) =>
      pullEmailedStatements(db: db, service: svc, files: files, remote: remote);

  Future<int> txCount() async => (await (db.select(
    db.transactions,
  )..where((t) => t.deletedAt.isNull())).get()).length;

  test(
    'an emailed statement is read on the phone and becomes transactions',
    () async {
      expect(await run([_remote('s1')]), 1);
      expect(await txCount(), 2);
      final st = await db.select(db.statements).getSingle();
      expect(st.source, 'gmail');
    },
  );

  test('each statement is fetched once, however often it runs', () async {
    await run([_remote('s1')]);
    expect(await run([_remote('s1')]), 0);
    expect(files.fetched, ['s1']);
    expect(await txCount(), 2);
  });

  test('uploads and non-email statements are left alone', () async {
    expect(await run([_remote('s1', source: 'upload')]), 0);
    expect(files.fetched, isEmpty);
  });

  test('a file already on the phone is not downloaded again', () async {
    await svc.upload(bytes: csv, filename: 'march.csv');
    final sha = (await db.select(db.statements).getSingle()).fileSha256;
    expect(await run([_remote('s1', sha: sha)]), 0);
    expect(files.fetched, isEmpty);
    expect(await txCount(), 2);
  });

  test('offline tries again next time', () async {
    files.offline = true;
    expect(await run([_remote('s1')]), 0);
    files.offline = false;
    expect(await run([_remote('s1')]), 1);
    expect(await txCount(), 2);
  });
}
