import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:material_ui/material_ui.dart';

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
  }) async {
    final json = await _send('POST', '/v1/categories', {
      'name': name.trim(),
      'kind': kind.name,
    });
    final dto = CategoryDto.fromJson(json);
    return SpendCategory.custom(dto.id, dto.name, kind: dto.categoryKind);
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
        'month': DateTime(now.year, now.month).toIso8601String().substring(0, 10),
        'limit_minor': toMinor(monthly),
        'currency': 'AED',
      });
    }
  }

  // ---- automations -----------------------------------------------------------

  /// The backend stores merchant -> category rules (`/v1/merchant-rules`).
  @override
  Future<List<AutomationRule>> rules() async {
    final (json, categories) = await (
      _getList('/v1/merchant-rules'),
      _categories(),
    ).wait;
    return [
      for (final r in json) MerchantRuleDto.fromJson(r).toDomain(categories),
    ];
  }

  @override
  Future<AutomationRule> saveRule(AutomationRule rule) async {
    // TODO(api): description / amount / account conditions, rename and
    // exclude actions need the rules endpoint; only merchant -> category
    // exists today.
    if (!rule.isMerchantCategoryRule) {
      throw const ApiException(
        message:
            'Only "merchant is ... → category" rules are supported by the server so far.',
        code: 'rule_unsupported',
      );
    }
    final categories = await _categories();
    final target = _categoryFor(rule.category!, categories.values);
    if (target == null) {
      throw ApiException(
        message: 'No "${rule.category!.label}" category exists on the server.',
        code: 'category_unavailable',
      );
    }
    final json = await _send('POST', '/v1/merchant-rules', {
      'merchant': rule.value.trim(),
      'category_id': target.id,
      'apply_to_existing': true,
    });
    return MerchantRuleDto.fromJson(json).toDomain(categories);
  }

  @override
  Future<void> deleteRule(String id) => _delete('/v1/merchant-rules/$id');

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
    final (expenses, settlements) = await (
      Future.wait([
        for (final g in groups)
          _getList('/v1/splits/groups/${g.id}/expenses', query: {'limit': 100}),
      ]),
      Future.wait([
        for (final g in groups) _getList('/v1/splits/groups/${g.id}/settlements'),
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
    // TODO(api): the members endpoint has no phone field yet; the number
    // stays on the device.
    final json = await _send('POST', '/v1/splits/groups/$groupId/members', {
      'display_name': name,
    });
    final m = SplitMemberDto.fromJson(json);
    return Member(m.id, m.displayName, const Color(0xFF5BC2A8), phone: phone);
  }

  /// TODO(api): `POST /v1/contacts/match {hashes}` is not built yet, so no
  /// contact is shown as "on Pulse" against the real backend.
  @override
  Future<Set<String>> matchContacts(List<String> phoneHashes) async => {};

  @override
  Future<SettlementRecord> markSettlementPaid(
    String groupId, {
    required String from,
    required String to,
    required double amount,
  }) async {
    final resolve = await _memberResolver(groupId);
    final json = await _send(
      'POST',
      '/v1/splits/groups/$groupId/settlements',
      {
        'from_member_id': resolve(from),
        'to_member_id': resolve(to),
        'amount_minor': toMinor(amount),
        'note': aaniPendingNote,
      },
    );
    return SettlementDto.fromJson(json).toDomain((id) => id).copyWith(
      status: SettlementStatus.awaitingConfirmation,
    );
  }

  /// TODO(api): settlements cannot be updated yet; confirmation needs the
  /// Aani settlement endpoints.
  @override
  Future<SettlementRecord> confirmSettlement(
    String groupId,
    String settlementId,
  ) => Future.error(
    const ApiException(
      message: 'Confirming a payment needs the next server update.',
      code: 'not_supported',
    ),
  );

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
}
