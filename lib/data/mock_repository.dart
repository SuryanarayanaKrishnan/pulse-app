import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'repository.dart';

typedef S = SpendCategory;

/// In-memory repository with realistic UAE sample data.
class MockPulseRepository implements PulseRepository {
  MockPulseRepository({
    this.latency = const Duration(milliseconds: 450),
    DateTime? now,
  }) : _now = now ?? DateTime.now() {
    _tx = _seedTransactions();
    _groups = _seedGroups();
  }

  final Duration latency;
  final DateTime _now;
  late List<Transaction> _tx;
  late List<SplitGroup> _groups;
  var _manualSeq = 0;

  Future<T> _d<T>(T v) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return v;
  }

  // ---- Cards -------------------------------------------------------------

  static final _due = DateTime(2026, 1, 1);

  List<CreditCard> get _owned => [
    CreditCard(
      id: 'enbd-sky',
      issuer: 'Emirates NBD',
      name: 'Skywards Infinite',
      last4: '4821',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF0B1F4B), Color(0xFF1E3A8A), Color(0xFFB91C1C)],
      limit: 60000,
      balance: 8420.5,
      dueDate: _dayInMonth(_now, 4),
      minDue: 421,
      rewardsLabel: 'Skywards Miles',
      rewardPoints: 48210,
      rewardValueAed: 964,
      categoryRates: const {
        SpendCategory.travel: 3.5,
        SpendCategory.dining: 2,
        SpendCategory.shopping: 1.5,
        SpendCategory.groceries: 1,
      },
      annualFee: 0,
      highlight: '3.5 Skywards Miles per AED 1 on flights',
    ),
    CreditCard(
      id: 'mashreq-cb',
      issuer: 'Mashreq',
      name: 'Cashback Card',
      last4: '0937',
      network: CardNetwork.mastercard,
      gradient: const [Color(0xFF7C2D12), Color(0xFFEA580C), Color(0xFFFBBF24)],
      limit: 25000,
      balance: 3190,
      dueDate: _dayInMonth(_now, 12),
      minDue: 160,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 312,
      categoryRates: const {
        SpendCategory.groceries: 5,
        SpendCategory.transport: 5,
        SpendCategory.dining: 2,
        SpendCategory.bills: 0.5,
      },
      highlight: '5% cashback on groceries and transport',
    ),
    CreditCard(
      id: 'fab-cb',
      issuer: 'FAB',
      name: 'Cashback Platinum',
      last4: '6604',
      network: CardNetwork.visa,
      gradient: const [Color(0xFF0F172A), Color(0xFF134E4A), Color(0xFF2DD4BF)],
      limit: 40000,
      balance: 11760,
      dueDate: _dayInMonth(_now, 21),
      minDue: 588,
      rewardsLabel: 'Cashback',
      rewardPoints: 0,
      rewardValueAed: 540,
      categoryRates: const {
        SpendCategory.dining: 5,
        SpendCategory.entertainment: 5,
        SpendCategory.shopping: 2,
        SpendCategory.health: 2,
      },
      annualFee: 0,
      highlight: '5% on dining and entertainment',
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
      categoryRates: const {
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
      categoryRates: const {
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
      categoryRates: const {
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
      categoryRates: const {
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
  Future<List<CreditCard>> myCards() => _d(_owned);
  @override
  Future<List<CreditCard>> cardCatalog() => _d(_catalog);

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
      );
    }

    const src = TxSource.sms;
    return [
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
        S.bills,
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
        'Du Telecom',
        399.00,
        S.bills,
        8,
        TxSource.statement,
        'enbd-current',
        'Emirates NBD Current',
      ),
      t(
        'Salary · Acme FZ-LLC',
        24500.00,
        S.income,
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
  Future<Transaction> recategorise(String txId, SpendCategory category) async {
    final i = _tx.indexWhere((e) => e.id == txId);
    _tx[i] = _tx[i].copyWith(category: category);
    return _d(_tx[i]);
  }

  @override
  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
  }) async {
    final tx = Transaction(
      id: 'manual${_manualSeq++}',
      merchant: merchant,
      amount: amount,
      category: category,
      date: DateTime.now(),
      source: TxSource.manual,
      cardId: 'cash',
      accountLabel: 'Cash',
    );
    _tx = [tx, ..._tx];
    return _d(tx);
  }

  // ---- Budget ------------------------------------------------------------

  static const _planned = {
    SpendCategory.groceries: 1600.0,
    SpendCategory.dining: 1200.0,
    SpendCategory.transport: 600.0,
    SpendCategory.bills: 1100.0,
    SpendCategory.shopping: 1000.0,
    SpendCategory.travel: 2500.0,
    SpendCategory.health: 500.0,
    SpendCategory.entertainment: 400.0,
    SpendCategory.rent: 6250.0,
  };

  @override
  Future<BudgetOverview> budgetOverview() async {
    final spend = _tx.where((t) => !t.isIncome).toList();
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
    final lines =
        _planned.entries
            .map(
              (e) => BudgetLine(
                category: e.key,
                planned: e.value,
                spent: byCat[e.key] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.spent.compareTo(a.spent));
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
      name: 'Gold · 120g 22K',
      kind: AssetKind.gold,
      value: 41800,
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
  Future<List<Asset>> assets() => _d(_assets);

  @override
  Future<NetWorth> netWorth() {
    final total = _assets.fold(
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
        changePct: (s.last / s[s.length - 2] - 1) * 100 + 0.8,
        changeAed: s.last - s.first,
      ),
    );
  }

  // ---- Splits ------------------------------------------------------------

  List<SplitGroup> _seedGroups() {
    const me = Member('me', 'You', Color(0xFF7C5CFF));
    const a = Member('ahmed', 'Ahmed', Color(0xFF2DD4BF));
    const s = Member('sara', 'Sara', Color(0xFFF472B6));
    const o = Member('omar', 'Omar', Color(0xFFFBBF24));
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

  @override
  Future<SplitExpense> addSplitExpense(
    String groupId,
    SplitExpense expense,
  ) async {
    _groups = [
      for (final g in _groups)
        if (g.id == groupId)
          SplitGroup(
            id: g.id,
            name: g.name,
            emoji: g.emoji,
            members: g.members,
            expenses: [expense, ...g.expenses],
          )
        else
          g,
    ];
    return _d(expense);
  }
}
