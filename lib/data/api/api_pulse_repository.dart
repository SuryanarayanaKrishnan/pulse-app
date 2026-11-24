import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

import '../insights.dart';
import '../models.dart';
import '../repository.dart';
import '../rules.dart';
import '../statements.dart';
import 'api_exception.dart';
import 'dto.dart';

/// [PulseRepository] backed by the Pulse FastAPI backend.
///
/// The backend is thinner than the UI models, so some screens are partly
/// derived or stubbed:
///  * Card rewards, minimum due and the card catalog have no backend source.
///  * Net-worth history does not exist, so the series is flat.
///  * Budget trend is built from the monthly budgets' spent figures.
class ApiPulseRepository with LocalOnlyFeatures implements PulseRepository {
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

  Future<void> _delete(String path) =>
      guardApi(() => _dio.delete<Object?>(path));

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
    for (final x in all) {
      if (x.id == c.id || x.slug == c.id) return x;
    }
    for (final x in all) {
      if (x.name.toLowerCase() == c.label.toLowerCase()) return x;
    }
    for (final x in all) {
      if (x.spendCategory == c) return x;
    }
    return null;
  }

  @override
  Future<Transaction> recategorise(
    String txId,
    SpendCategory category, {
    bool remember = false,
  }) async {
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
      'remember_merchant': remember,
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
      'direction': category.isIncome ? 'credit' : 'debit',
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

    final spend = txs
        .where(
          (t) =>
              t.direction == 'debit' &&
              !(categories[t.categoryId]?.spendCategory.isTransfer ?? false),
        )
        .toList();
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

  @override
  Future<List<SpendCategory>> categories() async {
    final all = (await _categories()).values.where((c) => !c.isHidden);
    final custom = [
      for (final c in all)
        if (c.spendCategory.custom) c.spendCategory,
    ];
    // Defaults in their canonical order (all of them, so the picker is
    // complete even before the backend seeds new ones), then custom.
    return [...SpendCategory.defaults, ...custom];
  }

  @override
  Future<SpendCategory> createCategory({
    required String name,
    CategoryKind kind = CategoryKind.expense,
    String? iconKey, // the hosted API has no icon field yet; kept on device only
  }) async {
    final json = await _send('POST', '/v1/categories', {
      'name': name.trim(),
      'kind': kind.name,
    });
    final dto = CategoryDto.fromJson(json);
    return SpendCategory.custom(dto.id, dto.name, kind: dto.categoryKind, iconKey: iconKey);
  }

  @override
  Future<void> setBudget(SpendCategory category, double monthly) async {
    final now = _clock();
    final (budgetsJson, categories) = await (
      _getList('/v1/budgets'),
      _categories(),
    ).wait;
    final target = _categoryFor(category, categories.values);
    if (target == null) {
      throw ApiException(
        message: 'No "${category.label}" category exists on the server.',
        code: 'category_unavailable',
      );
    }
    final existing = budgetsJson
        .map(BudgetDto.fromJson)
        .where(
          (b) =>
              b.categoryId == target.id &&
              b.month.year == now.year &&
              b.month.month == now.month,
        )
        .firstOrNull;
    if (monthly <= 0) {
      if (existing != null) await _delete('/v1/budgets/${existing.id}');
      return;
    }
    if (existing != null) {
      await _send('PATCH', '/v1/budgets/${existing.id}', {
        'limit_minor': toMinor(monthly),
      });
    } else {
      await _send('POST', '/v1/budgets', {
        'category_id': target.id,
        'month': DateTime(
          now.year,
          now.month,
        ).toIso8601String().substring(0, 10),
        'limit_minor': toMinor(monthly),
        'currency': 'AED',
      });
    }
  }

  // ---- automations -----------------------------------------------------------

  /// `/v1/rules`: conditions (AND) + actions. The UI edits one condition.
  @override
  Future<List<AutomationRule>> rules() async {
    final (json, categories, accounts) = await (
      _getList('/v1/rules'),
      _categories(),
      _accounts(),
    ).wait;
    return [
      for (final r in json)
        ?ruleFromJson(r, categories: categories, accounts: accounts),
    ];
  }

  @override
  Future<AutomationRule> saveRule(AutomationRule rule) async {
    final (categories, accounts) = await (_categories(), _accounts()).wait;
    final body = ruleToJson(
      rule,
      categoryId: rule.category == null
          ? null
          : _categoryFor(rule.category!, categories.values)?.id,
      accounts: accounts.values,
    );
    final json = await _send('POST', '/v1/rules', {
      ...body,
      'apply_to_existing': true,
    });
    return ruleFromJson(json, categories: categories, accounts: accounts) ??
        rule.copyWith(id: json['id']! as String);
  }

  @override
  Future<void> deleteRule(String id) => _delete('/v1/rules/$id');

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

  /// `/v1/rewards/summary` keyed by account id; empty while the endpoint is
  /// not deployed.
  Future<Map<String, Map<String, Object?>>> _rewardsByAccount() async {
    try {
      final j = await _getMap('/v1/rewards/summary');
      return {
        for (final c in (j['cards'] as List? ?? const []))
          if ((c as Map)['account_id'] != null)
            c['account_id']! as String: Map<String, Object?>.from(c),
      };
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) return const {};
      rethrow;
    }
  }

  static CreditCard _withRewards(CreditCard card, Map<String, Object?>? r) {
    if (r == null) return card;
    double n(Object? v) => v == null ? 0 : double.parse('$v');
    final cash = r['unit'] == 'cashback';
    final caps = <SpendCategory, RewardCap>{};
    for (final c in (r['caps'] as List? ?? const [])) {
      final m = Map<String, Object?>.from(c as Map);
      if (!cash || m['cap_units'] == null) continue;
      final cat = spendCategoryFor('${m['rule']}');
      if (cat == SpendCategory.other) continue;
      caps[cat] = RewardCap(limit: n(m['cap_units']), used: n(m['used_units']));
    }
    return CreditCard(
      id: card.id,
      issuer: (r['issuer'] as String?) ?? card.issuer,
      name: (r['name'] as String?) ?? card.name,
      last4: card.last4,
      network: card.network,
      gradient: card.gradient,
      limit: card.limit,
      balance: card.balance,
      dueDate: card.dueDate,
      minDue: card.minDue,
      rewardsLabel: cash ? 'Cashback this cycle' : 'Points this cycle',
      rewardPoints: cash ? 0 : n(r['earned_units']).round(),
      rewardValueAed: fromMinor(
        (r['earned_value_minor'] as num?)?.toInt() ?? 0,
      ),
      categoryRates: card.categoryRates,
      statementDate: r['cycle_end'] == null
          ? null
          : DateTime.parse(r['cycle_end']! as String),
      caps: caps,
      rulesVerifiedOn: r['verified_on'] == null
          ? null
          : DateTime.parse(r['verified_on']! as String),
      catalogId: card.catalogId,
    );
  }

  @override
  @override
  Future<List<CreditCard>> myCards() async {
    final (accounts, liabilities, rewards) = await (
      _accounts(),
      _getList('/v1/liabilities'),
      _rewardsByAccount(),
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
        _withRewards(
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
          rewards[cards[i].id],
        ),
    ];
  }

  /// TODO(api): the backend has no card catalog / suggestion endpoint yet.
  @override
  Future<List<CreditCard>> cardCatalog() async => const [];

  static const _accountGradients = [
    [Color(0xFF1B2433), Color(0xFF2E3B50)],
    [Color(0xFF173530), Color(0xFF285A50)],
    [Color(0xFF38332D), Color(0xFF575047)],
  ];

  /// Non-card accounts with their anchored balance. Month in/out comes from
  /// this month's transactions on the account.
  @override
  Future<List<BankAccount>> bankAccounts() async {
    final (accounts, txs) = await (_accounts(), transactions()).wait;
    final now = DateTime.now();
    final list = accounts.values.where((a) => !a.isCreditCard).toList();
    return [
      for (final (i, a) in list.indexed)
        () {
          var inflow = 0.0, outflow = 0.0;
          for (final t in txs) {
            if (t.accountLabel != a.label) continue;
            if (t.date.year != now.year || t.date.month != now.month) continue;
            if (t.isIncome) {
              inflow += t.amount;
            } else {
              outflow += t.amount;
            }
          }
          return BankAccount(
            id: a.id,
            bank: a.institution ?? a.name,
            name: a.institution == null ? _kindOf(a.type).label : a.name,
            kind: _kindOf(a.type),
            last4: a.last4,
            balance: fromMinor(a.balanceAnchorMinor ?? 0),
            gradient: _accountGradients[i % _accountGradients.length],
            monthIn: inflow,
            monthOut: outflow,
            matchLabels: [a.label],
          );
        }(),
    ];
  }

  static BankAccountKind _kindOf(String type) => switch (type) {
    'wallet' => BankAccountKind.wallet,
    'cash' => BankAccountKind.cash,
    _ => BankAccountKind.current,
  };

  /// `/v1/rewards/best-card`, with user cards mapped back to their account
  /// through `/v1/rewards/summary`.
  @override
  Future<List<BestCardPick>> bestCard(
    SpendCategory category,
    double amount,
  ) async {
    final (json, summary) = await (
      _send('POST', '/v1/rewards/best-card', {
        'category': category.id,
        'amount_minor': toMinor(amount),
      }),
      _rewardsByAccount(),
    ).wait;
    final accountOf = {
      for (final e in summary.entries) e.value['user_card_id']: e.key,
    };
    double n(Object? v) => v == null ? 0 : double.parse('$v');
    return [
      for (final r in (json['ranked'] as List? ?? const []))
        () {
          final m = Map<String, Object?>.from(r as Map);
          return BestCardPick(
            cardId: accountOf[m['user_card_id']],
            name: (m['name'] as String?) ?? 'Card',
            ratePct: n(m['effective_rate_pct']),
            estimate: fromMinor(
              (m['estimated_value_minor'] as num?)?.toInt() ?? 0,
            ),
            hitsCap: m['hits_cap'] as bool? ?? false,
            verified: m['data_status'] == 'verified',
          );
        }(),
    ];
  }

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
    final (expenses, settlements) = await (
      Future.wait([
        for (final g in groups)
          _getList('/v1/splits/groups/${g.id}/expenses', query: {'limit': 100}),
      ]),
      Future.wait([
        for (final g in groups)
          _getList('/v1/splits/groups/${g.id}/settlements'),
      ]),
    ).wait;
    return [
      for (var i = 0; i < groups.length; i++)
        splitGroupToDomain(
          groups[i],
          expenses[i].map(SplitExpenseDto.fromJson).toList(),
          settlements: settlements[i].map(SettlementDto.fromJson).toList(),
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

  Future<String Function(String)> _memberResolver(String groupId) async {
    final (groupJson, me) = await (
      _getMap('/v1/splits/groups/$groupId'),
      _myUserId(),
    ).wait;
    final group = SplitGroupDto.fromJson(groupJson);
    return (String id) {
      if (id != 'me') return id;
      final mine = group.members.where((m) => m.userId == me);
      if (mine.isEmpty) {
        throw const ApiException(
          message: 'You are not a member of this group.',
          code: 'invalid_member',
        );
      }
      return mine.first.id;
    };
  }

  @override
  Future<Member> addMember(
    String groupId, {
    required String name,
    String? phone,
  }) async {
    final json = await _send('POST', '/v1/splits/groups/$groupId/members', {
      'display_name': name,
      'phone': ?phone,
    });
    final m = SplitMemberDto.fromJson(json);
    return Member(m.id, m.displayName, const Color(0xFF5BC2A8), phone: phone);
  }

  /// `POST /v1/contacts/match`: only SHA-256 hashes are sent.
  @override
  Future<Set<String>> matchContacts(List<String> phoneHashes) async {
    if (phoneHashes.isEmpty) return {};
    final out = <String>{};
    for (var i = 0; i < phoneHashes.length; i += 1000) {
      final chunk = phoneHashes.sublist(
        i,
        (i + 1000).clamp(0, phoneHashes.length),
      );
      final j = await _send('POST', '/v1/contacts/match', {'hashes': chunk});
      for (final m in (j['matches'] as List? ?? const [])) {
        out.add((m as Map)['phone_hash'] as String);
      }
    }
    return out;
  }

  @override
  Future<SettlementRecord> markSettlementPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  }) async {
    // An Aani settlement starts pending; mark-paid records the payer's
    // claim and the payee confirms.
    final resolve = await _memberResolver(groupId);
    final created = await _send(
      'POST',
      '/v1/splits/groups/$groupId/settlements',
      {
        'from_member_id': resolve(from),
        'to_member_id': resolve(to),
        'amount_minor': toMinor(amount),
        'method': 'aani',
      },
    );
    final id = created['id']! as String;
    final json = await _send(
      'POST',
      '/v1/splits/groups/$groupId/settlements/$id/mark-paid',
      {},
    );
    return SettlementDto.fromJson(json).toDomain((id) => id);
  }

  @override
  Future<SettlementRecord> confirmSettlement(
    String groupId,
    String settlementId,
  ) async {
    final json = await _send(
      'POST',
      '/v1/splits/groups/$groupId/settlements/$settlementId/confirm',
      {},
    );
    return SettlementDto.fromJson(json).toDomain((id) => id);
  }

  // ---- monthly close -----------------------------------------------------------

  @override
  Future<List<Statement>> statements() async {
    final (json, accounts) = await (
      _getList('/v1/statements', query: {'limit': 100}),
      _accounts(),
    ).wait;
    return [for (final j in json) StatementDto.toDomain(j, accounts: accounts)];
  }

  @override
  Future<Reconciliation> reconciliation(String statementId) async =>
      StatementDto.reconciliation(
        await _getMap('/v1/statements/$statementId/reconciliation'),
      );

  @override
  Future<UploadResult> uploadStatement({
    required Uint8List bytes,
    required String filename,
    String? institution,
  }) => guardApi(() async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'institution': ?institution,
    });
    final res = await _dio.post<Map<String, Object?>>(
      '/v1/statements/upload',
      data: form,
    );
    final j = res.data!;
    return UploadResult(
      id: j['id']! as String,
      duplicate: (j['duplicate'] as bool?) ?? false,
    );
  });

  @override
  Future<void> reprocessStatement(String statementId) =>
      _send('POST', '/v1/statements/$statementId/reprocess', {});

  @override
  Future<List<StatementPassword>> statementPasswords() async => [
    for (final j in await _getList('/v1/statement-passwords'))
      StatementPassword(
        j['institution']! as String,
        DateTime.parse(j['updated_at']! as String),
      ),
  ];

  /// PUT upserts; the password is never returned by the server.
  @override
  Future<void> setStatementPassword(String institution, String password) =>
      _send('PUT', '/v1/statement-passwords', {
        'institution': institution,
        'password': password,
      });

  @override
  Future<Uri?> startGmailConnect() async {
    final j = await _send('POST', '/v1/email-connections/gmail/start', {});
    return Uri.parse(j['authorization_url']! as String);
  }

  @override
  Future<List<EmailConnection>> emailConnections() async => [
    for (final j in await _getList('/v1/email-connections'))
      EmailConnection(
        id: j['id']! as String,
        email: (j['email'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'active',
        lastSyncedAt: j['last_synced_at'] == null
            ? null
            : DateTime.parse(j['last_synced_at']! as String),
      ),
  ];

  // ---- insights ----------------------------------------------------------------
  //
  // TODO(api): `/v1/insights/*`, `/v1/rewards/*` and `/v1/cards/due-dates` are
  // planned; until they exist these are derived on the device from
  // transactions, budgets, accounts and assets.

  Future<double> _cash() async => (await assets())
      .where((a) => a.kind == AssetKind.cash)
      .fold<double>(0, (a, e) => a + e.value);

  @override
  Future<Cashflow> cashflow() async {
    final now = _clock();
    final (txs, cards, cash) = await (
      _allTx(from: DateTime(now.year, now.month - 5)),
      myCards(),
      _cash(),
    ).wait;
    final (accounts, categories) = await (_accounts(), _categories()).wait;
    final domain = [
      for (final t in txs)
        t.toDomain(accounts: accounts, categories: categories),
    ];
    final months = cashflowFromTransactions(domain, now: now);
    final end = DateTime(now.year, now.month + 1, 0);
    final committed = cards
        .where((c) => !c.dueDate.isAfter(end))
        .fold<double>(0, (a, c) => a + c.totalDue);
    return Cashflow(
      months: months,
      balanceNow: cash,
      committed: committed,
      projectedEndBalance: projectEndBalance(
        balanceNow: cash,
        spentSoFar: months.last.spend,
        dayOfMonth: now.day,
        daysInMonth: DateUtils.getDaysInMonth(now.year, now.month),
        committed: committed,
      ),
    );
  }

  @override
  Future<CategoryTrends> categoryTrends() async {
    final now = _clock();
    final (txs, accounts, categories) = await (
      _allTx(from: DateTime(now.year, now.month - 5)),
      _accounts(),
      _categories(),
    ).wait;
    final months = [
      for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i),
    ];
    final by = <SpendCategory, List<double>>{};
    for (final t in txs) {
      final d = t.toDomain(accounts: accounts, categories: categories);
      if (d.isIncome || d.excluded || d.category.isTransfer) continue;
      final i = months.indexWhere(
        (m) => m.year == d.date.year && m.month == d.date.month,
      );
      if (i < 0) continue;
      (by[d.category] ??= List.filled(6, 0.0))[i] += d.amount;
    }
    final series = [for (final e in by.entries) CategoryTrend(e.key, e.value)]
      ..sort((a, b) => b.values.last.compareTo(a.values.last));
    return CategoryTrends([
      for (final m in months) _months[m.month - 1],
    ], series.take(6).toList());
  }

  @override
  Future<SafeToSpend> safeToSpend() async {
    final now = _clock();
    final (budget, cards, cash) = await (
      budgetOverview(),
      myCards(),
      _cash(),
    ).wait;
    final end = DateTime(now.year, now.month + 1, 0);
    return computeSafeToSpend(
      cash: cash,
      budgetLeft: budget.remaining,
      bills: 0, // TODO(api): recurring bills are not modelled yet.
      cardDues: cards
          .where((c) => !c.dueDate.isAfter(end))
          .fold<double>(0, (a, c) => a + c.totalDue),
      goals: 0,
      daysLeft: budget.daysLeft,
    );
  }

  @override
  Future<HealthScore> healthScore() async {
    final (flow, cards) = await (cashflow(), myCards()).wait;
    final full = flow.months.length > 1
        ? flow.months[flow.months.length - 2]
        : flow.months.last;
    final limits = cards.fold<double>(0, (a, c) => a + c.limit);
    final balances = cards.fold<double>(0, (a, c) => a + c.balance);
    final spends = [for (final m in flow.months) m.spend];
    final avg = spends.isEmpty
        ? 0
        : spends.reduce((a, b) => a + b) / spends.length;
    return computeHealthScore(
      savingsRate: full.savingsRate,
      utilisation: limits == 0 ? 0 : balances / limits,
      onTimeRate: 1, // TODO(api): payment history per card.
      runwayMonths: avg == 0 ? 0 : flow.balanceNow / avg,
    );
  }

  @override
  Future<Transaction> simulateCapture() => Future.error(
    const ApiException(
      message: 'Capture simulation is only available with demo data.',
      code: 'not_supported',
    ),
  );

  // ---- family --------------------------------------------------------------------
  //
  // TODO(api): households are not in the backend yet; only you are shown.

  @override
  Future<Household> household() async {
    final b = await budgetOverview();
    return Household('Household', [
      FamilyMember(
        id: 'me',
        name: 'You',
        relation: 'You',
        sharing: SharingLevel.totals,
        isYou: true,
        spent: b.spent,
        budget: b.planned,
      ),
    ]);
  }

  @override
  Future<FamilyMember> inviteFamilyMember({
    required String name,
    required String phone,
    required String relation,
  }) => Future.error(
    const ApiException(
      message: 'Family invitations need the next server update.',
      code: 'not_supported',
    ),
  );

  @override
  Future<void> setSharing(String memberId, SharingLevel level) => Future.error(
    const ApiException(
      message: 'Sharing settings need the next server update.',
      code: 'not_supported',
    ),
  );
}
