import 'dart:typed_data';

import '../core/engine/nw_history.dart';
import 'api/api_exception.dart';
import 'digit_suggestion.dart';
import 'insights.dart';
import 'models.dart';
import 'local/splits_store.dart' show NewGroupMember;
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
    DateTime? date,
    String? note,
  });

  /// Saves (or clears, when empty) your note on a payment.
  Future<void> setTransactionNote(String txId, String? note);

  /// Removes a payment from every total. Only on-device ledgers delete.
  Future<void> deleteTransaction(String txId);

  /// The salary you entered by hand, if any. It feeds cash flow until a
  /// salary credit is detected, which then confirms or updates it.
  Future<ManualSalary?> manualSalary();

  /// Sets (or clears, with null) the manual salary.
  Future<void> setManualSalary(ManualSalary? salary);

  /// Adds dated payments from an imported sheet. Ones already imported
  /// (same day, amount, name and category) are skipped, so importing the same
  /// file twice changes nothing. Returns how many were added. Only the
  /// on-device ledger takes them; others add none.
  Future<int> importTransactions(List<ImportedTransaction> txs) async => 0;

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

  /// Creates a card the catalog does not list ("I can't find my card"), on
  /// this device only. Its rewards are not tracked (no earn rates are known).
  Future<CreditCard> addCustomCatalogCard({required String issuer, required String name});

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

  /// Replaces a card's editable details. An empty value clears that detail
  /// (the next statement can fill it again).
  Future<void> updateCardDetails(
    String accountId, {
    String? last4,
    double? limit,
    int? statementDay,
    int? dueDay,
  });

  /// Sets the last four digits of a card and replays alerts that were waiting for it.
  Future<void> setCardLast4(String accountId, String last4);

  /// Alerts waiting on card digits that a digit-less card could own.
  Future<List<DigitSuggestion>> digitSuggestions();

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

  /// Renames an [Asset] with `editable` set and sets its value (for an
  /// account, its balance from now on).
  Future<void> updateAsset(String id, {required String name, required double value});

  /// Removes an [Asset] with `editable` set. An account's transactions stay.
  Future<void> deleteAsset(String id);

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

  /// Creates a group (you plus [members]). Works with no backend: the group
  /// is kept on the phone.
  Future<SplitGroup> createSplitGroup({
    required String name,
    String emoji,
    List<NewGroupMember> members,
  });
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

/// A repository that can say what net worth was on past days (stored daily
/// snapshots, with the days before the first one rebuilt from transactions).
/// Others fall back to the month-end series of [PulseRepository.netWorth].
abstract interface class NetWorthHistorySource {
  /// Oldest first; the last point is today. Assets and liabilities in minor
  /// units (fils).
  Future<List<NwPoint>> netWorthHistory();
}

/// Defaults for repositories without an on-device ledger (demo data, API).
mixin LocalOnlyFeatures implements PulseRepository {
  @override
  Future<SplitGroup> createSplitGroup({
    required String name,
    String emoji = '👥',
    List<NewGroupMember> members = const [],
  }) => _unsupported('Creating groups');

  @override
  Future<SpendCategory> setCategoryIcon(SpendCategory category, String iconKey) async => category;

  @override
  Future<void> setReviewed(Iterable<String> txIds, bool reviewed) async {}

  @override
  Future<void> setTransactionNote(String txId, String? note) => _unsupported('Notes');

  @override
  Future<void> deleteTransaction(String txId) => _unsupported('Deleting payments');

  @override
  Future<ManualSalary?> manualSalary() async => null;

  @override
  Future<void> setManualSalary(ManualSalary? salary) => _unsupported('Setting a salary');

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
  Future<void> updateCardDetails(
    String accountId, {
    String? last4,
    double? limit,
    int? statementDay,
    int? dueDay,
  }) => _unsupported('Editing cards');

  @override
  Future<void> setCardLast4(String accountId, String last4) => _unsupported('Editing cards');

  @override
  Future<List<DigitSuggestion>> digitSuggestions() async => const [];

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
  Future<void> updateAsset(String id, {required String name, required double value}) =>
      _unsupported('Editing assets');

  @override
  Future<void> deleteAsset(String id) => _unsupported('Deleting assets');

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
