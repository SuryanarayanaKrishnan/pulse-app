import 'dart:math' as math;
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import 'api/api_exception.dart';
import 'card_util.dart';
import 'goal_service.dart';
import 'local/goal_store.dart';
import 'local/splits_store.dart' show NewGroupMember;
import 'insights.dart';
import 'models.dart';
import 'phone.dart';
import 'recategoriser.dart';
import '../core/engine/dates.dart' show CalDate, toDubaiDate;
import '../core/engine/nw_history.dart';
import '../core/engine/goals.dart';
import '../core/engine/merchants.dart' show normalizeMerchant;
import '../core/engine/recategorise.dart';
import 'repository.dart';
import 'rules.dart';
import 'statements.dart';
import 'wealth_service.dart';

typedef S = SpendCategory;

/// In-memory repository with realistic UAE sample data.
class MockPulseRepository with LocalOnlyFeatures implements PulseRepository, Recategoriser, NetWorthHistorySource {
  MockPulseRepository({
    this.latency = const Duration(milliseconds: 450),
    DateTime? now,
    this.wealth,
    this.goals,
    bool seedGroups = true,
  }) : _now = now ?? DateTime.now() {
    _tx = [for (final t in _seedTransactions()) applyRules(t, _rules)];
    _groups = seedGroups ? _seedGroups() : [];
    _statements = _seedStatements();
  }

  final Duration latency;

  /// Demo goals; their monthly set-aside feeds safe to spend.
  final GoalStore? goals;

  /// Demo jewellery and funds, so net worth includes them.
  final WealthService? wealth;
  final DateTime _now;
  late List<Transaction> _tx;
  late List<SplitGroup> _groups;
  late List<Statement> _statements;
  var _manualSeq = 0;
  var _seq = 0;
  String _id(String prefix) => '$prefix${_seq++}';

  Future<T> _d<T>(T v) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return v;
  }

  // ---- Cards -------------------------------------------------------------

  static final _due = DateTime(2026, 1, 1);

  late List<CreditCard> _owned = _seedCards();

  List<CreditCard> _seedCards() => [
    CreditCard(
      id: 'enbd-sky',
      issuer: 'Emirates NBD',
      name: 'Skywards Infinite',
      last4: '4821',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF14213D), Color(0xFF26395F)],
      limit: 60000,
      balance: 8420.5,
      dueDate: _dayInMonth(_now, 4),
      minDue: 421,
      rewardsLabel: 'Skywards Miles',
      rewardPoints: 48210,
      rewardValueAed: 964,
      categoryRates: {
        SpendCategory.travel: 3.5,
        SpendCategory.dining: 2,
        SpendCategory.shopping: 1.5,
        SpendCategory.groceries: 1,
      },
      annualFee: 1575,
      highlight: '3.5 Skywards Miles per AED 1 on flights',
      statementDate: _dayInMonth(_now, 4).subtract(const Duration(days: 25)),
      statementBalance: 7980,
      rulesVerifiedOn: DateTime(2026, 11, 2),
    ),
    CreditCard(
      id: 'mashreq-cb',
      issuer: 'Mashreq',
      name: 'Cashback Card',
      last4: '0937',
      network: CardNetwork.mastercard,
      gradient: const [Color(0xFF5A2A18), Color(0xFF8C4A2B)],
      limit: 25000,
      balance: 3190,
      dueDate: _dayInMonth(_now, 12),
      minDue: 160,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 312,
      categoryRates: {
        SpendCategory.groceries: 5,
        SpendCategory.transport: 5,
        SpendCategory.dining: 3,
        SpendCategory.utilities: 0.5,
      },
      baseRate: 0.25,
      caps: {
        SpendCategory.groceries: RewardCap(limit: 150, used: 61),
        SpendCategory.transport: RewardCap(limit: 75, used: 14),
        SpendCategory.dining: RewardCap(limit: 50, used: 9),
      },
      highlight: '5% cashback on groceries and transport',
      statementDate: _dayInMonth(_now, 12).subtract(const Duration(days: 25)),
      statementBalance: 3190,
      rulesVerifiedOn: DateTime(2026, 10, 18),
    ),
    CreditCard(
      id: 'fab-cb',
      issuer: 'FAB',
      name: 'Cashback Platinum',
      last4: '6604',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF10302B), Color(0xFF1F5047)],
      limit: 40000,
      balance: 11760,
      dueDate: _dayInMonth(_now, 21),
      minDue: 588,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 540,
      categoryRates: {
        SpendCategory.dining: 5,
        SpendCategory.entertainment: 5,
        SpendCategory.shopping: 2,
        SpendCategory.health: 2,
      },
      annualFee: 0,
      baseRate: 0,
      caps: {
        SpendCategory.dining: RewardCap(limit: 100, used: 95),
        SpendCategory.entertainment: RewardCap(limit: 100, used: 22),
      },
      highlight: '5% on dining and entertainment',
      statementDate: _dayInMonth(_now, 21).subtract(const Duration(days: 25)),
      statementBalance: 11760,
      rulesVerifiedOn: DateTime(2026, 11, 14),
    ),
  ];

  static DateTime _dayInMonth(DateTime now, int day) {
    final d = DateTime(now.year, now.month, day);
    return d.isBefore(DateTime(now.year, now.month, now.day))
        ? DateTime(now.year, now.month + 1, day)
        : d;
  }

  List<CreditCard> get _catalog => [
    CreditCard(
      id: 'adcb-tp',
      issuer: 'ADCB',
      name: 'TouchPoints Platinum',
      last4: '0000',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF111827), Color(0xFF9F1239), Color(0xFFE11D48)],
      limit: 0,
      balance: 0,
      dueDate: _due,
      minDue: 0,
      rewardsLabel: 'TouchPoints',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: {
        SpendCategory.groceries: 3,
        SpendCategory.dining: 3,
        SpendCategory.travel: 2,
      },
      annualFee: 0,
      owned: false,
      highlight: 'Up to 3 TouchPoints per AED 1 at supermarkets',
    ),
    CreditCard(
      id: 'enbd-go4it',
      issuer: 'Emirates NBD',
      name: 'Go4it Platinum',
      last4: '0000',
      network: CardNetwork.mastercard,
      gradient: const [Color(0xFF1E1B4B), Color(0xFF4338CA), Color(0xFF22D3EE)],
      limit: 0,
      balance: 0,
      dueDate: _due,
      minDue: 0,
      rewardsLabel: 'Go4it Points',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: {
        SpendCategory.entertainment: 4,
        SpendCategory.transport: 3,
        SpendCategory.dining: 2,
      },
      owned: false,
      highlight: 'Points on every swipe, redeem on fuel and movies',
    ),
    CreditCard(
      id: 'liv-plat',
      issuer: 'Liv by ENBD',
      name: 'Liv Platinum',
      last4: '0000',
      network: CardNetwork.mastercard,
      gradient: const [Color(0xFF3F0D6B), Color(0xFFC026D3), Color(0xFFF97316)],
      limit: 0,
      balance: 0,
      dueDate: _due,
      minDue: 0,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: {
        SpendCategory.shopping: 4,
        SpendCategory.dining: 3,
        SpendCategory.groceries: 1,
      },
      owned: false,
      highlight: 'Digital-first, no annual fee, 4% online shopping',
    ),
    CreditCard(
      id: 'mashreq-solaris',
      issuer: 'Mashreq',
      name: 'Solitaire',
      last4: '0000',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF020617), Color(0xFF334155), Color(0xFFCBD5E1)],
      limit: 0,
      balance: 0,
      dueDate: _due,
      minDue: 0,
      rewardsLabel: 'Salaam points',
      rewardPoints: 0,
      rewardValueAed: 0,
      categoryRates: {
        SpendCategory.travel: 4,
        SpendCategory.health: 3,
        SpendCategory.dining: 3,
      },
      annualFee: 1050,
      owned: false,
      highlight: 'Airport lounge access and concierge',
    ),
  ];

  @override
  Future<List<CreditCard>> myCards() => _d(List.of(_owned));

  @override
  Future<CreditCard> addCard({
    required String catalogId,
    required String last4,
    double? limit,
    int? statementDay,
    int? dueDay,
    double owed = 0,
  }) async {
    final cat = _catalog.where((c) => c.id == catalogId).firstOrNull;
    if (cat == null) throw const ApiException(message: 'That card is not in the catalog.', code: 'unknown_card');
    final card = cat.copyWith(
      last4: last4.isEmpty ? '----' : last4,
      limit: limit ?? 0,
      balance: owed,
      owned: true,
    );
    _owned = [..._owned.where((c) => c.id != catalogId), card];
    return _d(card);
  }
  @override
  Future<void> updateCardDetails(
    String accountId, {
    String? last4,
    double? limit,
    int? statementDay,
    int? dueDay,
  }) async {
    _owned = [
      for (final c in _owned)
        if (c.id == accountId)
          c.copyWith(
            last4: last4 == null || last4.isEmpty ? '----' : last4,
            limit: limit ?? 0,
            statementDay: statementDay,
            dueDay: dueDay,
          )
        else
          c,
    ];
  }

  @override
  Future<List<CreditCard>> cardCatalog() => _d(_catalog);
  @override
  Future<CreditCard> addCustomCatalogCard({required String issuer, required String name}) =>
      throw UnimplementedError('The demo catalog is fixed');

  @override
  Future<List<BankAccount>> bankAccounts() {
    final now = DateTime.now();
    BankAccount acct(
      String id,
      String bank,
      String name,
      BankAccountKind kind,
      double balance,
      List<Color> gradient,
      List<String> labels, {
      String? last4,
    }) {
      var inflow = 0.0, outflow = 0.0;
      for (final t in _tx) {
        if (!labels.contains(t.accountLabel)) continue;
        if (t.date.year != now.year || t.date.month != now.month) continue;
        if (t.isIncome) {
          inflow += t.amount;
        } else {
          outflow += t.amount;
        }
      }
      return BankAccount(
        id: id,
        bank: bank,
        name: name,
        kind: kind,
        balance: balance,
        gradient: gradient,
        last4: last4,
        monthIn: inflow,
        monthOut: outflow,
        matchLabels: labels,
        updatedAt: now.subtract(const Duration(minutes: 8)),
      );
    }

    return _d([
      acct(
        'enbd-current',
        'Emirates NBD',
        'Current',
        BankAccountKind.current,
        41200,
        const [Color(0xFF1B2433), Color(0xFF2E3B50)],
        const ['Emirates NBD Current'],
        last4: '2210',
      ),
      acct(
        'liv-savings',
        'Liv',
        'Savings',
        BankAccountKind.savings,
        24000,
        const [Color(0xFF173530), Color(0xFF285A50)],
        const ['Liv', 'Liv Savings'],
        last4: '7731',
      ),
      acct(
        'cash',
        'Cash',
        'Wallet',
        BankAccountKind.cash,
        4500,
        const [Color(0xFF38332D), Color(0xFF575047)],
        const ['Cash'],
      ),
    ]);
  }

  @override
  Future<List<BestCardPick>> bestCard(SpendCategory category, double amount) =>
      _d([
        for (final c in rankCardsFor(_owned, category))
          BestCardPick(
            cardId: c.id,
            name: '${c.issuer} ${c.name}',
            ratePct: effectiveRate(c, category),
            estimate: rewardFor(c, category, amount),
            hitsCap:
                c.caps[category] != null &&
                rewardFor(c, category, amount) <
                    amount * rateFor(c, category) / 100 - 0.005,
            verified: c.rulesVerifiedOn != null,
          ),
      ]);

  // ---- Transactions ------------------------------------------------------

  List<Transaction> _seedTransactions() {
    var n = 0;
    Transaction t(
      String m,
      double a,
      SpendCategory c,
      int daysAgo,
      TxSource s,
      String card,
      String acct, {
      bool income = false,
    }) {
      final d = DateTime(
        _now.year,
        _now.month,
        _now.day,
        9 + (n % 10),
        (n * 7) % 60,
      ).subtract(Duration(days: daysAgo));
      return Transaction(
        id: 'tx${n++}',
        merchant: m,
        amount: a,
        category: c,
        date: d,
        source: s,
        cardId: card,
        accountLabel: acct,
        isIncome: income,
        // Recent captured payments wait for a look; older and typed ones do not.
        reviewed: !s.automatic || daysAgo > 7,
        confidence: n % 4 == 1 ? 0.4 : 0.8,
      );
    }

    // The two months before, for the bills and subscriptions above (same day
    // of the month), so Recurring has history to find. Netflix went up this
    // month. Nothing older: three months back stays empty.
    var hist = 0;
    Transaction past(String m, double a, SpendCategory c, int daysAgo, int monthsBack, String card, String acct) {
      final base = DateTime(_now.year, _now.month, _now.day).subtract(Duration(days: daysAgo));
      final d = DateTime(base.year, base.month - monthsBack, base.day.clamp(1, 28), 10, 5);
      return Transaction(
        id: 'hist${hist++}',
        merchant: m,
        amount: a,
        category: c,
        date: d,
        source: TxSource.statement,
        cardId: card,
        accountLabel: acct,
      );
    }

    final history = [
      for (var k = 1; k <= 2; k++) ...[
        past('Netflix', 45, S.entertainment, 21, k, 'fab-cb', 'FAB Cashback'),
        past('Fitness First', 349, S.health, 20, k, 'fab-cb', 'FAB Cashback'),
        past('DEWA', const [540.0, 480.0][k - 1], S.utilities, 2, k, 'enbd-current', 'Emirates NBD Current'),
      ],
    ];

    const src = TxSource.sms;
    return [
      ...history,
      t(
        'Carrefour',
        312.40,
        S.groceries,
        0,
        TxSource.applePayShortcut,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t('Talabat', 86.00, S.dining, 0, src, 'fab-cb', 'FAB Cashback'),
      t(
        'Salik',
        24.00,
        S.transport,
        1,
        TxSource.walletNotification,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t(
        'Noon',
        459.00,
        S.shopping,
        1,
        TxSource.statement,
        'enbd-sky',
        'ENBD Skywards',
      ),
      t(
        'DEWA',
        612.30,
        S.utilities,
        2,
        TxSource.statement,
        'enbd-current',
        'Emirates NBD Current',
      ),
      t(
        'Starbucks',
        28.50,
        S.dining,
        2,
        TxSource.applePayShortcut,
        'fab-cb',
        'FAB Cashback',
      ),
      t('Careem', 41.00, S.transport, 3, src, 'mashreq-cb', 'Mashreq Cashback'),
      t(
        'Spinneys',
        187.90,
        S.groceries,
        3,
        src,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t(
        'Tabby · Namshi',
        215.00,
        S.shopping,
        4,
        TxSource.walletNotification,
        'tabby',
        'Tabby',
      ),
      t(
        'Vox Cinemas',
        96.00,
        S.entertainment,
        5,
        TxSource.applePayShortcut,
        'fab-cb',
        'FAB Cashback',
      ),
      t(
        'Emirates Airline',
        2840.00,
        S.travel,
        6,
        TxSource.statement,
        'enbd-sky',
        'ENBD Skywards',
      ),
      t('Talabat', 74.50, S.dining, 6, src, 'fab-cb', 'FAB Cashback'),
      t(
        'Carrefour',
        241.15,
        S.groceries,
        7,
        TxSource.applePayShortcut,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t(
        'du',
        399.00,
        S.telecom,
        8,
        TxSource.statement,
        'enbd-current',
        'Emirates NBD Current',
      ),
      t(
        'Salary · Acme FZ-LLC',
        24500.00,
        S.salary,
        9,
        TxSource.statement,
        'enbd-current',
        'Emirates NBD Current',
        income: true,
      ),
      t(
        'Rent · Dubai Marina',
        6250.00,
        S.rent,
        9,
        TxSource.statement,
        'liv',
        'Liv',
      ),
      t('ENOC', 180.00, S.transport, 10, src, 'mashreq-cb', 'Mashreq Cashback'),
      t(
        'Zuma',
        640.00,
        S.dining,
        11,
        TxSource.walletNotification,
        'fab-cb',
        'FAB Cashback',
      ),
      t('Aster Pharmacy', 132.00, S.health, 12, src, 'fab-cb', 'FAB Cashback'),
      t(
        'Noon Minutes',
        63.40,
        S.groceries,
        13,
        src,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t(
        'Salik',
        24.00,
        S.transport,
        14,
        TxSource.walletNotification,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t('Talabat', 98.00, S.dining, 15, src, 'fab-cb', 'FAB Cashback'),
      t(
        'Amazon.ae',
        275.00,
        S.shopping,
        16,
        TxSource.statement,
        'enbd-sky',
        'ENBD Skywards',
      ),
      t(
        'Carrefour',
        355.75,
        S.groceries,
        18,
        TxSource.applePayShortcut,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      t(
        'Fitness First',
        349.00,
        S.health,
        20,
        TxSource.statement,
        'fab-cb',
        'FAB Cashback',
      ),
      t(
        'Netflix',
        56.00,
        S.entertainment,
        21,
        TxSource.statement,
        'fab-cb',
        'FAB Cashback',
      ),
      t(
        'Lunch with Sara',
        120.00,
        S.dining,
        22,
        TxSource.manual,
        'cash',
        'Cash',
      ),
      t(
        'Careem',
        38.00,
        S.transport,
        24,
        src,
        'mashreq-cb',
        'Mashreq Cashback',
      ),
      Transaction(
        id: 'tx-savings',
        merchant: 'Liv Savings',
        rawDescription: 'Transfer to Liv Savings',
        amount: 3000,
        category: S.savings,
        date: DateTime(
          _now.year,
          _now.month,
          _now.day,
          8,
        ).subtract(const Duration(days: 9)),
        source: TxSource.statement,
        cardId: 'enbd-current',
        accountLabel: 'Emirates NBD Current',
      ),
    ]..sort((a, b) => b.date.compareTo(a.date));
  }

  @override
  Future<List<Transaction>> transactions() => _d(List.of(_tx));

  /// Mock cursor is simply the list offset.
  @override
  Future<TxPage> transactionsPage({String? cursor, int limit = 50}) {
    final start = int.tryParse(cursor ?? '') ?? 0;
    final end = (start + limit).clamp(0, _tx.length);
    return _d(
      TxPage(
        _tx.sublist(start.clamp(0, _tx.length), end),
        nextCursor: end < _tx.length ? '$end' : null,
      ),
    );
  }

  @override
  Future<Transaction> recategorise(
    String txId,
    SpendCategory category, {
    bool remember = false,
  }) async {
    final i = _tx.indexWhere((e) => e.id == txId);
    _tx[i] = _tx[i].copyWith(category: category, reviewed: true);
    if (remember) {
      await saveRule(suggestMerchantRule(_tx[i], category));
    }
    return _d(_tx[i]);
  }

  @override
  Future<void> setReviewed(Iterable<String> txIds, bool reviewed) async {
    final ids = txIds.toSet();
    _tx = [for (final t in _tx) ids.contains(t.id) ? t.copyWith(reviewed: reviewed) : t];
  }

  @override
  Future<int> importTransactions(List<ImportedTransaction> txs) async => 0;

  @override
  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
    DateTime? date,
    String? note,
  }) async {
    final tx = applyRules(
      Transaction(
        id: 'manual${_manualSeq++}',
        merchant: merchant,
        amount: amount,
        category: category,
        date: date ?? DateTime.now(),
        source: TxSource.manual,
        note: note?.trim().isEmpty ?? true ? null : note!.trim(),
        cardId: 'cash',
        accountLabel: 'Cash',
        isIncome: category.isIncome,
      ),
      _rules,
    );
    _tx = [tx, ..._tx];
    return _d(tx);
  }

  @override
  Future<void> setTransactionNote(String txId, String? note) async {
    final n = note?.trim();
    _tx = [
      for (final t in _tx)
        if (t.id == txId) t.copyWith(note: n, clearNote: n == null || n.isEmpty) else t,
    ];
  }

  @override
  Future<void> deleteTransaction(String txId) async {
    _tx = [for (final t in _tx) if (t.id != txId) t];
  }

  // ---- Budget ------------------------------------------------------------

  final _planned = <SpendCategory, double>{
    SpendCategory.groceries: 1600.0,
    SpendCategory.dining: 1200.0,
    SpendCategory.transport: 600.0,
    SpendCategory.utilities: 700.0,
    SpendCategory.telecom: 400.0,
    SpendCategory.shopping: 1000.0,
    SpendCategory.travel: 2500.0,
    SpendCategory.health: 500.0,
    SpendCategory.entertainment: 400.0,
    SpendCategory.rent: 6250.0,
  };
  final _custom = <SpendCategory>[];

  @override
  Future<List<SpendCategory>> categories() =>
      _d([...SpendCategory.defaults, ..._custom]);

  @override
  Future<SpendCategory> createCategory({
    required String name,
    CategoryKind kind = CategoryKind.expense,
    String? iconKey,
  }) {
    final c = SpendCategory.custom(_id('custom_'), name.trim(), kind: kind, iconKey: iconKey);
    _custom.add(c);
    return _d(c);
  }

  @override
  Future<SpendCategory> setCategoryIcon(SpendCategory category, String iconKey) {
    final i = _custom.indexWhere((c) => c.id == category.id);
    if (i < 0) return _d(category);
    final c = SpendCategory.custom(category.id, category.label, kind: category.kind, iconKey: iconKey);
    _custom[i] = c;
    return _d(c);
  }

  @override
  Future<void> setBudget(SpendCategory category, double monthly) {
    if (monthly <= 0) {
      _planned.remove(category);
    } else {
      _planned[category] = monthly;
    }
    return _d(null);
  }

  // ---- Automations ---------------------------------------------------------

  final _rules = <AutomationRule>[
    const AutomationRule(
      id: 'r1',
      field: RuleField.merchant,
      op: RuleOperator.contains,
      value: 'Talabat',
      action: RuleAction.setCategory,
      category: SpendCategory.dining,
    ),
    const AutomationRule(
      id: 'r2',
      field: RuleField.merchant,
      op: RuleOperator.startsWith,
      value: 'Tabby ·',
      action: RuleAction.rename,
      renameTo: 'Namshi (Tabby)',
    ),
    const AutomationRule(
      id: 'r3',
      field: RuleField.description,
      op: RuleOperator.contains,
      value: 'Transfer to Liv Savings',
      action: RuleAction.exclude,
    ),
  ];

  // ---- scoped re-categorise (demo) -------------------------------------------------

  String? _key(Transaction t) =>
      recategoriseKey(raw: t.rawDescription ?? t.merchant, normalized: normalizeMerchant(t.merchant));

  SpendCategory _cat(String? id) =>
      [...S.defaults, ..._tx.map((t) => t.category)].firstWhere((c) => c.id == id, orElse: () => S.defaults.first);

  @override
  Future<RecatPreview?> previewRecategorise(String txId, SpendCategory to) async {
    final t = _tx.firstWhere((e) => e.id == txId);
    final key = _key(t);
    if (key == null) return null;
    final past = _tx.where((e) => e.id != txId && _key(e) == key && e.category != to);
    return RecatPreview(merchant: t.merchant, pastCount: past.length);
  }

  @override
  Future<RecatUndo> recategoriseScoped(String txId, SpendCategory to, RecategoriseScope scope) async {
    final i = _tx.indexWhere((e) => e.id == txId);
    final t = _tx[i];
    final key = _key(t);
    _tx[i] = t.copyWith(category: to, reviewed: true);
    if (scope == RecategoriseScope.once || key == null) {
      return RecatUndo(txId: txId, txCategoryId: t.category.id);
    }
    // Only future captures: add the rule without applying it to history.
    final rule = suggestMerchantRule(t, to).copyWith(id: _id('rule'));
    _rules.add(rule);
    final before = <String, (String?, String?)>{};
    if (scope == RecategoriseScope.all) {
      for (var j = 0; j < _tx.length; j++) {
        final e = _tx[j];
        if (e.id == txId || _key(e) != key || e.category == to) continue;
        before[e.id] = (e.category.id, null);
        _tx[j] = e.copyWith(category: to);
      }
    }
    return RecatUndo(txId: txId, txCategoryId: t.category.id, createdRuleId: rule.id, pastBefore: before);
  }

  @override
  Future<void> undoRecategorise(RecatUndo undo) async {
    for (final e in {undo.txId: (undo.txCategoryId, null), ...undo.pastBefore}.entries) {
      final j = _tx.indexWhere((t) => t.id == e.key);
      if (j >= 0) _tx[j] = _tx[j].copyWith(category: _cat(e.value.$1));
    }
    if (undo.createdRuleId != null) await deleteRule(undo.createdRuleId!);
  }

  @override
  Future<List<AutomationRule>> rules() => _d(List.of(_rules));

  @override
  Future<AutomationRule> saveRule(AutomationRule rule) {
    final saved = rule.copyWith(id: _id('rule'));
    _rules.add(saved);
    _tx = [
      for (final t in _tx) applyRules(t, [saved]),
    ];
    return _d(saved);
  }

  @override
  Future<void> deleteRule(String id) {
    _rules.removeWhere((r) => r.id == id);
    return _d(null);
  }

  @override
  Future<BudgetOverview> budgetOverview() async {
    final spend = _tx
        .where((t) => !t.isIncome && !t.excluded && !t.category.isTransfer)
        .toList();
    final byCat = <SpendCategory, double>{};
    final byMerchant = <String, List<Transaction>>{};
    final byCard = <String, double>{};
    final byAcct = <String, double>{};
    for (final t in spend) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
      byMerchant.putIfAbsent(t.merchant, () => []).add(t);
      byAcct[t.accountLabel] = (byAcct[t.accountLabel] ?? 0) + t.amount;
      final cardName = {
        for (final c in _owned) c.id: '${c.issuer} ${c.last4}',
      }[t.cardId];
      if (cardName != null)
        byCard[cardName] = (byCard[cardName] ?? 0) + t.amount;
    }
    final lines = [
      for (final c in {..._planned.keys, ...byCat.keys})
        BudgetLine(
          category: c,
          planned: _planned[c] ?? 0,
          spent: byCat[c] ?? 0,
        ),
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    final merchants =
        byMerchant.entries
            .map(
              (e) => MerchantTotal(
                e.key,
                e.value.first.category,
                e.value.fold(0.0, (a, t) => a + t.amount),
                e.value.length,
              ),
            )
            .toList()
          ..sort((a, b) => b.total.compareTo(a.total));
    final dim = DateUtils.getDaysInMonth(_now.year, _now.month);
    final spent = spend.fold(0.0, (a, t) => a + t.amount);
    const hist = [11200.0, 12850.0, 13900.0, 11980.0, 12400.0];
    final labels = List.generate(
      5,
      (i) => _short(DateTime(_now.year, _now.month - 5 + i).month),
    );
    return _d(
      BudgetOverview(
        planned: _planned.values.fold(0.0, (a, b) => a + b),
        spent: spent,
        daysLeft: dim - _now.day + 1,
        daysInMonth: dim,
        lines: lines,
        trend: [
          for (var i = 0; i < 5; i++) MonthlyTotal(labels[i], hist[i], 14000),
          MonthlyTotal(_short(_now.month), spent, 14000),
        ],
        topMerchants: merchants.take(5).toList(),
        byCard: byCard,
        byAccount: byAcct,
        autoCaptured: spend.where((t) => t.source.automatic).length,
        manual: spend.where((t) => !t.source.automatic).length,
      ),
    );
  }

  static String _short(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][(m - 1) % 12];

  // ---- Wealth ------------------------------------------------------------

  static const _assets = [
    Asset(
      id: 'a1',
      name: 'Emirates NBD Current',
      kind: AssetKind.cash,
      value: 48200,
      note: 'AED',
    ),
    Asset(id: 'a2', name: 'Liv Savings', kind: AssetKind.cash, value: 21500),
    Asset(
      id: 'a3',
      name: 'ADCB Fixed Deposit',
      kind: AssetKind.fixedDeposit,
      value: 150000,
      note: '4.6% · matures Mar 2027',
    ),
    Asset(
      id: 'a4',
      name: 'Dubai Marina 1BR',
      kind: AssetKind.realEstate,
      value: 1450000,
      note: 'Est. value',
    ),
    Asset(
      id: 'a5',
      name: 'Gold bars · 120 g 22K',
      kind: AssetKind.gold,
      value: 51700,
      note: 'Live spot',
    ),
    Asset(
      id: 'a6',
      name: 'Nasdaq portfolio',
      kind: AssetKind.stocks,
      value: 96300,
      note: 'Brokerage',
    ),
    Asset(id: 'a7', name: 'DFM holdings', kind: AssetKind.stocks, value: 28400),
    Asset(
      id: 'l1',
      name: 'Mortgage · ADCB',
      kind: AssetKind.liability,
      value: 920000,
    ),
    Asset(
      id: 'l2',
      name: 'Credit card balances',
      kind: AssetKind.liability,
      value: 23370,
    ),
  ];

  @override
  Future<List<Asset>> assets() async =>
      _d([..._assets, ...?await wealth?.assets()]);

  /// Demo history: a year of days that follow the month-end series, with
  /// debt easing as the line climbs.
  @override
  Future<List<NwPoint>> netWorthHistory() async {
    final all = [..._assets, ...?await wealth?.assets()];
    var a = 0.0, l = 0.0;
    for (final e in all) {
      if (e.isLiability) {
        l += e.value;
      } else {
        a += e.value;
      }
    }
    final today = toDubaiDate(_now);
    final out = <NwPoint>[];
    for (var i = 364; i >= 0; i--) {
      // 0.90 a year ago up to 1.0 today, with a gentle wobble.
      final f = 0.90 + 0.10 * (364 - i) / 364 + 0.012 * math.sin((364 - i) / 9.0);
      final debt = l * (1 + 0.25 * (1 - f) * 10);
      final net = (a - l) * f;
      out.add(NwPoint(today.addDays(-i), ((net + debt) * 100).round(), (debt * 100).round()));
    }
    out[out.length - 1] = NwPoint(today, (a * 100).round(), (l * 100).round());
    return out;
  }

  @override
  Future<NetWorth> netWorth() async {
    final all = [..._assets, ...?await wealth?.assets()];
    final total = all.fold(
      0.0,
      (a, e) => a + (e.isLiability ? -e.value : e.value),
    );
    const series = [
      0.93,
      0.94,
      0.935,
      0.95,
      0.96,
      0.955,
      0.97,
      0.985,
      0.98,
      0.99,
      0.995,
      1.0,
    ];
    final s = series.map((f) => total * f).toList();
    return _d(
      NetWorth(
        total: total,
        series: s,
        labels: [
          for (var i = 11; i >= 0; i--)
            _short(DateTime(_now.year, _now.month - i).month),
        ],
        changePct: (s.last / s[s.length - 2] - 1) * 100 + 0.8,
        changeAed: s.last - s.first,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
        prices: [
          if (wealth != null)
            ...priceInputs(await wealth!.book())
          else ...[
            PriceInput(
              name: 'Gold 22K',
              value: 'AED 348.25 / g',
              source: 'Dubai gold rate',
              updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
              changePct: 0.6,
            ),
            PriceInput(
              name: 'USD / AED',
              value: '3.6725',
              source: 'Central Bank peg',
              updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
            ),
          ],
          PriceInput(
            name: 'Dubai Marina 1BR',
            value: 'AED 1,450,000',
            source: 'Area sales index',
            updatedAt: DateTime.now().subtract(const Duration(days: 6)),
            changePct: 1.9,
          ),
        ],
      ),
    );
  }

  // ---- Splits ------------------------------------------------------------

  List<SplitGroup> _seedGroups() {
    const me = Member('me', 'You', Color(0xFF5BC2A8), onPulse: true);
    const a = Member(
      'ahmed',
      'Ahmed',
      Color(0xFF5BC2A8),
      phone: '+971501234567',
      onPulse: true,
    );
    const s = Member(
      'sara',
      'Sara',
      Color(0xFF5BC2A8),
      phone: '+971552345678',
      onPulse: true,
    );
    const o = Member('omar', 'Omar', Color(0xFF5BC2A8), phone: '+971563456789');
    final now = _now;
    return [
      SplitGroup(
        id: 'g1',
        name: 'Marina flat',
        emoji: '🏙️',
        members: const [me, a, s],
        expenses: [
          SplitExpense(
            id: 'e1',
            title: 'DEWA bill',
            paidBy: 'me',
            amount: 612.30,
            participants: const ['me', 'ahmed', 'sara'],
            date: now.subtract(const Duration(days: 2)),
          ),
          SplitExpense(
            id: 'e2',
            title: 'Wifi · Du',
            paidBy: 'ahmed',
            amount: 399,
            participants: const ['me', 'ahmed', 'sara'],
            date: now.subtract(const Duration(days: 8)),
          ),
          SplitExpense(
            id: 'e3',
            title: 'Carrefour run',
            paidBy: 'sara',
            amount: 241.15,
            participants: const ['me', 'ahmed', 'sara'],
            date: now.subtract(const Duration(days: 9)),
          ),
        ],
        settlements: [
          SettlementRecord(
            id: 's1',
            from: 'ahmed',
            to: 'me',
            amount: 18.48,
            date: now.subtract(const Duration(hours: 5)),
            status: SettlementStatus.awaitingConfirmation,
          ),
        ],
      ),
      SplitGroup(
        id: 'g2',
        name: 'Oman road trip',
        emoji: '🏜️',
        members: const [me, o, s],
        expenses: [
          SplitExpense(
            id: 'e4',
            title: 'Fuel · ENOC',
            paidBy: 'omar',
            amount: 310,
            participants: const ['me', 'omar', 'sara'],
            date: now.subtract(const Duration(days: 20)),
          ),
          SplitExpense(
            id: 'e5',
            title: 'Hotel in Muscat',
            paidBy: 'me',
            amount: 1480,
            participants: const ['me', 'omar', 'sara'],
            date: now.subtract(const Duration(days: 19)),
          ),
          SplitExpense(
            id: 'e6',
            title: 'Dinner · Kargeen',
            paidBy: 'sara',
            amount: 420,
            participants: const ['me', 'omar'],
            date: now.subtract(const Duration(days: 18)),
          ),
        ],
      ),
      SplitGroup(
        id: 'g3',
        name: 'Friday brunch',
        emoji: '🥂',
        members: const [me, a, o],
        expenses: [
          SplitExpense(
            id: 'e7',
            title: 'Zuma brunch',
            paidBy: 'ahmed',
            amount: 1260,
            participants: const ['me', 'ahmed', 'omar'],
            date: now.subtract(const Duration(days: 5)),
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<SplitGroup>> splitGroups() => _d(List.of(_groups));

  void _updateGroup(String id, SplitGroup Function(SplitGroup) f) =>
      _groups = [for (final g in _groups) g.id == id ? f(g) : g];

  @override
  Future<SplitExpense> addSplitExpense(String groupId, SplitExpense expense) {
    _updateGroup(
      groupId,
      (g) => g.copyWith(expenses: [expense, ...g.expenses]),
    );
    return _d(expense);
  }

  @override
  Future<SplitGroup> createSplitGroup({
    required String name,
    String emoji = '👥',
    List<NewGroupMember> members = const [],
  }) {
    final g = SplitGroup(
      id: _id('newgroup'),
      name: name.trim(),
      emoji: emoji,
      members: [
        const Member('me', 'You', Color(0xFF5BC2A8), onPulse: true),
        for (final m in members)
          Member(
            _id('m'),
            m.name.trim(),
            const Color(0xFF5BC2A8),
            phone: m.phone == null ? null : toE164(m.phone!),
          ),
      ],
      expenses: const [],
    );
    _groups = [g, ..._groups];
    return _d(g);
  }

  /// Numbers of people who already use Pulse (demo).
  static const _pulseUsers = [
    '+971501234567',
    '+971552345678',
    '+971504445566',
    '+971585550101',
  ];

  @override
  Future<Set<String>> matchContacts(List<String> phoneHashes) {
    final known = {for (final p in _pulseUsers) phoneHash(p)};
    return _d(phoneHashes.where(known.contains).toSet());
  }

  @override
  Future<Member> addMember(
    String groupId, {
    required String name,
    String? phone,
  }) {
    final e164 = phone == null ? null : toE164(phone);
    final m = Member(
      _id('m'),
      name,
      const Color(0xFF5BC2A8),
      phone: e164,
      onPulse: e164 != null && _pulseUsers.contains(e164),
    );
    _updateGroup(groupId, (g) => g.copyWith(members: [...g.members, m]));
    return _d(m);
  }

  @override
  Future<SettlementRecord> markSettlementPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  }) {
    final rec = SettlementRecord(
      id: _id('s'),
      from: from,
      to: to,
      amount: amount,
      date: DateTime.now(),
      status: SettlementStatus.awaitingConfirmation,
    );
    _updateGroup(
      groupId,
      (g) => g.copyWith(settlements: [...g.settlements, rec]),
    );
    return _d(rec);
  }

  @override
  Future<SettlementRecord> confirmSettlement(
    String groupId,
    String settlementId,
  ) {
    late SettlementRecord out;
    _updateGroup(
      groupId,
      (g) => g.copyWith(
        settlements: [
          for (final s in g.settlements)
            if (s.id == settlementId)
              out = s.copyWith(status: SettlementStatus.confirmed)
            else
              s,
        ],
      ),
    );
    return _d(out);
  }

  @override
  Future<void> undoSettlement(String groupId, String settlementId) {
    _updateGroup(
      groupId,
      (g) => g.copyWith(
        settlements: [
          for (final s in g.settlements)
            if (s.id != settlementId) s,
        ],
      ),
    );
    return _d(null);
  }

  // ---- Monthly close -------------------------------------------------------

  final _passwords = <String, DateTime>{
    'enbd': DateTime(2026, 9, 2),
    'mashreq': DateTime(2026, 9, 2),
  };
  final _gmail = <EmailConnection>[];

  List<Statement> _seedStatements() {
    final end = DateTime(_now.year, _now.month, 0);
    final start = DateTime(end.year, end.month, 1);
    Statement st(
      String id,
      String inst,
      String label,
      ParseStatus p,
      ReconStatus r, {
      double? diff,
      String source = 'gmail',
      DateTime? s,
      DateTime? e,
    }) => Statement(
      id: id,
      institution: inst,
      accountLabel: label,
      parse: p,
      recon: r,
      diff: diff,
      source: source,
      periodStart: s ?? start,
      periodEnd: e ?? end,
    );
    final prevEnd = DateTime(end.year, end.month, 0);
    final prevStart = DateTime(prevEnd.year, prevEnd.month, 1);
    return [
      st(
        'st1',
        'enbd',
        'Emirates NBD Current',
        ParseStatus.parsed,
        ReconStatus.matched,
      ),
      st(
        'st2',
        'mashreq',
        'Mashreq Cashback ••0937',
        ParseStatus.parsed,
        ReconStatus.mismatch,
        diff: 238,
      ),
      st(
        'st3',
        'fab',
        'FAB Cashback ••6604',
        ParseStatus.needsPassword,
        ReconStatus.pending,
      ),
      st(
        'st4',
        'enbd',
        'Emirates NBD Skywards ••4821',
        ParseStatus.parsed,
        ReconStatus.matched,
        source: 'upload',
      ),
      st(
        'st5',
        'enbd',
        'Emirates NBD Current',
        ParseStatus.parsed,
        ReconStatus.matched,
        s: prevStart,
        e: prevEnd,
      ),
      st(
        'st6',
        'mashreq',
        'Mashreq Cashback ••0937',
        ParseStatus.parsed,
        ReconStatus.matched,
        s: prevStart,
        e: prevEnd,
      ),
    ];
  }

  @override
  Future<List<Statement>> statements() => _d(List.of(_statements));

  @override
  Future<Reconciliation> reconciliation(String statementId) {
    final s = _statements.firstWhere((e) => e.id == statementId);
    final end = s.periodEnd ?? _now;
    if (s.state == CloseState.mismatch) {
      return _d(
        Reconciliation(
          statementId: s.id,
          status: s.recon,
          opening: 2952,
          closing: 3428,
          computedClosing: 3190,
          diff: -238,
          linked: 41,
          statementOnly: [
            ReconLine(
              date: DateTime(end.year, end.month, 18),
              description: 'NOON.COM DUBAI',
              amount: 238,
            ),
          ],
          warnings: const ['One purchase on the statement was never captured.'],
        ),
      );
    }
    return _d(
      Reconciliation(
        statementId: s.id,
        status: s.recon,
        opening: 6120,
        closing: 8420.5,
        computedClosing: 8420.5,
        diff: 0,
        linked: 37,
      ),
    );
  }

  @override
  Future<UploadResult> uploadStatement({
    required Uint8List bytes,
    required String filename,
    String? institution,
  }) {
    final id = _id('up');
    _statements = [
      Statement(
        id: id,
        institution: institution,
        accountLabel: filename,
        parse: ParseStatus.pending,
        recon: ReconStatus.pending,
        filename: filename,
        periodEnd: DateTime(_now.year, _now.month, 0),
      ),
      ..._statements,
    ];
    return _d(UploadResult(id: id, duplicate: false));
  }

  @override
  Future<void> reprocessStatement(String statementId) {
    _statements = [
      for (final s in _statements)
        s.id == statementId
            ? s.copyWith(parse: ParseStatus.parsed, recon: ReconStatus.matched)
            : s,
    ];
    return _d(null);
  }

  @override
  Future<List<StatementPassword>> statementPasswords() => _d([
    for (final e in _passwords.entries) StatementPassword(e.key, e.value),
  ]);

  @override
  Future<void> setStatementPassword(String institution, String password) {
    _passwords[institution] = DateTime.now();
    // The backend re-queues locked statements; the demo unlocks them at once.
    _statements = [
      for (final s in _statements)
        s.institution == institution && s.parse == ParseStatus.needsPassword
            ? s.copyWith(parse: ParseStatus.parsed, recon: ReconStatus.matched)
            : s,
    ];
    return _d(null);
  }

  @override
  Future<Uri?> startGmailConnect() {
    if (_gmail.isEmpty) {
      _gmail.add(
        EmailConnection(
          id: 'gm1',
          email: 'sara@example.ae',
          status: 'active',
          lastSyncedAt: DateTime.now(),
        ),
      );
    }
    return _d(null);
  }

  @override
  Future<List<EmailConnection>> emailConnections() => _d(List.of(_gmail));

  // ---- Insights ------------------------------------------------------------

  static const _income = 24500.0;
  static const _history = [11200.0, 12850.0, 13900.0, 11980.0, 12400.0];
  static const _cash = 69700.0;
  static const _upcomingBills = 310.0; // DEWA, due on the 28th
  static const _goals = 200.0; // Emergency fund top-up

  double get _spentThisMonth => _tx
      .where((t) => !t.isIncome && !t.excluded && !t.category.isTransfer)
      .fold(0.0, (a, t) => a + t.amount);

  double get _duesBeforeMonthEnd {
    final end = DateTime(_now.year, _now.month + 1, 0);
    return _owned
        .where((c) => !c.dueDate.isAfter(end))
        .fold(0.0, (a, c) => a + c.totalDue);
  }

  @override
  Future<Cashflow> cashflow() {
    final dim = DateUtils.getDaysInMonth(_now.year, _now.month);
    final months = [
      for (var i = 0; i < 5; i++)
        CashflowMonth(
          _short(DateTime(_now.year, _now.month - 5 + i).month),
          _income + (i == 2 ? 1800 : 0),
          _history[i],
        ),
      CashflowMonth(_short(_now.month), _income, _spentThisMonth),
    ];
    final committed = _upcomingBills + _duesBeforeMonthEnd;
    return _d(
      Cashflow(
        months: months,
        balanceNow: _cash,
        committed: committed,
        projectedEndBalance: projectEndBalance(
          balanceNow: _cash,
          spentSoFar: _spentThisMonth - 6250, // rent is not daily spend
          dayOfMonth: _now.day,
          daysInMonth: dim,
          committed: committed,
        ),
      ),
    );
  }

  @override
  Future<CategoryTrends> categoryTrends() {
    final byCat = <SpendCategory, double>{};
    for (final t in _tx) {
      if (t.isIncome || t.excluded || t.category.isTransfer) continue;
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amount;
    }
    final top = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // Deterministic history around this month's figure.
    const shape = [0.82, 1.06, 0.94, 1.18, 0.9];
    return _d(
      CategoryTrends(
        [
          for (var i = 5; i >= 0; i--)
            _short(DateTime(_now.year, _now.month - i).month),
        ],
        [
          for (final (i, e) in top.take(6).indexed)
            CategoryTrend(e.key, [
              for (var m = 0; m < 5; m++)
                e.value * shape[(m + i) % shape.length],
              e.value,
            ]),
        ],
      ),
    );
  }

  @override
  Future<SafeToSpend> safeToSpend() async {
    var goalMinor = 0;
    var lines = <GoalLine>[];
    if (goals case final store?) {
      final recs = await store.goals();
      final linked = {for (final a in await assets()) a.id: a};
      final res = goalReservations(
        GoalService.inputs(recs, await store.contributions(), linked),
        CalDate(_now.year, _now.month, _now.day),
      );
      goalMinor = totalReserved(res);
      lines = [for (final g in res) GoalLine(g.goalId, g.name, g.amountMinor / 100)];
    }
    final dim = DateUtils.getDaysInMonth(_now.year, _now.month);
    final planned = _planned.values.fold(0.0, (a, b) => a + b);
    return _d(
      computeSafeToSpend(
        cash: _cash,
        budgetLeft: planned - _spentThisMonth,
        bills: _upcomingBills,
        cardDues: _duesBeforeMonthEnd,
        goals: goals == null ? _goals : goalMinor / 100,
        daysLeft: dim - _now.day + 1,
        goalLines: lines,
      ),
    );
  }

  @override
  Future<HealthScore> healthScore() {
    final limits = _owned.fold(0.0, (a, c) => a + c.limit);
    final balances = _owned.fold(0.0, (a, c) => a + c.balance);
    final avgSpend = _history.reduce((a, b) => a + b) / _history.length;
    return _d(
      computeHealthScore(
        savingsRate: (_income - _history.last) / _income,
        utilisation: limits == 0 ? 0 : balances / limits,
        onTimeRate: 11 / 12,
        runwayMonths: _cash / avgSpend,
      ),
    );
  }

  var _captureSeq = 0;

  /// Alternates a dining tap that hits FAB's cap and a grocery tap.
  @override
  Future<Transaction> simulateCapture() {
    final dining = (_captureSeq++).isEven;
    final cardId = dining ? 'fab-cb' : 'mashreq-cb';
    final cat = dining ? SpendCategory.dining : SpendCategory.groceries;
    final amount = dining ? 142.0 : 230.5;
    final card = _owned.firstWhere((c) => c.id == cardId);
    final reward = rewardFor(card, cat, amount);
    _owned = [
      for (final c in _owned)
        if (c.id == cardId)
          c.copyWith(
            balance: c.balance + amount,
            caps: {
              ...c.caps,
              if (c.caps[cat] != null) cat: c.caps[cat]!.add(reward),
            },
          )
        else
          c,
    ];
    final tx = Transaction(
      id: _id('live'),
      merchant: dining ? 'Talabat' : 'Carrefour',
      amount: amount,
      category: cat,
      date: DateTime.now(),
      source: dining ? TxSource.walletNotification : TxSource.sms,
      cardId: cardId,
      accountLabel: '${card.issuer} ${card.name}',
    );
    _tx = [tx, ..._tx];
    return _d(tx);
  }

  // ---- Family --------------------------------------------------------------

  late var _family = [
    const FamilyMember(
      id: 'me',
      name: 'Sara',
      relation: 'You',
      sharing: SharingLevel.categories,
      isYou: true,
    ),
    FamilyMember(
      id: 'f1',
      name: 'Khalid',
      relation: 'Partner',
      phone: '+971501112233',
      sharing: SharingLevel.full,
      spent: 9420,
      budget: 11000,
      byCategory: {
        SpendCategory.groceries: 2140,
        SpendCategory.transport: 1310,
        SpendCategory.dining: 960,
        SpendCategory.family: 3500,
      },
    ),
    FamilyMember(
      id: 'f2',
      name: 'Noor',
      relation: 'Daughter',
      phone: '+971502223344',
      sharing: SharingLevel.totals,
      spent: 640,
      budget: 800,
    ),
  ];

  @override
  Future<Household> household() {
    final spent = _spentThisMonth;
    final planned = _planned.values.fold(0.0, (a, b) => a + b);
    return _d(
      Household('Al Mansoori household', [
        for (final m in _family)
          if (m.isYou)
            FamilyMember(
              id: m.id,
              name: m.name,
              relation: m.relation,
              sharing: m.sharing,
              isYou: true,
              spent: spent,
              budget: planned,
            )
          else
            m,
      ]),
    );
  }

  @override
  Future<FamilyMember> inviteFamilyMember({
    required String name,
    required String phone,
    required String relation,
  }) {
    final m = FamilyMember(
      id: _id('f'),
      name: name,
      relation: relation,
      phone: toE164(phone),
      sharing: SharingLevel.totals,
      invited: true,
    );
    _family = [..._family, m];
    return _d(m);
  }

  @override
  Future<void> setSharing(String memberId, SharingLevel level) {
    _family = [
      for (final m in _family)
        m.id == memberId ? m.copyWith(sharing: level) : m,
    ];
    return _d(null);
  }
}
