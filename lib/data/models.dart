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

enum SpendCategory {
  groceries('Groceries', Icons.shopping_basket_rounded, Color(0xFF34D399)),
  dining('Dining', Icons.restaurant_rounded, Color(0xFFFB923C)),
  transport('Transport', Icons.directions_car_rounded, Color(0xFF60A5FA)),
  bills('Bills & Utilities', Icons.bolt_rounded, Color(0xFFFBBF24)),
  shopping('Shopping', Icons.shopping_bag_rounded, Color(0xFFF472B6)),
  travel('Travel', Icons.flight_takeoff_rounded, Color(0xFF22D3EE)),
  health('Health', Icons.favorite_rounded, Color(0xFFFB7185)),
  entertainment('Entertainment', Icons.movie_rounded, Color(0xFFA78BFA)),
  rent('Rent & Housing', Icons.home_rounded, Color(0xFF94A3B8)),
  income('Income', Icons.south_west_rounded, Color(0xFF2DD4BF)),
  other('Other', Icons.category_rounded, Color(0xFF94A3B8));

  const SpendCategory(this.label, this.icon, this.color);
  final String label;
  final IconData icon;
  final Color color;
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

  double get signed => isIncome ? amount : -amount;

  Transaction copyWith({SpendCategory? category}) => Transaction(
    id: id,
    merchant: merchant,
    amount: amount,
    category: category ?? this.category,
    date: date,
    source: source,
    cardId: cardId,
    accountLabel: accountLabel,
    isIncome: isIncome,
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
  const Member(this.id, this.name, this.color);
  final String id;
  final String name;
  final Color color;
  String get initial => name.isEmpty ? '?' : name[0];
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
  });
  final String id;
  final String name;
  final String emoji;
  final List<Member> members;
  final List<SplitExpense> expenses;

  double get total => expenses.fold(0, (a, e) => a + e.amount);
}
