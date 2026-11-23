import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../core/env/env.dart';
import '../core/network/api_client.dart';
import 'api/api_pulse_repository.dart';
import 'insights.dart';
import 'mock_repository.dart';
import 'models.dart';
import 'rules.dart';
import 'statements.dart';
import 'repository.dart';

/// Shared dio client (Supabase JWT interceptor). Overridden in tests.
final dioProvider = Provider<Dio>((ref) => buildApiClient());

/// API-backed when `API_BASE_URL` is defined, mock data otherwise (the demo
/// default).
final repositoryProvider = Provider<PulseRepository>(
  (ref) => Env.useApi
      ? ApiPulseRepository(ref.watch(dioProvider))
      : MockPulseRepository(),
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
}
