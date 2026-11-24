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
    GoalContributions,
    RawIngests,
    NetWorthSnapshots,
    RecurringReviews,
    AppSettings,
    PriceCache,
    JewelleryItems,
    DocumentAttachments,
    FundHoldings,
    ValuationSnapshots,
  ],
)
class PulseDatabase extends _$PulseDatabase {
  PulseDatabase(super.e);

  /// Bump together with a new step in [migration] and a dump in
  /// `drift_schemas/` (`dart run drift_dev schema dump ...`).
  static const currentSchemaVersion = 5;

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
    onUpgrade: stepByStep(
      // v2: price cache, jewellery, documents, fund holdings, valuation
      // snapshots. Purely additive: nothing existing is touched.
      from1To2: (m, schema) async {
        await m.createTable(schema.priceCache);
        await m.createTable(schema.jewelleryItems);
        await m.createTable(schema.documentAttachments);
        await m.createTable(schema.fundHoldings);
        await m.createTable(schema.valuationSnapshots);
      },
      // v3: `transactions.reviewed` for swipe-to-review. Everything already in
      // the ledger counts as reviewed, so nobody opens the app to a backlog.
      from2To3: (m, schema) async {
        await m.addColumn(schema.transactions, schema.transactions.reviewed);
        await schema.database.customStatement('UPDATE transactions SET reviewed = 1');
      },
      // v4: `categories.icon_key`, the glyph picked for a custom category.
      // Null everywhere to start with; defaults resolve theirs from the slug.
      from3To4: (m, schema) async {
        await m.addColumn(schema.categories, schema.categories.iconKey);
      },
      // v5: goals. `savings_goals` gains kind, icon, link, pause and
      // completion; contributions get their own table. Additive only: goals
      // saved before keep their name, target and date as `save` goals.
      from4To5: (m, schema) async {
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.kind);
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.iconKey);
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.linkedRef);
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.paused);
        await m.addColumn(schema.savingsGoals, schema.savingsGoals.completedAt);
        await m.createTable(schema.goalContributions);
      },
    ),
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
