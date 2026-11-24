import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../core/env/env.dart';
import '../core/network/api_client.dart';
import 'api/api_pulse_repository.dart';
import 'card_ranking.dart';
import 'insights.dart';
import 'local/catalog_service.dart';
import 'local/database.dart';
import 'local/ingest_pipeline.dart';
import 'local/local_repository.dart';
import 'mock_repository.dart';
import 'models.dart';
import 'rules.dart';
import 'statements.dart';
import 'repository.dart';

/// Shared dio client (Supabase JWT interceptor). Overridden in tests.
final dioProvider = Provider<Dio>((ref) => buildApiClient());

/// The encrypted on-device database. Opened in `main`; null in widget tests
/// and previews, which then run on demo data.
final localDatabaseProvider = Provider<PulseDatabase?>((ref) => null);

/// The card catalog (bundled, refreshed from the backend when configured).
final catalogServiceProvider = Provider<CatalogService?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null ? null : CatalogService(db: db);
});

/// The on-device ingest pipeline every capture channel feeds.
final ingestPipelineProvider = Provider<IngestPipeline?>((ref) {
  final db = ref.watch(localDatabaseProvider);
  if (db == null) return null;
  final p = IngestPipeline(db);
  ref.onDispose(p.dispose);
  return p;
});

/// What runs where:
///  * on-device (default): [LocalPulseRepository] over the encrypted DB;
///  * `DEMO_DATA=true` (or no database, as in tests): [MockPulseRepository];
///  * with `API_BASE_URL`, [ApiPulseRepository] serves only the shared
///    features (splits, family, statements, Gmail).
final repositoryProvider = Provider<PulseRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final catalog = ref.watch(catalogServiceProvider);
  final pipeline = ref.watch(ingestPipelineProvider);
  if (Env.demoData || db == null || catalog == null || pipeline == null) {
    return MockPulseRepository();
  }
  return LocalPulseRepository(
    db: db,
    catalog: catalog,
    pipeline: pipeline,
    shared: Env.useApi ? ApiPulseRepository(ref.watch(dioProvider)) : null,
  );
});

/// Every capture that produced a new transaction, as it happens.
final captureOutcomesProvider = StreamProvider<IngestOutcome>(
  (ref) => ref.watch(ingestPipelineProvider)?.results ?? const Stream.empty(),
);

final transactionsProvider = FutureProvider<List<Transaction>>(
  (ref) => ref.watch(repositoryProvider).transactions(),
);
final budgetProvider = FutureProvider<BudgetOverview>(
  (ref) => ref.watch(repositoryProvider).budgetOverview(),
);
final myCardsProvider = FutureProvider<List<CreditCard>>(
  (ref) => ref.watch(repositoryProvider).myCards(),
);
final catalogProvider = FutureProvider<List<CreditCard>>(
  (ref) => ref.watch(repositoryProvider).cardCatalog(),
);
final netWorthProvider = FutureProvider<NetWorth>(
  (ref) => ref.watch(repositoryProvider).netWorth(),
);
final assetsProvider = FutureProvider<List<Asset>>(
  (ref) => ref.watch(repositoryProvider).assets(),
);
final splitGroupsProvider = FutureProvider<List<SplitGroup>>(
  (ref) => ref.watch(repositoryProvider).splitGroups(),
);
final categoriesProvider = FutureProvider<List<SpendCategory>>(
  (ref) => ref.watch(repositoryProvider).categories(),
);
final rulesProvider = FutureProvider<List<AutomationRule>>(
  (ref) => ref.watch(repositoryProvider).rules(),
);
final statementsProvider = FutureProvider<List<Statement>>(
  (ref) => ref.watch(repositoryProvider).statements(),
);
final statementPasswordsProvider = FutureProvider<List<StatementPassword>>(
  (ref) => ref.watch(repositoryProvider).statementPasswords(),
);
final emailConnectionsProvider = FutureProvider<List<EmailConnection>>(
  (ref) => ref.watch(repositoryProvider).emailConnections(),
);

final cashflowProvider = FutureProvider<Cashflow>(
  (ref) => ref.watch(repositoryProvider).cashflow(),
);
final categoryTrendsProvider = FutureProvider<CategoryTrends>(
  (ref) => ref.watch(repositoryProvider).categoryTrends(),
);
final safeToSpendProvider = FutureProvider<SafeToSpend>(
  (ref) => ref.watch(repositoryProvider).safeToSpend(),
);
final healthScoreProvider = FutureProvider<HealthScore>(
  (ref) => ref.watch(repositoryProvider).healthScore(),
);
final bankAccountsProvider = FutureProvider<List<BankAccount>>(
  (ref) => ref.watch(repositoryProvider).bankAccounts(),
);

/// Best card for each everyday category, for a nominal AED 100 purchase.
final bestByCategoryProvider =
    FutureProvider<List<(SpendCategory, String, BestCardPick?)>>((ref) async {
      ref.watch(myCardsProvider);
      final repo = ref.watch(repositoryProvider);
      return [
        for (final (cat, label) in bestCardCategories)
          (cat, label, (await repo.bestCard(cat, 100)).firstOrNull),
      ];
    });

final householdProvider = FutureProvider<Household>(
  (ref) => ref.watch(repositoryProvider).household(),
);

/// Refreshes everything derived from transactions.
void invalidateLedger(WidgetRef ref) {
  ref.invalidate(transactionsProvider);
  ref.invalidate(budgetProvider);
  ref.invalidate(cashflowProvider);
  ref.invalidate(categoryTrendsProvider);
  ref.invalidate(safeToSpendProvider);
  ref.invalidate(healthScoreProvider);
  ref.invalidate(bankAccountsProvider);
  ref.invalidate(bestByCategoryProvider);
  ref.invalidate(netWorthProvider);
  ref.invalidate(assetsProvider);
}

/// Refreshes everything after the wallet itself changed (a card, an account
/// or an asset was added or removed).
void invalidateWallet(WidgetRef ref) {
  ref.invalidate(myCardsProvider);
  ref.invalidate(catalogProvider);
  invalidateLedger(ref);
}
