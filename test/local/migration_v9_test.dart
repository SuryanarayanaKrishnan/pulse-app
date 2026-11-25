import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v8.dart' as v8;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v8 to v9 adds the receipt columns and leaves every row alone', () async {
    final schema = await verifier.schemaAt(8);
    final seed = v8.DatabaseAtV8(schema.newConnection());
    await seed.customStatement("INSERT INTO accounts (id, type, name) VALUES ('a1', 'credit_card', 'Card')");
    await seed.customStatement(
      "INSERT INTO transactions (id, account_id, amount_minor, direction, posted_at, source, notes) "
      "VALUES ('t1', 'a1', 6100, 'debit', 1790000000, 'sms', 'my note')",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    final r = await db.customSelect('SELECT amount_minor, notes, receipt_ref, receipt_notes FROM transactions').getSingle();
    expect(r.read<int>('amount_minor'), 6100);
    expect(r.read<String>('notes'), 'my note');
    expect(r.read<String?>('receipt_ref'), isNull);
    expect(r.read<String?>('receipt_notes'), isNull);
    expect(PulseDatabase.currentSchemaVersion, greaterThanOrEqualTo(10));
  });

  test('a fresh v9 database stores a receipt link and notes', () async {
    final schema = await verifier.schemaAt(9);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await db.customStatement("INSERT INTO accounts (id, type, name) VALUES ('a1', 'credit_card', 'Card')");
    await db.customStatement(
      "INSERT INTO transactions (id, account_id, amount_minor, direction, posted_at, source, receipt_ref, receipt_notes) "
      "VALUES ('t1', 'a1', 100, 'debit', 1790000000, 'sms', 'msg-1', '2 x Milk')",
    );
    final r = await db.customSelect('SELECT receipt_ref, receipt_notes FROM transactions').getSingle();
    expect(r.read<String>('receipt_ref'), 'msg-1');
    expect(r.read<String>('receipt_notes'), '2 x Milk');
  });
}
