import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../models.dart';
import '../repository.dart';
import 'api_exception.dart';
import 'dto.dart';

/// [PulseRepository] backed by the Pulse FastAPI backend.
///
/// The backend is thinner than the UI models, so some screens are partly
/// derived or stubbed:
///  * Card rewards, minimum due and the card catalog have no backend source.
///  * Net-worth history does not exist, so the series is flat.
///  * Budget trend is built from the monthly budgets' spent figures.
class ApiPulseRepository implements PulseRepository {
  ApiPulseRepository(this._dio, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _clock;

  /// Safety cap for "fetch everything" listings: 3 pages x 200.
  static const _maxPages = 3;
  static const _pageSize = 200;

  // ---- low-level -----------------------------------------------------------

  Future<List<Map<String, Object?>>> _getList(
    String path, {
    Map<String, Object?>? query,
  }) => guardApi(() async {
    final res = await _dio.get<List<Object?>>(path, queryParameters: query);
    return [
      for (final e in res.data ?? const <Object?>[])
        Map<String, Object?>.from(e! as Map),
    ];
  });

  Future<Map<String, Object?>> _getMap(
    String path, {
    Map<String, Object?>? query,
  }) => guardApi(() async {
    final res = await _dio.get<Map<String, Object?>>(
      path,
      queryParameters: query,
    );
    return res.data!;
  });

  Future<Map<String, Object?>> _send(
    String method,
    String path,
    Map<String, Object?> body,
  ) => guardApi(() async {
    final res = await _dio.request<Map<String, Object?>>(
      path,
      data: body,
      options: Options(method: method),
    );
    return res.data!;
  });

  Future<Map<String, AccountDto>> _accounts() async => {
    for (final a in await _getList('/v1/accounts'))
      AccountDto.fromJson(a).id: AccountDto.fromJson(a),
  };

  Future<Map<String, CategoryDto>> _categories() async => {
    for (final c in await _getList('/v1/categories'))
      CategoryDto.fromJson(c).id: CategoryDto.fromJson(c),
  };

  // ---- transactions ----------------------------------------------------------

  Future<PageDto<TransactionDto>> _txPage({
    String? cursor,
    int limit = 50,
    DateTime? from,
  }) async {
    final json = await _getMap(
      '/v1/transactions',
      query: {
        'limit': limit,
        'cursor': ?cursor,
        if (from != null) 'date_from': from.toUtc().toIso8601String(),
      },
    );
    return PageDto.fromJson(json, TransactionDto.fromJson);
  }

  @override
  Future<TxPage> transactionsPage({String? cursor, int limit = 50}) async {
    final (page, accounts, categories) = await (
      _txPage(cursor: cursor, limit: limit),
      _accounts(),
      _categories(),
    ).wait;
    return TxPage([
      for (final t in page.items)
        t.toDomain(accounts: accounts, categories: categories),
    ], nextCursor: page.nextCursor);
  }

  /// Follows `next_cursor` until exhausted or [_maxPages] is reached.
  Future<List<TransactionDto>> _allTx({DateTime? from}) async {
    final out = <TransactionDto>[];
    String? cursor;
    for (var i = 0; i < _maxPages; i++) {
      final page = await _txPage(cursor: cursor, limit: _pageSize, from: from);
      out.addAll(page.items);
      cursor = page.nextCursor;
      if (cursor == null) break;
    }
    return out;
  }

  @override
  Future<List<Transaction>> transactions() async {
    final (txs, accounts, categories) = await (
      _allTx(),
      _accounts(),
      _categories(),
    ).wait;
    return [
      for (final t in txs)
        t.toDomain(accounts: accounts, categories: categories),
    ];
  }

  /// Backend category to use when the user picks [c] in the UI: exact label or
  /// name match first, then any category mapping to the same bucket.
  CategoryDto? _categoryFor(SpendCategory c, Iterable<CategoryDto> all) {
    final want = c == SpendCategory.income ? 'income' : 'expense';
    final mine = all.where((x) => x.kind == want).toList();
    for (final x in mine) {
      if (x.name.toLowerCase() == c.label.toLowerCase()) return x;
    }
    for (final x in mine) {
      if (x.spendCategory == c) return x;
    }
    return null;
  }

  @override
  Future<Transaction> recategorise(String txId, SpendCategory category) async {
    final (accounts, categories) = await (_accounts(), _categories()).wait;
    final target = _categoryFor(category, categories.values);
    if (target == null) {
      throw ApiException(
        message: 'No "${category.label}" category exists on the server.',
        code: 'category_unavailable',
      );
    }
    final json = await _send('PATCH', '/v1/transactions/$txId', {
      'category_id': target.id,
      'remember_merchant': true,
    });
    return TransactionDto.fromJson(json)
        .toDomain(accounts: accounts, categories: categories);
  }

  @override
  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
  }) async {
    var (accounts, categories) = await (_accounts(), _categories()).wait;
    // Prefer a cash account for manual entries; create one on first use.
    final cash = accounts.values.where((a) => a.type == 'cash');
    AccountDto? acct = cash.isNotEmpty
        ? cash.first
        : (accounts.values.isNotEmpty ? accounts.values.first : null);
    if (acct == null) {
      acct = AccountDto.fromJson(
        await _send('POST', '/v1/accounts', {
          'type': 'cash',
          'name': 'Cash',
          'currency': 'AED',
        }),
      );
      accounts = {...accounts, acct.id: acct};
    }
    final cat = _categoryFor(category, categories.values);
    final json = await _send('POST', '/v1/transactions', {
      'account_id': acct.id,
      'amount_minor': toMinor(amount),
      'direction': category == SpendCategory.income ? 'credit' : 'debit',
      'merchant_raw': merchant,
      if (cat != null) 'category_id': cat.id,
      'posted_at': _clock().toUtc().toIso8601String(),
    });
    return TransactionDto.fromJson(json)
        .toDomain(accounts: accounts, categories: categories);
  }

  // ---- budgets ---------------------------------------------------------------

  static const _months = [
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
  ];

  @override
  Future<BudgetOverview> budgetOverview() async {
    final now = _clock();
    final monthStart = DateTime(now.year, now.month);
    final dim = DateUtils.getDaysInMonth(now.year, now.month);
    final (budgetsJson, txs, accounts, categories) = await (
      _getList('/v1/budgets'),
      _allTx(from: monthStart),
      _accounts(),
      _categories(),
    ).wait;
    final budgets = budgetsJson.map(BudgetDto.fromJson).toList();

    bool sameMonth(DateTime d, DateTime m) =>
        d.year == m.year && d.month == m.month;
    final current = budgets
        .where((b) => sameMonth(b.month, monthStart))
        .toList();

    final spend = txs.where((t) => t.direction == 'debit').toList();
    final byMerchant = <String, List<TransactionDto>>{};
    final byCard = <String, double>{};
    final byAccount = <String, double>{};
    for (final t in spend) {
      final tx = t.toDomain(accounts: accounts, categories: categories);
      byMerchant.putIfAbsent(tx.merchant, () => []).add(t);
      final acct = accounts[t.accountId];
      final target = (acct?.isCreditCard ?? false) ? byCard : byAccount;
      target[tx.accountLabel] = (target[tx.accountLabel] ?? 0) + tx.amount;
    }
    final spent = spend.fold<double>(0, (a, t) => a + fromMinor(t.amountMinor));
    final planned = current.fold<double>(
      0,
      (a, b) => a + fromMinor(b.limitMinor),
    );

    final lines = [
      for (final b in current)
        BudgetLine(
          category:
              categories[b.categoryId]?.spendCategory ?? SpendCategory.other,
          planned: fromMinor(b.limitMinor),
          spent: fromMinor(b.spentMinor),
        ),
    ]..sort((a, b) => b.spent.compareTo(a.spent));

    // Trend: totals per budget month, oldest first, last six months.
    final byMonth = <DateTime, List<BudgetDto>>{};
    for (final b in budgets) {
      byMonth
          .putIfAbsent(DateTime(b.month.year, b.month.month), () => [])
          .add(b);
    }
    final months = byMonth.keys.toList()..sort();
    final trend = [
      for (final m in months.reversed.take(6).toList().reversed)
        MonthlyTotal(
          _months[m.month - 1],
          sameMonth(m, monthStart)
              ? spent
              : byMonth[m]!.fold<double>(
                  0,
                  (a, b) => a + fromMinor(b.spentMinor),
                ),
          byMonth[m]!.fold<double>(0, (a, b) => a + fromMinor(b.limitMinor)),
        ),
    ];

    final merchants = [
      for (final e in byMerchant.entries)
        MerchantTotal(
          e.key,
          (categories[e.value.first.categoryId]?.spendCategory) ??
              SpendCategory.other,
          e.value.fold<double>(0, (a, t) => a + fromMinor(t.amountMinor)),
          e.value.length,
        ),
    ]..sort((a, b) => b.total.compareTo(a.total));

    return BudgetOverview(
      planned: planned,
      spent: spent,
      daysLeft: dim - now.day + 1,
      daysInMonth: dim,
      lines: lines,
      trend: trend,
      topMerchants: merchants.take(5).toList(),
      byCard: byCard,
      byAccount: byAccount,
      autoCaptured: spend.where((t) => txSourceFor(t.source).automatic).length,
      manual: spend.where((t) => !txSourceFor(t.source).automatic).length,
    );
  }

  // ---- cards -------------------------------------------------------------------

  static const _gradients = [
    [Color(0xFF0B1F4B), Color(0xFF1E3A8A), Color(0xFFB91C1C)],
    [Color(0xFF111827), Color(0xFF374151), Color(0xFF0EA5E9)],
    [Color(0xFF3B0764), Color(0xFF7C3AED), Color(0xFFEC4899)],
    [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF22D3EE)],
  ];

  DateTime _nextDay(int? day) {
    final now = _clock();
    final d = (day ?? 1).clamp(1, 28);
    final thisMonth = DateTime(now.year, now.month, d);
    return thisMonth.isBefore(DateTime(now.year, now.month, now.day))
        ? DateTime(now.year, now.month + 1, d)
        : thisMonth;
  }

  @override
  Future<List<CreditCard>> myCards() async {
    final (accounts, liabilities) = await (
      _accounts(),
      _getList('/v1/liabilities'),
    ).wait;
    final owed = <String, int>{};
    for (final l in liabilities.map(LiabilityDto.fromJson)) {
      if (l.accountId != null) {
        owed[l.accountId!] = (owed[l.accountId!] ?? 0) + l.outstandingMinor;
      }
    }
    final cards = accounts.values.where((a) => a.isCreditCard).toList();
    return [
      for (var i = 0; i < cards.length; i++)
        CreditCard(
          id: cards[i].id,
          issuer: cards[i].institution ?? cards[i].name,
          name: cards[i].name,
          last4: cards[i].last4 ?? '----',
          network: CardNetwork.visa, // not stored by the backend
          gradient: _gradients[i % _gradients.length],
          limit: fromMinor(cards[i].creditLimitMinor ?? 0),
          balance: fromMinor(owed[cards[i].id] ?? 0),
          dueDate: _nextDay(cards[i].dueDay),
          minDue: 0, // TODO(api): no minimum-due field yet.
          rewardsLabel: 'Rewards',
          rewardPoints: 0,
          rewardValueAed: 0,
          categoryRates: const {},
        ),
    ];
  }

  /// TODO(api): the backend has no card catalog / suggestion endpoint yet.
  @override
  Future<List<CreditCard>> cardCatalog() async => const [];

  // ---- wealth ------------------------------------------------------------------

  @override
  Future<NetWorth> netWorth() async =>
      NetWorthDto.fromJson(await _getMap('/v1/net-worth')).toDomain();

  @override
  Future<List<Asset>> assets() async {
    final (assets, liabilities) = await (
      _getList('/v1/assets'),
      _getList('/v1/liabilities'),
    ).wait;
    return [
      ...assets.map((j) => AssetDto.fromJson(j).toDomain()),
      ...liabilities.map((j) => LiabilityDto.fromJson(j).toDomain()),
    ];
  }

  // ---- splits ------------------------------------------------------------------

  Future<String?> _myUserId() async {
    final me = await _getMap('/v1/me');
    return me['id'] as String?;
  }

  @override
  Future<List<SplitGroup>> splitGroups() async {
    final (groupsJson, me) = await (
      _getList('/v1/splits/groups'),
      _myUserId(),
    ).wait;
    final groups = groupsJson.map(SplitGroupDto.fromJson).toList();
    final expenses = await Future.wait([
      for (final g in groups)
        _getList('/v1/splits/groups/${g.id}/expenses', query: {'limit': 100}),
    ]);
    return [
      for (var i = 0; i < groups.length; i++)
        splitGroupToDomain(
          groups[i],
          expenses[i].map(SplitExpenseDto.fromJson).toList(),
          myUserId: me,
        ),
    ];
  }

  @override
  Future<SplitExpense> addSplitExpense(
    String groupId,
    SplitExpense expense,
  ) async {
    final (groupJson, me) = await (
      _getMap('/v1/splits/groups/$groupId'),
      _myUserId(),
    ).wait;
    final group = SplitGroupDto.fromJson(groupJson);
    String resolve(String id) {
      if (id != 'me') return id;
      final mine = group.members.where((m) => m.userId == me);
      if (mine.isEmpty) {
        throw const ApiException(
          message: 'You are not a member of this group.',
          code: 'invalid_member',
        );
      }
      return mine.first.id;
    }

    final explicit = expense.shares;
    final json = await _send('POST', '/v1/splits/groups/$groupId/expenses', {
      'description': expense.title,
      'amount_minor': toMinor(expense.amount),
      'paid_by_member_id': resolve(expense.paidBy),
      'split_type': explicit == null ? 'equal' : 'exact',
      'participants': [
        for (final p in expense.participants)
          {
            'member_id': resolve(p),
            if (explicit != null) 'amount_minor': toMinor(explicit[p] ?? 0),
          },
      ],
      'spent_at': expense.date.toUtc().toIso8601String(),
    });
    return splitGroupToDomain(group, [
      SplitExpenseDto.fromJson(json),
    ], myUserId: me).expenses.single;
  }
}
