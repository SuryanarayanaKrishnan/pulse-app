import 'package:material_ui/material_ui.dart';

import '../core/engine/card_art.dart';

/// How a transaction entered the system. Automation is the norm.
enum TxSource {
  statement('Statement', Icons.description_rounded, true),
  sms('SMS', Icons.sms_rounded, true),
  walletNotification('Wallet', Icons.account_balance_wallet_rounded, true),
  applePayShortcut('Apple Pay', Icons.apple, true),
  manual('Manual', Icons.edit_rounded, false);

  const TxSource(this.label, this.icon, this.automatic);
  final String label;
  final IconData icon;
  final bool automatic;
}

enum CategoryKind { expense, income, transfer }

/// A budget category: one of the default set or a user-created one.
///
/// Ids of the defaults match the backend slugs. Equality is by [id].
@immutable
class SpendCategory {
  const SpendCategory(
    this.id,
    this.label, {
    this.kind = CategoryKind.expense,
    this.custom = false,
    this.iconKey,
  });

  /// A user-created category. [iconKey] is the glyph they picked from the
  /// category icon family (null: the generic tag).
  const SpendCategory.custom(
    this.id,
    this.label, {
    this.iconKey,
    this.kind = CategoryKind.expense,
  }) : custom = true;

  final String id;
  final String label;

  /// The chosen glyph of a custom category. Defaults ignore it: their glyph
  /// comes from the id (see `core/icons`).
  final String? iconKey;
  final CategoryKind kind;
  final bool custom;

  /// Stable key (analytics, routes). Same as [id].
  String get name => id;
  bool get isIncome => kind == CategoryKind.income;
  bool get isTransfer => kind == CategoryKind.transfer;

  static const salary = SpendCategory(
    'salary',
    'Salary',
    kind: CategoryKind.income,
  );
  static const groceries = SpendCategory('groceries', 'Groceries');
  static const dining = SpendCategory('dining', 'Dining & Delivery');
  static const transport = SpendCategory('transport', 'Transport & Fuel');
  static const carLoan = SpendCategory('car_loan', 'Car Loan');
  static const homeLoan = SpendCategory('home_loan', 'Home Loan');
  static const rent = SpendCategory('rent', 'Rent & Housing');
  static const utilities = SpendCategory('utilities', 'Utilities');
  static const telecom = SpendCategory('telecom', 'Telecom');
  static const fixedExpenses = SpendCategory(
    'fixed_expenses',
    'Fixed Expenses',
  );
  static const education = SpendCategory('education', 'Education Fees');
  static const health = SpendCategory('health', 'Health');
  static const shopping = SpendCategory('shopping', 'Shopping');
  static const travel = SpendCategory('travel', 'Travel');
  static const entertainment = SpendCategory('entertainment', 'Entertainment');
  static const family = SpendCategory('family', 'Family & Remittances');
  static const savings = SpendCategory('savings', 'Savings & Investments');
  static const cardPayments = SpendCategory(
    'cc_payment',
    'Credit Card Payments',
    kind: CategoryKind.transfer,
  );
  static const fees = SpendCategory('fees', 'Fees');
  static const other = SpendCategory('other', 'Other');

  /// The income bucket.
  static const income = salary;

  /// The default set, in display order.
  static const defaults = [
    salary,
    groceries,
    dining,
    transport,
    carLoan,
    homeLoan,
    rent,
    utilities,
    telecom,
    fixedExpenses,
    education,
    health,
    shopping,
    travel,
    entertainment,
    family,
    savings,
    cardPayments,
    fees,
    other,
  ];

  /// Alias of [defaults], for code that iterates "all categories" without a
  /// repository (custom ones come from `categoriesProvider`).
  static const values = defaults;

  static SpendCategory? byId(String? id) {
    for (final c in defaults) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is SpendCategory && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SpendCategory($id)';
}

/// A payment read from a sheet the user brought, before it is stored.
class ImportedTransaction {
  const ImportedTransaction({
    required this.date,
    required this.merchant,
    required this.amountMinor,
    required this.category,
    this.isIncome = false,
  });
  final DateTime date;
  final String merchant;
  final int amountMinor;
  final SpendCategory category;
  final bool isIncome;
}

class Transaction {
  const Transaction({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
    required this.source,
    required this.cardId,
    required this.accountLabel,
    this.isIncome = false,
    this.excluded = false,
    this.rawDescription,
    this.reviewed = true,
    this.confidence = 1,
    this.receiptNotes,
    this.receiptRef,
    this.pendingHold = false,
    this.note,
    this.learned = false,
    this.guess = false,
  });

  final String id;
  final String merchant;

  /// The category was filled in from this person's own earlier choice for the
  /// same merchant (not a rule, not a default).
  final bool learned;

  /// The category is a best guess for a super-app (Noon, Careem...) and
  /// the row shows one-tap category chips until it is confirmed.
  final bool guess;

  /// Your own note on this payment. Null when there is none.
  final String? note;

  /// A card pre-authorisation still waiting for its final charge or release.
  /// Shown as pending and left out of budgets until it settles.
  final bool pendingHold;

  /// Item-level notes taken from a matched email receipt (extracted fields
  /// only), and the id of that email. Null when no receipt was matched.
  final String? receiptNotes;
  final String? receiptRef;

  /// Always positive; direction given by [isIncome].
  final double amount;
  final SpendCategory category;
  final DateTime date;
  final TxSource source;
  final String cardId;
  final String accountLabel;
  final bool isIncome;

  /// Hidden from budgets and totals (an automation rule excluded it).
  final bool excluded;

  /// The text as captured (SMS body line, statement description), before
  /// merchant clean-up.
  final String? rawDescription;

  /// You have looked at it and it is right (swipe-to-review).
  final bool reviewed;

  /// How sure Pulse is of the category, 0 to 1.
  final double confidence;
  String get description => rawDescription ?? merchant;

  double get signed => isIncome ? amount : -amount;

  Transaction copyWith({
    SpendCategory? category,
    String? merchant,
    bool? excluded,
    bool? reviewed,
    double? confidence,
    String? note,
    bool clearNote = false,
  }) => Transaction(
    id: id,
    merchant: merchant ?? this.merchant,
    amount: amount,
    category: category ?? this.category,
    date: date,
    source: source,
    cardId: cardId,
    accountLabel: accountLabel,
    isIncome: isIncome,
    excluded: excluded ?? this.excluded,
    rawDescription: rawDescription,
    reviewed: reviewed ?? this.reviewed,
    confidence: confidence ?? this.confidence,
    receiptNotes: receiptNotes,
    receiptRef: receiptRef,
    pendingHold: pendingHold,
    learned: learned,
    guess: guess,
    note: clearNote ? null : (note ?? this.note),
  );
}

/// A salary the user typed in: the amount and the day of the month it lands.
class ManualSalary {
  const ManualSalary({required this.amountMinor, required this.day});
  final int amountMinor;

  /// 1 to 31; shorter months use their last day.
  final int day;
}

/// One page of a cursor-paginated transaction listing.
class TxPage {
  const TxPage(this.items, {this.nextCursor});
  final List<Transaction> items;

  /// Opaque cursor for the next page; null when this is the last page.
  final String? nextCursor;
  bool get hasMore => nextCursor != null;
}

enum CardNetwork { visa, mastercard, amex }

class CreditCard {
  const CreditCard({
    required this.id,
    required this.issuer,
    required this.name,
    required this.last4,
    required this.network,
    required this.gradient,
    required this.limit,
    required this.balance,
    required this.dueDate,
    required this.minDue,
    required this.rewardsLabel,
    required this.rewardPoints,
    required this.rewardValueAed,
    required this.categoryRates,
    this.annualFee = 0,
    this.owned = true,
    this.highlight = '',
    this.statementDate,
    this.statementBalance,
    this.baseRate = 0.5,
    this.caps = const {},
    this.rulesVerifiedOn,
    this.catalogId,
    this.art,
    this.hasDueDate = true,
    this.statementDay,
    this.dueDay,
  });

  final String id;
  final String issuer;
  final String name;
  final String last4;
  final CardNetwork network;

  /// False when the card has no due day set: [dueDate] is then a placeholder
  /// and must not be shown or counted in upcoming dues.
  final bool hasDueDate;

  /// Day of the month the statement closes and the payment falls due, when set.
  final int? statementDay, dueDay;

  /// The catalog product this card is, when known; picks the card's art.
  final String? catalogId;

  /// Face art from the catalog (`perks.art`), when it has any.
  final CardArtSpec? art;
  final List<Color> gradient;
  final double limit;
  final double balance;
  final DateTime dueDate;
  final double minDue;
  final String rewardsLabel;
  final int rewardPoints;
  final double rewardValueAed;

  /// Cashback / reward rate (percent) by category.
  final Map<SpendCategory, double> categoryRates;
  final double annualFee;
  final bool owned;
  final String highlight;

  /// Last statement date; the due date follows it.
  final DateTime? statementDate;

  /// Full amount due on the last statement (pay this to avoid interest).
  final double? statementBalance;

  /// Rate (percent) for categories without a specific rate, and once a
  /// category's cap is used up.
  final double baseRate;

  /// Monthly reward caps by category, in AED of reward.
  final Map<SpendCategory, RewardCap> caps;

  /// When the reward rules above were last checked against the issuer's
  /// published terms.
  final DateTime? rulesVerifiedOn;

  double get utilisation => limit == 0 ? 0 : balance / limit;
  double get totalDue => statementBalance ?? balance;

  CreditCard copyWith({
    double? balance,
    Map<SpendCategory, RewardCap>? caps,
    bool? hasDueDate,
    String? last4,
    double? limit,
    bool? owned,
    int? statementDay,
    int? dueDay,
  }) => CreditCard(
    id: id,
    issuer: issuer,
    name: name,
    last4: last4 ?? this.last4,
    network: network,
    gradient: gradient,
    limit: limit ?? this.limit,
    balance: balance ?? this.balance,
    dueDate: dueDate,
    minDue: minDue,
    rewardsLabel: rewardsLabel,
    rewardPoints: rewardPoints,
    rewardValueAed: rewardValueAed,
    categoryRates: categoryRates,
    annualFee: annualFee,
    owned: owned ?? this.owned,
    highlight: highlight,
    statementDate: statementDate,
    statementBalance: statementBalance,
    baseRate: baseRate,
    caps: caps ?? this.caps,
    rulesVerifiedOn: rulesVerifiedOn,
    catalogId: catalogId,
    art: art,
    hasDueDate: hasDueDate ?? this.hasDueDate,
    statementDay: statementDay ?? this.statementDay,
    dueDay: dueDay ?? this.dueDay,
  );
}

/// A monthly cap on the reward a card pays for a category (AED of reward).
class RewardCap {
  const RewardCap({required this.limit, this.used = 0});
  final double limit;
  final double used;
  double get remaining => (limit - used).clamp(0, limit).toDouble();
  bool get reached => remaining <= 0.005;
  double get progress => limit == 0 ? 1 : (used / limit).clamp(0, 1).toDouble();
  RewardCap add(double reward) => RewardCap(limit: limit, used: used + reward);
}

class BudgetLine {
  const BudgetLine({
    required this.category,
    required this.planned,
    required this.spent,
  });
  final SpendCategory category;
  final double planned;
  final double spent;
  double get progress => planned == 0 ? 0 : spent / planned;
}

class MerchantTotal {
  const MerchantTotal(this.merchant, this.category, this.total, this.count);
  final String merchant;
  final SpendCategory category;
  final double total;
  final int count;
}

class MonthlyTotal {
  const MonthlyTotal(this.label, this.spent, this.planned);
  final String label;
  final double spent;
  final double planned;
}

class BudgetOverview {
  const BudgetOverview({
    required this.planned,
    required this.spent,
    required this.daysLeft,
    required this.daysInMonth,
    required this.lines,
    required this.trend,
    required this.topMerchants,
    required this.byCard,
    required this.byAccount,
    required this.autoCaptured,
    required this.manual,
  });

  final double planned;
  final double spent;
  final int daysLeft;
  final int daysInMonth;
  final List<BudgetLine> lines;
  final List<MonthlyTotal> trend;
  final List<MerchantTotal> topMerchants;
  final Map<String, double> byCard;
  final Map<String, double> byAccount;
  final int autoCaptured;
  final int manual;

  double get remaining => planned - spent;
  double get safePerDay =>
      daysLeft <= 0 ? 0 : (remaining < 0 ? 0 : remaining / daysLeft);
  double get progress => planned == 0 ? 0 : spent / planned;
  double get autoShare {
    final total = autoCaptured + manual;
    return total == 0 ? 1 : autoCaptured / total;
  }
}

enum AssetKind {
  cash('Cash', Icons.account_balance_rounded, Color(0xFF2DD4BF)),
  fixedDeposit('Fixed deposits', Icons.savings_rounded, Color(0xFF60A5FA)),
  stocks('Stocks', Icons.show_chart_rounded, Color(0xFFA78BFA)),
  funds('Mutual funds', Icons.pie_chart_rounded, Color(0xFF34D399)),
  gold('Gold', Icons.diamond_rounded, Color(0xFFFBBF24)),
  realEstate('Real estate', Icons.apartment_rounded, Color(0xFFF472B6)),
  liability('Liabilities', Icons.credit_score_rounded, Color(0xFFFB7185)),
  other('Other', Icons.category_rounded, Color(0xFF94A3B8));

  const AssetKind(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
}

class Asset {
  const Asset({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    this.note = '',
    this.editable = false,
  });
  final String id;
  final String name;
  final AssetKind kind;

  /// True for things the user typed in (a manual asset, loan or account
  /// balance): they can be edited and deleted. Priced holdings, cards and
  /// the like are managed elsewhere.
  final bool editable;

  /// Positive number; liabilities are subtracted by [AssetKind.liability].
  final double value;
  final String note;
  bool get isLiability => kind == AssetKind.liability;
}

class NetWorth {
  const NetWorth({
    required this.total,
    required this.series,
    required this.changePct,
    required this.changeAed,
    this.labels = const [],
    this.updatedAt,
    this.prices = const [],
    this.pricesLive = true,
  });
  final double total;

  /// False when the prices are cached or the bundled demo values (offline).
  final bool pricesLive;

  /// Month-end values, oldest first; the last point is now.
  final List<double> series;

  /// Short month label per [series] point.
  final List<String> labels;
  final double changePct;
  final double changeAed;

  /// When the valuations were last refreshed.
  final DateTime? updatedAt;

  /// Live inputs to the valuation (gold, FX, property index).
  final List<PriceInput> prices;
}

/// A market price that revalues assets automatically.
class PriceInput {
  const PriceInput({
    required this.name,
    required this.value,
    required this.source,
    required this.updatedAt,
    this.changePct = 0,
  });
  final String name;

  /// Display value, e.g. "AED 312.40 / g".
  final String value;
  final String source;
  final DateTime updatedAt;
  final double changePct;
}

class Member {
  const Member(
    this.id,
    this.name,
    this.color, {
    this.phone,
    this.onPulse = false,
    this.ibanTail,
  });
  final String id;
  final String name;
  final Color color;

  /// Last digits of the member's IBAN, for matching Aani transfers.
  final String? ibanTail;

  /// E.164 mobile number, when the member was added from contacts.
  final String? phone;

  /// The member has a Pulse account (matched by phone hash).
  final bool onPulse;
  String get initial => name.isEmpty ? '?' : name[0];
}

enum SettlementStatus {
  /// The payer says they paid (e.g. via Aani); the payee has not confirmed.
  awaitingConfirmation,

  /// The payee confirmed the money arrived. Counts towards balances.
  confirmed,
}

/// A recorded payment between two members of a group.
class SettlementRecord {
  const SettlementRecord({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.status = SettlementStatus.confirmed,
    this.method = 'aani',
  });
  final String id;
  final String from;
  final String to;
  final double amount;
  final DateTime date;
  final SettlementStatus status;
  final String method;

  SettlementRecord copyWith({SettlementStatus? status}) => SettlementRecord(
    id: id,
    from: from,
    to: to,
    amount: amount,
    date: date,
    status: status ?? this.status,
    method: method,
  );
}

/// Id of the transaction that records your share of an expense someone else
/// paid. Derived from the expense, so syncing the same expense twice never
/// adds a second one.
String splitShareTxId(String expenseId) => 'split_$expenseId';

class SplitExpense {
  const SplitExpense({
    required this.id,
    required this.title,
    required this.paidBy,
    required this.amount,
    required this.participants,
    required this.date,
    this.shares,
    this.transactionId,
  });
  final String id;
  final String title;
  final String paidBy;

  /// The payment in your own transactions this split was started from (you
  /// paid). Null when typed in by hand, or when someone else paid: then your
  /// share has a transaction of its own, see [linkedTransactionId].
  final String? transactionId;

  /// Id of your own transaction this split ties to: the payment you split, or
  /// (someone else paid) the one recording your share. Null when you paid and
  /// nothing was linked.
  String? get linkedTransactionId =>
      transactionId ?? (paidBy == 'me' ? null : splitShareTxId(id));
  final double amount;

  /// Member ids sharing equally (when [shares] is null).
  final List<String> participants;
  final DateTime date;

  /// Optional explicit share amounts by member id.
  final Map<String, double>? shares;
}

class SplitGroup {
  const SplitGroup({
    required this.id,
    required this.name,
    required this.emoji,
    required this.members,
    required this.expenses,
    this.settlements = const [],
  });
  final String id;
  final String name;
  final String emoji;
  final List<Member> members;
  final List<SplitExpense> expenses;
  final List<SettlementRecord> settlements;

  Member? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  SplitGroup copyWith({
    List<Member>? members,
    List<SplitExpense>? expenses,
    List<SettlementRecord>? settlements,
  }) => SplitGroup(
    id: id,
    name: name,
    emoji: emoji,
    members: members ?? this.members,
    expenses: expenses ?? this.expenses,
    settlements: settlements ?? this.settlements,
  );

  double get total => expenses.fold(0, (a, e) => a + e.amount);
}

enum BankAccountKind {
  current('Current'),
  savings('Savings'),
  wallet('Wallet'),
  cash('Cash');

  const BankAccountKind(this.label);
  final String label;
}

/// A bank account or wallet, shown as a card in the wallet stack.
class BankAccount {
  const BankAccount({
    required this.id,
    required this.bank,
    required this.name,
    required this.kind,
    required this.balance,
    required this.gradient,
    this.last4,
    this.monthIn = 0,
    this.monthOut = 0,
    this.matchLabels = const [],
    this.updatedAt,
  });
  final String id;
  final String bank;
  final String name;
  final BankAccountKind kind;
  final String? last4;
  final double balance;
  final List<Color> gradient;
  final double monthIn;
  final double monthOut;

  /// Transaction account labels that belong to this account.
  final List<String> matchLabels;
  final DateTime? updatedAt;

  double get monthNet => monthIn - monthOut;
  String get label => '$bank $name';
}

/// One row of a best-card answer for a purchase.
class BestCardPick {
  const BestCardPick({
    required this.name,
    required this.ratePct,
    this.cardId,
    this.estimate = 0,
    this.hitsCap = false,
    this.verified = false,
  });
  final String? cardId;
  final String name;
  final double ratePct;
  final double estimate;
  final bool hitsCap;
  final bool verified;
}
