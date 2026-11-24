import 'package:drift/drift.dart';

import 'default_categories.dart';
import 'schema_versions.dart';
import 'tables.dart';

part 'database.g.dart';

/// The on-device database. Open it with `openEncryptedDatabase` in the app,
/// or `PulseDatabase.memory()` / a plain `NativeDatabase` in tests.
@DriftDatabase(
  tables: [
    Accounts,
    CatalogCards,
    UserCards,
    Categories,
    Transactions,
    Budgets,
    MerchantRules,
    Statements,
    StatementLines,
    Assets,
    Liabilities,
    SalaryRecords,
    SavingsGoals,
    RawIngests,
    NetWorthSnapshots,
    RecurringReviews,
    AppSettings,
  ],
)
class PulseDatabase extends _$PulseDatabase {
  PulseDatabase(super.e);

  /// Bump together with a new step in [migration] and a dump in
  /// `drift_schemas/` (`dart run drift_dev schema dump ...`).
  static const currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await seedDefaults();
    },
    // Each schema change: bump [currentSchemaVersion], dump the schema
    // (`dart run drift_dev schema dump lib/data/local/database.dart drift_schemas/`),
    // regenerate steps (`schema steps drift_schemas/ lib/data/local/schema_versions.dart`)
    // and add a `fromNToN+1` callback below. Never drop user data.
    onUpgrade: stepByStep(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      if (!details.wasCreated) await seedDefaults();
    },
  );

  /// Idempotent first-run seed: the default categories. (The card catalog is
  /// loaded by `CatalogService`.)
  Future<void> seedDefaults() async {
    await batch((b) {
      for (final c in defaultCategories) {
        b.insert(
          categories,
          CategoriesCompanion.insert(
            id: c.slug,
            slug: Value(c.slug),
            name: c.name,
            kind: Value(c.kind),
            isFixed: Value(c.isFixed),
            icon: Value(c.icon),
            color: Value(c.color),
            sortOrder: Value(c.order),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
    await into(appSettings).insert(
      AppSettingsCompanion.insert(key: 'seeded_at', value: DateTime.now().toUtc().toIso8601String()),
      mode: InsertMode.insertOrIgnore,
    );
  }

  Future<String?> setting(String key) async {
    final row = await (select(appSettings)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> putSetting(String key, String value) => into(appSettings).insertOnConflictUpdate(
    AppSettingsCompanion.insert(key: key, value: value),
  );
}
