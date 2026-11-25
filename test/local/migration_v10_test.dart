import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v9.dart' as v9;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v9 to v10 adds the vault tables and leaves every row alone', () async {
    final schema = await verifier.schemaAt(9);
    final seed = v9.DatabaseAtV9(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO accounts (id, type, name) VALUES ('a1', 'credit_card', 'Card')",
    );
    await seed.customStatement(
      "INSERT INTO document_attachments (id, title, category, file_paths) VALUES ('d1', 'Title deed', 'title_deed', '[\"/x.jpg\"]')",
    );
    await seed.customStatement(
      "INSERT INTO app_settings (key, value) VALUES ('seeded_at', 'then')",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    expect(PulseDatabase.currentSchemaVersion, greaterThanOrEqualTo(10));
    expect(
      (await db.customSelect('SELECT name FROM accounts').getSingle())
          .read<String>('name'),
      'Card',
    );
    expect(
      (await db
              .customSelect('SELECT file_paths FROM document_attachments')
              .getSingle())
          .read<String>('file_paths'),
      '["/x.jpg"]',
    );
    expect(
      (await db
              .customSelect(
                "SELECT value FROM app_settings WHERE key = 'seeded_at'",
              )
              .getSingle())
          .read<String>('value'),
      'then',
    );
    expect(await db.customSelect('SELECT * FROM vault_entries').get(), isEmpty);
    expect(
      await db.customSelect('SELECT * FROM vault_nominees').get(),
      isEmpty,
    );
  });

  test(
    'a fresh v10 database stores entries and people with their defaults',
    () async {
      final schema = await verifier.schemaAt(10);
      final db = PulseDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 10);
      await db.customStatement(
        "INSERT INTO vault_entries (id, type, institution) VALUES ('v1', 'bank', 'Mashreq')",
      );
      await db.customStatement(
        "INSERT INTO vault_nominees (id, name) VALUES ('n1', 'Sara')",
      );
      final e = await db
          .customSelect(
            'SELECT title, where_to_find, photo_paths, estimated_value_minor, deleted_at FROM vault_entries',
          )
          .getSingle();
      expect(e.read<String>('title'), '');
      expect(e.read<String>('photo_paths'), '[]');
      expect(e.read<int?>('estimated_value_minor'), isNull);
      expect(e.read<int?>('deleted_at'), isNull);
      final n = await db
          .customSelect('SELECT entry_ids FROM vault_nominees')
          .getSingle();
      expect(n.read<String>('entry_ids'), '*');
    },
  );
}
