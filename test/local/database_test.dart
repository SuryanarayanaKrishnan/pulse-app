import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/db_key.dart';
import 'package:pulse/data/local/default_categories.dart';
import 'package:pulse/data/local/open.dart';
import 'package:sqlite3/sqlite3.dart' as raw;

import '../support/fake_adapter.dart';
import 'package:drift_dev/api/migrations_native.dart';
import '../drift/generated/schema.dart';

String bundled() => File('test/fixtures/catalog/cards_small.json').readAsStringSync();

PulseDatabase memory() => PulseDatabase(NativeDatabase.memory());


void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  group('schema and seed', () {
    test('first open seeds the 22 default categories and the seed marker', () async {
      final db = memory();
      addTearDown(db.close);
      final cats = await db.select(db.categories).get();
      expect(cats.length, defaultCategories.length);
      expect(cats.length, 22);
      expect(cats.map((c) => c.id), contains('groceries'));
      expect(cats.firstWhere((c) => c.id == 'cc_payment').kind, 'transfer');
      expect(cats.firstWhere((c) => c.id == 'salary').kind, 'income');
      expect(await db.setting('seeded_at'), isNotNull);
      expect(await db.select(db.transactions).get(), isEmpty);
      expect(await db.select(db.accounts).get(), isEmpty);
    });

    test('seeding twice is idempotent and keeps user renames', () async {
      final db = memory();
      addTearDown(db.close);
      await (db.update(db.categories)..where((t) => t.id.equals('dining'))).write(const CategoriesCompanion(name: Value('Eating out')));
      await db.seedDefaults();
      expect((await db.select(db.categories).get()).length, 22);
      expect((await (db.select(db.categories)..where((t) => t.id.equals('dining'))).getSingle()).name, 'Eating out');
    });

    test('foreign keys are enforced', () async {
      final db = memory();
      addTearDown(db.close);
      expect(
        () => db.into(db.transactions).insert(TransactionsCompanion.insert(
          id: 't', accountId: 'missing', amountMinor: 1, direction: 'debit', postedAt: DateTime.utc(2026), source: 'manual')),
        throwsA(anything),
      );
    });

    test('external_hash is unique so a replayed message cannot double-insert', () async {
      final db = memory();
      addTearDown(db.close);
      await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'a', type: 'bank', name: 'x'));
      Future<void> add(String id) => db.into(db.transactions).insert(TransactionsCompanion.insert(
        id: id, accountId: 'a', amountMinor: 1, direction: 'debit', postedAt: DateTime.utc(2026), source: 'sms', externalHash: const Value('h')));
      await add('t1');
      expect(() => add('t2'), throwsA(anything));
    });
  });

  group('encryption at rest', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('pulse_db'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('the loaded SQLite supports encryption', () {
      final db = raw.sqlite3.openInMemory();
      addTearDown(db.close);
      expect(sqliteSupportsEncryption(db), isTrue);
    });

    test('data survives reopen with the same key and is unreadable without it', () async {
      final keys = MemoryKeyStore();
      var db = await openEncryptedDatabase(keys: keys, directory: dir, background: false);
      await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'a', type: 'bank', name: 'Salary account'));
      await db.close();

      final bytes = File('${dir.path}/pulse.db').readAsBytesSync();
      expect(String.fromCharCodes(bytes), isNot(contains('Salary account')));
      expect(String.fromCharCodes(bytes.take(16)), isNot(startsWith('SQLite format 3')));

      db = await openEncryptedDatabase(keys: keys, directory: dir, background: false);
      expect((await db.select(db.accounts).get()).single.name, 'Salary account');
      await db.close();

      final plain = raw.sqlite3.open('${dir.path}/pulse.db');
      expect(() => plain.select('select * from accounts'), throwsA(isA<raw.SqliteException>()));
      plain.close();

      final other = await openEncryptedDatabase(keys: MemoryKeyStore(), directory: dir, background: false);
      await expectLater(other.select(other.accounts).get(), throwsA(anything));
    });

    test('refuses to write plaintext when the SQLite build cannot encrypt', () {
      final db = raw.sqlite3.openInMemory();
      addTearDown(db.close);
      expect(
        () => applyEncryptionKey(db, 'k', allowPlaintext: false, encryptionSupported: false),
        throwsA(isA<EncryptionUnavailable>()),
      );
      // Tests (and only tests) may opt in.
      expect(() => applyEncryptionKey(db, 'k', allowPlaintext: true, encryptionSupported: false), returnsNormally);
    });

    test('database keys are random and url safe', () {
      final a = generateDatabaseKey(), b = generateDatabaseKey();
      expect(a, isNot(b));
      expect(a.length, greaterThanOrEqualTo(43));
      expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(a), isTrue);
    });
  });

  group('migrations', () {
    late SchemaVerifier verifier;
    setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

    test('a fresh v1 database matches the dumped v1 schema', () async {
      final connection = await verifier.startAt(1);
      final db = PulseDatabase(connection);
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, PulseDatabase.currentSchemaVersion);
    });

    test('the current schema equals the latest dump', () async {
      final schema = await verifier.schemaAt(PulseDatabase.currentSchemaVersion);
      final db = PulseDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, PulseDatabase.currentSchemaVersion);
    });
  });

  group('catalog service', () {
    test('loads the bundled catalog once and records the version', () async {
      final db = memory();
      addTearDown(db.close);
      final svc = CatalogService(db: db, bundled: () async => bundled());
      final cat = await svc.loadBundled();
      expect(cat.cards.length, 14);
      expect((await svc.cards()).length, 14);
      expect(await svc.currentVersion(), cat.version);
      await svc.loadBundled(); // no duplicates on the second run
      expect((await svc.cards()).length, 14);
    });

    test('without a backend there is nothing to check', () async {
      final db = memory();
      addTearDown(db.close);
      final svc = CatalogService(db: db, bundled: () async => bundled());
      await svc.loadBundled();
      expect(await svc.checkForUpdate(), isFalse);
    });

    Dio dioWith(Map<String, Object?> routes) =>
        Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = FakeAdapter(routes);

    Map<String, Object?> remote(int version, {List<Map<String, Object?>>? cards}) => {
      'version': version,
      'updated_on': '2027-01-01',
      'cards': cards ?? [
        {
          'id': 'new-bank-super', 'issuer': 'New Bank', 'name': 'Super',
          'reward_structure': {'unit': 'cashback', 'base_rate': 0.02},
          'verified_on': '2026-12-30', 'source': 'https://example.com/terms',
        },
      ],
    };

    test('a newer remote catalog is applied and keeps existing cards', () async {
      final db = memory();
      addTearDown(db.close);
      final svc = CatalogService(db: db, bundled: () async => bundled(), dio: dioWith({'GET /v1/catalog/cards': remote(99)}));
      await svc.loadBundled();
      expect(await svc.checkForUpdate(), isTrue);
      final cards = await svc.cards();
      expect(cards.length, 15);
      final added = cards.firstWhere((c) => c.id == 'new-bank-super');
      expect(added.verified, isTrue);
      expect(added.source, 'https://example.com/terms');
      expect(await svc.currentVersion(), 99);
    });

    test('an older, equal, empty or broken remote catalog is ignored', () async {
      for (final body in <Object?>[remote(1), remote(0), remote(99, cards: []), 'garbage', {'version': 99, 'cards': 'x'}]) {
        final db = memory();
        final svc = CatalogService(db: db, bundled: () async => bundled(), dio: dioWith({'GET /v1/catalog/cards': body}));
        await svc.loadBundled();
        expect(await svc.checkForUpdate(), isFalse, reason: '$body');
        expect((await svc.cards()).length, 14);
        await db.close();
      }
    });

    test('network failure leaves the catalog alone', () async {
      final db = memory();
      addTearDown(db.close);
      final svc = CatalogService(db: db, bundled: () async => bundled(), dio: dioWith({'GET /v1/catalog/cards': (500, {'error': 'x'})}));
      await svc.loadBundled();
      expect(await svc.checkForUpdate(), isFalse);
    });

    test('the bundled asset is newer than a stored older version and replaces it', () async {
      final db = memory();
      addTearDown(db.close);
      await db.putSetting(CatalogService.versionKey, '0');
      final svc = CatalogService(db: db, bundled: () async => bundled());
      await svc.loadBundled();
      expect((await svc.cards()).length, 14);
    });
  });

  test('CalDate sanity (engine dates are usable in the data layer)', () {
    expect(toDubaiDate(DateTime.utc(2026, 1, 1, 21)).day, 2);
    expect(Variable<int>(1).value, 1);
  });
}
