import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v7.dart' as v7;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v7 to v8 adds recurring_choices and carries the old reviews across', () async {
    final schema = await verifier.schemaAt(7);
    final seed = v7.DatabaseAtV7(schema.newConnection());
    await seed.customStatement("INSERT INTO recurring_reviews (series_key, status) VALUES ('acme tv', 'confirmed')");
    await seed.customStatement("INSERT INTO recurring_reviews (series_key, status) VALUES ('old gym', 'dismissed')");
    await seed.customStatement("INSERT INTO budget_prefs (id, mode) VALUES ('main', 'category')");
    await seed.customStatement("INSERT INTO categories (id, name) VALUES ('dining', 'Dining')");
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    final rows = await db.customSelect('SELECT series_key, choice, merchant FROM recurring_choices ORDER BY series_key').get();
    expect([for (final r in rows) (r.read<String>('series_key'), r.read<String>('choice'), r.read<String>('merchant'))], [
      ('acme tv', 'confirmed', ''),
      ('old gym', 'ignored', ''),
    ]);
    // Nothing else moved.
    expect((await db.customSelect('SELECT mode FROM budget_prefs').getSingle()).read<String>('mode'), 'category');
    expect((await db.customSelect("SELECT name FROM categories WHERE id = 'dining'").getSingle()).read<String>('name'), 'Dining');
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM recurring_reviews').getSingle()).read<int>('n'), 2);
    expect(PulseDatabase.currentSchemaVersion, greaterThanOrEqualTo(10));
  });

  test('a fresh v8 database stores and clears a choice', () async {
    final schema = await verifier.schemaAt(8);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await db.customStatement("INSERT INTO recurring_choices (series_key, choice) VALUES ('x', 'ignored')");
    final r = await db.customSelect('SELECT choice, merchant, decided_at FROM recurring_choices').getSingle();
    expect(r.read<String>('choice'), 'ignored');
    expect(r.read<String>('merchant'), '');
    expect(r.read<int?>('decided_at'), isNotNull);
    await db.customStatement("DELETE FROM recurring_choices WHERE series_key = 'x'");
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM recurring_choices').getSingle()).read<int>('n'), 0);
  });

}
