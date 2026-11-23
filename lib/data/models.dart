import 'package:material_ui/material_ui.dart';

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
    this.label,
    this.icon, {
    this.kind = CategoryKind.expense,
    this.custom = false,
  });

  /// A user-created category.
  const SpendCategory.custom(
    this.id,
    this.label, {
    this.icon = Icons.label_outline_rounded,
    this.kind = CategoryKind.expense,
  }) : custom = true;

  final String id;
  final String label;
  final IconData icon;
  final CategoryKind kind;
  final bool custom;

  /// Stable key (analytics, routes). Same as [id].
  String get name => id;
  bool get isIncome => kind == CategoryKind.income;
  bool get isTransfer => kind == CategoryKind.transfer;

  static const salary = SpendCategory(
    'salary',
    'Salary',
    Icons.payments_outlined,
    kind: CategoryKind.income,
  );
  static const groceries = SpendCategory(
    'groceries',
    'Groceries',
    Icons.shopping_basket_outlined,
  );
  static const dining = SpendCategory(
    'dining',
    'Dining & Delivery',
    Icons.restaurant_outlined,
  );
  static const transport = SpendCategory(
    'transport',
    'Transport & Fuel',
    Icons.local_gas_station_outlined,
  );
  static const carLoan = SpendCategory(
    'car_loan',
    'Car Loan',
    Icons.directions_car_outlined,
  );
  static const homeLoan = SpendCategory(
    'home_loan',
    'Home Loan',
    Icons.account_balance_outlined,
  );
  static const rent = SpendCategory(
    'rent',
    'Rent & Housing',
    Icons.home_outlined,
  );
  static const utilities = SpendCategory(
    'utilities',
    'Utilities',
    Icons.bolt_outlined,
  );
  static const telecom = SpendCategory(
    'telecom',
    'Telecom',
    Icons.wifi_rounded,
  );
  static const fixedExpenses = SpendCategory(
    'fixed_expenses',
    'Fixed Expenses',
    Icons.event_repeat_outlined,
  );
  static const education = SpendCategory(
    'education',
    'Education Fees',
    Icons.school_outlined,
  );
  static const health = SpendCategory(
    'health',
    'Health',
    Icons.favorite_border_rounded,
  );
  static const shopping = SpendCategory(
    'shopping',
    'Shopping',
    Icons.shopping_bag_outlined,
  );
  static const travel = SpendCategory(
    'travel',
    'Travel',
    Icons.flight_outlined,
  );
  static const entertainment = SpendCategory(
    'entertainment',
    'Entertainment',
    Icons.movie_outlined,
  );
  static const family = SpendCategory(
    'family',
    'Family & Remittances',
    Icons.people_outline_rounded,
  );
  static const savings = SpendCategory(
    'savings',
    'Savings & Investments',
    Icons.savings_outlined,
  );
  static const cardPayments = SpendCategory(
    'cc_payment',
    'Credit Card Payments',
    Icons.credit_card_outlined,
    kind: CategoryKind.transfer,
  );
  static const fees = SpendCategory(
    'fees',
    'Fees',
    Icons.receipt_outlined,
  );
  static const other = SpendCategory(
    'other',
    'Other',
    Icons.more_horiz_rounded,
  );

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
  });

  final String id;
  final String merchant;

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
  String get description => rawDescription ?? merchant;

  double get signed => isIncome ? amount : -amount;

  Transaction copyWith({
    SpendCategory? category,
    String? merchant,
    bool? excluded,
  }) =>
      Transaction(
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
  );
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
  });

  final String id;
  final String issuer;
  final String name;
  final String last4;
  final CardNetwork network;
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

  double get utilisation => limit == 0 ? 0 : balance / limit;
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
  });
  final String id;
  final String name;
  final AssetKind kind;

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
  });
  final double total;
  final List<double> series;
  final double changePct;
  final double changeAed;
}

class Member {
  const Member(
    this.id,
    this.name,
    this.color, {
    this.phone,
    this.onPulse = false,
  });
  final String id;
  final String name;
  final Color color;

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

class SplitExpense {
  const SplitExpense({
    required this.id,
    required this.title,
    required this.paidBy,
    required this.amount,
    required this.participants,
    required this.date,
    this.shares,
  });
  final String id;
  final String title;
  final String paidBy;
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
