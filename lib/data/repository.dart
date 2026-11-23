import 'models.dart';

/// Data access contract. Swap [MockPulseRepository] for an API-backed
/// implementation (see `core/network/api_client.dart`) without touching UI.
abstract class PulseRepository {
  Future<List<Transaction>> transactions();

  /// Cursor-paginated listing, newest first. Pass the previous page's
  /// [TxPage.nextCursor] to continue.
  Future<TxPage> transactionsPage({String? cursor, int limit = 50});
  Future<Transaction> recategorise(String txId, SpendCategory category);
  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
  });
  Future<BudgetOverview> budgetOverview();
  Future<List<CreditCard>> myCards();
  Future<List<CreditCard>> cardCatalog();
  Future<NetWorth> netWorth();
  Future<List<Asset>> assets();
  Future<List<SplitGroup>> splitGroups();
  Future<SplitExpense> addSplitExpense(String groupId, SplitExpense expense);
}
