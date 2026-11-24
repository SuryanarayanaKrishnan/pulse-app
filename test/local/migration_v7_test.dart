import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v6.dart' as v6;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v6 to v7 keeps every category, budget and limit, and adds the flex columns and tables', () async {
    final schema = await verifier.schemaAt(6);
    final seed = v6.DatabaseAtV6(schema.newConnection());
    await seed.customStatement("INSERT INTO categories (id, slug, name, kind, is_fixed) VALUES ('rent', 'rent', 'Rent', 'expense', 1)");
    await seed.customStatement("INSERT INTO categories (id, slug, name, kind, is_fixed) VALUES ('dining', 'dining', 'Dining', 'expense', 0)");
    await seed.customStatement(
      "INSERT INTO budgets (id, category_id, month, limit_minor) VALUES ('b1', 'dining', '2026-11-01', 120000)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);

    final rows = await db.customSelect(
      'SELECT id, budget_group, rollover, rollover_start, rollover_start_minor, cycle_cost_minor, cycle_months '
      "FROM categories WHERE id IN ('rent', 'dining') ORDER BY id",
    ).get();
    expect(rows.length, 2);
    for (final r in rows) {
      expect(r.read<String?>('budget_group'), isNull, reason: r.read<String>('id'));
      expect(r.read<int>('rollover'), 0);
      expect(r.read<String?>('rollover_start'), isNull);
      expect(r.read<int>('rollover_start_minor'), 0);
      expect(r.read<int>('cycle_cost_minor'), 0);
      expect(r.read<int>('cycle_months'), 1);
    }
    final b = await db.customSelect("SELECT limit_minor FROM budgets WHERE id = 'b1'").getSingle();
    expect(b.read<int>('limit_minor'), 120000);
    for (final t in ['budget_moves', 'budget_prefs']) {
      expect((await db.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle()).read<int>('n'), 0, reason: t);
    }
    expect(PulseDatabase.currentSchemaVersion, 9);
  });

  test('a fresh v7 database stores a group, a move and the mode', () async {
    final schema = await verifier.schemaAt(7);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 9);
    await db.customStatement("INSERT INTO categories (id, name, budget_group, rollover, cycle_cost_minor, cycle_months) VALUES ('fee', 'Card fee', 'nonmonthly', 1, 36500, 12)");
    final c = await db.customSelect("SELECT budget_group, cycle_months FROM categories WHERE id = 'fee'").getSingle();
    expect(c.read<String>('budget_group'), 'nonmonthly');
    expect(c.read<int>('cycle_months'), 12);
    await db.customStatement(
      "INSERT INTO budget_moves (id, month, from_category_id, to_category_id, amount_minor) VALUES ('m1', '2026-11-01', 'a', 'b', 5000)",
    );
    final m = await db.customSelect('SELECT scope, deleted_at FROM budget_moves WHERE id = ?', variables: [Variable('m1')]).getSingle();
    expect(m.read<String>('scope'), 'me');
    expect(m.read<int?>('deleted_at'), isNull);
    await db.customStatement("INSERT INTO budget_prefs (id) VALUES ('main')");
    expect((await db.customSelect('SELECT mode FROM budget_prefs').getSingle()).read<String>('mode'), 'flex');
  });
}
