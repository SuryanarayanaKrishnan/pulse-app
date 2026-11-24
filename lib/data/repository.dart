import 'dart:typed_data';

import 'api/api_exception.dart';
import 'insights.dart';
import 'models.dart';
import 'rules.dart';
import 'statements.dart';

/// Data access contract. [MockPulseRepository] is the demo default;
/// [ApiPulseRepository] talks to the backend. UI only sees this interface.
abstract class PulseRepository {
  // ---- transactions ------------------------------------------------------

  Future<List<Transaction>> transactions();

  /// Cursor-paginated listing, newest first. Pass the previous page's
  /// [TxPage.nextCursor] to continue.
  Future<TxPage> transactionsPage({String? cursor, int limit = 50});

  /// Sets the category of one transaction. [remember] also creates a
  /// merchant rule server-side; the UI asks first and uses [saveRule].
  Future<Transaction> recategorise(
    String txId,
    SpendCategory category, {
    bool remember = false,
  });
  /// Marks transactions reviewed (or not). Repositories without a ledger of
  /// their own ignore it.
  Future<void> setReviewed(Iterable<String> txIds, bool reviewed);

  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
  });

  // ---- budget & categories ------------------------------------------------

  Future<BudgetOverview> budgetOverview();

  /// Default and custom categories.
  Future<List<SpendCategory>> categories();
  Future<SpendCategory> createCategory({
    required String name,
    CategoryKind kind = CategoryKind.expense,
    String? iconKey,
  });

  /// Changes the glyph of a custom category. Returns the updated category.
  Future<SpendCategory> setCategoryIcon(SpendCategory category, String iconKey);

  /// Monthly budget for [category] (this month onwards). 0 clears it.
  Future<void> setBudget(SpendCategory category, double monthly);

  // ---- automations --------------------------------------------------------

  Future<List<AutomationRule>> rules();

  /// Creates [rule] (its id is ignored) and applies it to past transactions.
  Future<AutomationRule> saveRule(AutomationRule rule);
  Future<void> deleteRule(String id);

  // ---- cards & wealth -----------------------------------------------------

  Future<List<CreditCard>> myCards();
  Future<List<CreditCard>> cardCatalog();

  /// Adds a card from the catalog to the wallet. On-device only.
  Future<CreditCard> addCard({
    required String catalogId,
    required String last4,
    double? limit,
    int? statementDay,
    int? dueDay,
    double owed = 0,
  });

  /// Removes a card from the wallet (its transactions stay).
  Future<void> removeCard(String id);

  /// Adds a bank account, wallet or cash pot with an opening balance.
  Future<BankAccount> addBankAccount({
    required String bank,
    required String name,
    required BankAccountKind kind,
    String? last4,
    double balance = 0,
  });

  /// Adds something you own (property, gold, deposits, stocks...).
  Future<Asset> addAsset({
    required String name,
    required AssetKind kind,
    required double value,
  });

  /// How many past transactions [rule] would match, and how many of those
  /// it would change. Null when the repository cannot say.
  Future<RulePreviewSummary?> previewRule(AutomationRule rule);

  /// Bank accounts and wallets (not credit cards).
  Future<List<BankAccount>> bankAccounts();

  /// Cards ranked for a purchase, best first (`/v1/rewards/best-card`).
  Future<List<BestCardPick>> bestCard(SpendCategory category, double amount);
  Future<NetWorth> netWorth();
  Future<List<Asset>> assets();

  // ---- splits ---------------------------------------------------------------

  Future<List<SplitGroup>> splitGroups();
  Future<SplitExpense> addSplitExpense(String groupId, SplitExpense expense);
  Future<Member> addMember(
    String groupId, {
    required String name,
    String? phone,
  });

  /// Of [phoneHashes] (SHA-256 of E.164), the ones that belong to Pulse users.
  /// Only hashes leave the device.
  Future<Set<String>> matchContacts(List<String> phoneHashes);

  /// The payer reports a payment made outside the app (Aani).
  Future<SettlementRecord> markSettlementPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  });

  /// The payee confirms the money arrived.
  Future<SettlementRecord> confirmSettlement(
    String groupId,
    String settlementId,
  );

  /// Remove a settlement again (the Undo of an auto-settle).
  Future<void> undoSettlement(String groupId, String settlementId);

  // ---- monthly close ---------------------------------------------------------

  Future<List<Statement>> statements();
  Future<Reconciliation> reconciliation(String statementId);
  Future<UploadResult> uploadStatement({
    required Uint8List bytes,
    required String filename,
    String? institution,
  });
  Future<void> reprocessStatement(String statementId);
  Future<List<StatementPassword>> statementPasswords();

  /// Write-only: the password is never read back.
  Future<void> setStatementPassword(String institution, String password);

  /// Starts Gmail OAuth. Returns the consent URL to open, or null when the
  /// connection completed without a browser (demo data).
  Future<Uri?> startGmailConnect();
  Future<List<EmailConnection>> emailConnections();

  // ---- insights ----------------------------------------------------------------

  /// Income, spend and savings by month, plus the projected month-end balance.
  Future<Cashflow> cashflow();

  /// Spend per category by month, biggest categories first.
  Future<CategoryTrends> categoryTrends();

  /// Today's allowance after bills, card dues and goals.
  Future<SafeToSpend> safeToSpend();
  Future<HealthScore> healthScore();

  /// Demo only: pretend a wallet / SMS capture just arrived. Returns the
  /// captured transaction; the cards' caps are updated.
  Future<Transaction> simulateCapture();

  // ---- family ------------------------------------------------------------------

  Future<Household> household();
  Future<FamilyMember> inviteFamilyMember({
    required String name,
    required String phone,
    required String relation,
  });

  /// What [memberId] shares. Only the member themself can change it; for
  /// you this is your own privacy setting.
  Future<void> setSharing(String memberId, SharingLevel level);
}

/// Defaults for repositories without an on-device ledger (demo data, API).
mixin LocalOnlyFeatures implements PulseRepository {
  @override
  Future<SpendCategory> setCategoryIcon(SpendCategory category, String iconKey) async => category;

  @override
  Future<void> setReviewed(Iterable<String> txIds, bool reviewed) async {}

  @override
  Future<CreditCard> addCard({
    required String catalogId,
    required String last4,
    double? limit,
    int? statementDay,
    int? dueDay,
    double owed = 0,
  }) => _unsupported('Adding cards');

  @override
  Future<void> removeCard(String id) => _unsupported('Removing cards');

  @override
  Future<BankAccount> addBankAccount({
    required String bank,
    required String name,
    required BankAccountKind kind,
    String? last4,
    double balance = 0,
  }) => _unsupported('Adding accounts');

  @override
  Future<Asset> addAsset({
    required String name,
    required AssetKind kind,
    required double value,
  }) => _unsupported('Adding assets');

  @override
  Future<RulePreviewSummary?> previewRule(AutomationRule rule) async => null;

  @override
  Future<void> undoSettlement(String groupId, String settlementId) =>
      _unsupported('Settling up');
}

Future<T> _unsupported<T>(String what) => Future.error(
  ApiException(
    message: '$what is not available in this mode.',
    code: 'not_supported',
  ),
);
