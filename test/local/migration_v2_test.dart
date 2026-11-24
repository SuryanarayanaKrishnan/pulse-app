import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v1 to v2 adds the five new tables and keeps existing rows', () async {
    final schema = await verifier.schemaAt(1);
    final raw = schema.newConnection();
    final seed = PulseDatabase(raw);
    // Write v1 rows through plain SQL against the v1 layout.
    await seed.customStatement(
      "INSERT INTO assets (id, kind, name, currency, valuation_source, meta, created_at) "
      "VALUES ('a1', 'gold', 'Old gold bar', 'AED', 'manual', '{}', 0)",
    );
    await seed.customStatement(
      "INSERT INTO app_settings (key, value) VALUES ('keep', 'me')",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final assets = await db.select(db.assets).get();
    expect(assets.single.name, 'Old gold bar');
    expect(await db.setting('keep'), 'me');
    for (final t in ['price_cache', 'jewellery_items', 'document_attachments', 'fund_holdings', 'valuation_snapshots']) {
      final rows = await db.customSelect('SELECT count(*) AS n FROM $t').getSingle();
      expect(rows.read<int>('n'), 0, reason: t);
    }
  });

  test('the new tables accept rows after migrating', () async {
    final schema = await verifier.schemaAt(1);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);
    await db.customStatement(
      "INSERT INTO jewellery_items (id, name, weight_grams, karat, photo_paths, created_at) VALUES ('j', 'Ring', 8.5, 22, '[]', 0)",
    );
    await db.customStatement(
      "INSERT INTO valuation_snapshots (id, subject_kind, subject_id, snapshot_date, value_minor) VALUES ('v1','jewellery','j','2026-11-01',100)",
    );
    // One snapshot per subject and day.
    expect(
      () => db.customStatement(
        "INSERT INTO valuation_snapshots (id, subject_kind, subject_id, snapshot_date, value_minor) VALUES ('v2','jewellery','j','2026-11-01',200)",
      ),
      throwsA(anything),
    );
    final r = await db.customSelect('SELECT value_minor FROM valuation_snapshots WHERE id = ?', variables: [Variable('v1')]).getSingle();
    expect(r.read<int>('value_minor'), 100);
  });
}
