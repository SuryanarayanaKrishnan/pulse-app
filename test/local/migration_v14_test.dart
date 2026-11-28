import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v13.dart' as v13;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v13 to v14 adds the split link and keeps existing splits', () async {
    final schema = await verifier.schemaAt(13);
    final seed = v13.DatabaseAtV13(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO split_groups (id, name, emoji, created_at) "
      "VALUES ('g1', 'Flat', 'x', 0)",
    );
    await seed.customStatement(
      "INSERT INTO split_expenses (id, group_id, title, paid_by, "
      "amount_minor, participants, date) "
      "VALUES ('e1', 'g1', 'Dinner', 'me', 9000, '[\"me\"]', 0)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 14);

    final e = await db
        .customSelect('SELECT title, transaction_id FROM split_expenses')
        .getSingle();
    expect(e.read<String>('title'), 'Dinner');
    expect(e.readNullable<String>('transaction_id'), isNull);
  });
}
