import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v11.dart' as v11;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v11 to v12 adds ownership to jewellery and funds; existing rows start Private', () async {
    final schema = await verifier.schemaAt(11);
    final seed = v11.DatabaseAtV11(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO jewellery_items (id, name, weight_grams, karat) VALUES ('j1', 'Chain', 20.5, 22)",
    );
    await seed.customStatement(
      "INSERT INTO fund_holdings (id, kind, name, units, nav) VALUES ('f1', 'manual', 'Fund', 10, 1.5)",
    );
    await seed.customStatement(
      "INSERT INTO household_members (id, name) VALUES ('m1', 'Maya')",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 12);

    expect(PulseDatabase.currentSchemaVersion, 12);
    for (final (t, id) in [
      ('jewellery_items', 'j1'),
      ('fund_holdings', 'f1'),
    ]) {
      final r = await db
          .customSelect("SELECT owner, is_private FROM $t WHERE id = '$id'")
          .getSingle();
      expect(
        (r.read<String>('owner'), r.read<bool>('is_private')),
        ('me', true),
        reason: t,
      );
    }
    final m = await db
        .customSelect('SELECT name, removed_by FROM household_members')
        .getSingle();
    expect(
      (m.read<String>('name'), m.read<String?>('removed_by')),
      ('Maya', null),
    );

    // New rows default to Mine, not private (like the other shareable tables).
    await db.customStatement(
      "INSERT INTO jewellery_items (id, name, weight_grams, karat) VALUES ('j2', 'Ring', 5, 22)",
    );
    final n = await db
        .customSelect(
          "SELECT owner, is_private FROM jewellery_items WHERE id = 'j2'",
        )
        .getSingle();
    expect(
      (n.read<String>('owner'), n.read<bool>('is_private')),
      ('me', false),
    );
  });
}
