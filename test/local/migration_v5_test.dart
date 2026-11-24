import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/goal_store.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v4 to v5 keeps old goals as save goals and adds the contributions table', () async {
    final schema = await verifier.schemaAt(4);
    final seed = v4.DatabaseAtV4(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO savings_goals (id, name, target_minor, saved_minor, currency, target_date, monthly_contribution_minor) "
      "VALUES ('g_old', 'Emergency fund', 5000000, 100000, 'AED', '2027-06-30', 250000)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);

    final goals = await LocalGoalStore(db).goals();
    expect(goals, hasLength(1));
    final g = goals.single;
    expect(g.name, 'Emergency fund');
    expect(g.kind.key, 'save');
    expect(g.targetMinor, 5000000);
    expect(g.startMinor, 100000);
    expect(g.targetDate?.toIso(), '2027-06-30');
    expect(g.monthlyMinor, 250000);
    expect(g.paused, isFalse);
    expect(g.linkedRef, isNull);
    expect(await LocalGoalStore(db).contributions(), isEmpty);
    expect(PulseDatabase.currentSchemaVersion, 8);
  });

  test('a fresh v5 database stores a pay down goal and its contributions', () async {
    final schema = await verifier.schemaAt(5);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 8);
    await db.customStatement(
      "INSERT INTO savings_goals (id, name, target_minor, saved_minor, kind, icon_key, linked_ref, paused) "
      "VALUES ('g1', 'Clear the card', 0, 900000, 'paydown', 'fees', 'card:a1', 1)",
    );
    await db.customStatement(
      "INSERT INTO goal_contributions (id, goal_id, amount_minor, on_date, note) VALUES ('c1', 'g1', 100000, '2026-11-01', 'Bonus')",
    );
    final r = await db
        .customSelect('SELECT kind, linked_ref, paused FROM savings_goals WHERE id = ?', variables: [Variable('g1')])
        .getSingle();
    expect(r.read<String>('kind'), 'paydown');
    expect(r.read<String>('linked_ref'), 'card:a1');
    expect(r.read<int>('paused'), 1);
    final c = await LocalGoalStore(db).contributions();
    expect(c.single.amountMinor, 100000);
    expect(c.single.note, 'Bonus');
  });
}
