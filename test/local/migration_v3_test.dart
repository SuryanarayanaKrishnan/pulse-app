import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const insert =
      "INSERT INTO transactions (id, account_id, amount_minor, currency, direction, posted_at, source, "
      "exclude_from_budget, tags, sources, statement_locked, created_at) "
      "VALUES (?, 'a1', 1000, 'AED', 'debit', 0, 'sms', 0, '[]', '[]', 0, 0)";

  test('v2 to v3 adds reviewed and counts existing transactions as reviewed', () async {
    final schema = await verifier.schemaAt(2);
    final seed = v2.DatabaseAtV2(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO accounts (id, type, name, currency, created_at) VALUES ('a1', 'cash', 'Cash', 'AED', 0)",
    );
    await seed.customStatement(insert.replaceFirst('?', "'old'"));
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);

    final old = await db.select(db.transactions).getSingle();
    expect(old.reviewed, isTrue, reason: 'no backlog after an update');
  });

  test('new transactions start unreviewed', () async {
    final schema = await verifier.schemaAt(3);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
    await db.customStatement(
      "INSERT INTO accounts (id, type, name, currency, created_at) VALUES ('a1', 'cash', 'Cash', 'AED', 0)",
    );
    await db.customStatement(insert.replaceFirst('?', "'fresh'"));
    final row = await db
        .customSelect('SELECT reviewed FROM transactions WHERE id = ?', variables: [Variable('fresh')])
        .getSingle();
    expect(row.read<int>('reviewed'), 0);
    expect(PulseDatabase.currentSchemaVersion, 3);
  });
}
