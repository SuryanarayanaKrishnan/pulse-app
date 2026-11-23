import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mock_repository.dart';
import 'models.dart';
import 'repository.dart';

/// Swap this for an API-backed repository to go live.
final repositoryProvider = Provider<PulseRepository>(
  (ref) => MockPulseRepository(),
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
