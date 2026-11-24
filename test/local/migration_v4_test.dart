import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v3 to v4 adds categories.icon_key and keeps every category', () async {
    final schema = await verifier.schemaAt(3);
    final seed = v3.DatabaseAtV3(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO categories (id, slug, name, kind, is_fixed, icon, color, sort_order, is_custom, is_hidden) "
      "VALUES ('groceries', 'groceries', 'Groceries', 'expense', 0, 'shopping-basket', 'green', 30, 0, 0)",
    );
    await seed.customStatement(
      "INSERT INTO categories (id, name, kind, is_fixed, sort_order, is_custom, is_hidden) "
      "VALUES ('c_old', 'Old custom', 'expense', 0, 1000, 1, 0)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);

    final rows = {for (final c in await db.select(db.categories).get()) c.id: c};
    expect(rows.keys, containsAll(['groceries', 'c_old']));
    expect(rows['c_old']!.iconKey, isNull, reason: 'an old custom category falls back to the generic tag');
    expect(rows['groceries']!.icon, 'shopping-basket');
  });

  test('a v4 database upgraded to the current schema stores and reads an icon key', () async {
    final schema = await verifier.schemaAt(4);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);
    await db.customStatement(
      "INSERT INTO categories (id, name, kind, is_fixed, sort_order, is_custom, is_hidden, icon_key) "
      "VALUES ('c_new', 'Coffee', 'expense', 0, 1000, 1, 0, 'coffee')",
    );
    final r = await db
        .customSelect('SELECT icon_key FROM categories WHERE id = ?', variables: [Variable('c_new')])
        .getSingle();
    expect(r.read<String>('icon_key'), 'coffee');
    expect(PulseDatabase.currentSchemaVersion, 9);
  });
}
