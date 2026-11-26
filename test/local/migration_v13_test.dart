import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v12.dart' as v12;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v12 to v13 adds the splits ledger and keeps existing data', () async {
    final schema = await verifier.schemaAt(12);
    final seed = v12.DatabaseAtV12(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO household_members (id, name) VALUES ('m1', 'Maya')",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 13);

    expect(PulseDatabase.currentSchemaVersion, 13);
    final m = await db
        .customSelect('SELECT name FROM household_members')
        .getSingle();
    expect(m.read<String>('name'), 'Maya');
    for (final t in [
      'split_groups',
      'split_members',
      'split_expenses',
      'split_settlements',
    ]) {
      final n = await db
          .customSelect('SELECT COUNT(*) AS n FROM $t')
          .getSingle();
      expect(n.read<int>('n'), 0, reason: t);
    }
  });
}
