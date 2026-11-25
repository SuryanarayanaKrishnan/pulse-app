import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v10.dart' as v10;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v10 to v11 adds the investing tables and keeps gold exact', () async {
    final schema = await verifier.schemaAt(10);
    final seed = v10.DatabaseAtV10(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO jewellery_items (id, name, weight_grams, karat) VALUES ('j1', 'Chain', 20.5, 22)",
    );
    await seed.customStatement(
      "INSERT INTO fund_holdings (id, kind, name, units, nav) VALUES ('f1', 'manual', 'Fund', 10, 1.5)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 11);

    expect(PulseDatabase.currentSchemaVersion, 11);
    final j = await db
        .customSelect(
          'SELECT name, weight_grams, approximate FROM jewellery_items',
        )
        .getSingle();
    expect(
      (
        j.read<String>('name'),
        j.read<double>('weight_grams'),
        j.read<bool>('approximate'),
      ),
      ('Chain', 20.5, false),
    );
    expect(
      (await db.customSelect('SELECT name FROM fund_holdings').getSingle())
          .read<String>('name'),
      'Fund',
    );
    for (final t in [
      'investment_holdings',
      'investing_rules',
      'investing_occurrences',
    ]) {
      expect(
        await db.customSelect('SELECT * FROM $t').get(),
        isEmpty,
        reason: t,
      );
    }
  });
}
