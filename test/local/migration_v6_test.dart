import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/local/database.dart';

import '../drift/generated/schema.dart';
import '../drift/generated/schema_v5.dart' as v5;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('v5 to v6 keeps everything as mine and not private, and adds the household tables', () async {
    final schema = await verifier.schemaAt(5);
    final seed = v5.DatabaseAtV5(schema.newConnection());
    await seed.customStatement(
      "INSERT INTO accounts (id, type, name) VALUES ('a1', 'bank', 'Salary')",
    );
    await seed.customStatement(
      "INSERT INTO transactions (id, account_id, amount_minor, direction, posted_at, source) "
      "VALUES ('t1', 'a1', 1200, 'debit', 1760000000, 'manual')",
    );
    await seed.customStatement(
      "INSERT INTO assets (id, kind, name) VALUES ('as1', 'gold', 'Coins')",
    );
    await seed.customStatement(
      "INSERT INTO liabilities (id, kind, name, outstanding_minor) VALUES ('l1', 'loan', 'Car', 500000)",
    );
    await seed.customStatement(
      "INSERT INTO savings_goals (id, name, target_minor) VALUES ('g1', 'Trip', 2000000)",
    );
    await seed.close();

    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);

    for (final t in [
      'accounts',
      'transactions',
      'assets',
      'liabilities',
      'savings_goals',
    ]) {
      final r = await db
          .customSelect('SELECT owner, is_private FROM $t')
          .getSingle();
      expect(r.read<String>('owner'), 'me', reason: t);
      expect(r.read<int>('is_private'), 0, reason: t);
    }
    for (final t in [
      'household_configs',
      'household_members',
      'household_bills',
      'household_limits',
      'household_mirror',
    ]) {
      expect(
        (await db.customSelect('SELECT COUNT(*) AS n FROM $t').getSingle())
            .read<int>('n'),
        0,
        reason: t,
      );
    }
    expect(PulseDatabase.currentSchemaVersion, greaterThanOrEqualTo(10));
  });

  test('a fresh v6 database stores ownership and a household', () async {
    final schema = await verifier.schemaAt(6);
    final db = PulseDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 10);
    await db.customStatement(
      "INSERT INTO accounts (id, type, name, owner, is_private) VALUES ('a1', 'bank', 'Joint', 'shared', 1)",
    );
    final r = await db
        .customSelect(
          'SELECT owner, is_private FROM accounts WHERE id = ?',
          variables: [Variable('a1')],
        )
        .getSingle();
    expect(r.read<String>('owner'), 'shared');
    expect(r.read<int>('is_private'), 1);
    await db.customStatement(
      "INSERT INTO household_configs (id, name, my_member_id) VALUES ('h', 'Us', 'm1')",
    );
    await db.customStatement(
      "INSERT INTO household_mirror (kind, row_id, payload) VALUES ('transactions', 't', '{}')",
    );
    expect(
      (await db
              .customSelect('SELECT share_mine FROM household_configs')
              .getSingle())
          .read<int>('share_mine'),
      1,
    );
  });
}
