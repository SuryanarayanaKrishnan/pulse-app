import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart';

import '../core/env/env.dart';
import '../core/network/api_client.dart';
import 'api/api_pulse_repository.dart';
import 'mock_repository.dart';
import 'models.dart';
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
