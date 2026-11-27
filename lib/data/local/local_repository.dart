import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:material_ui/material_ui.dart' show Color, DateUtils;

import '../../core/engine/card_art.dart';
import '../../core/engine/catalog.dart' show CatalogCard;
import '../../core/engine/dates.dart';
import '../../core/engine/dues.dart' show nextDueFromDay;
import '../../core/engine/goals.dart';
import '../goal_service.dart';
import 'goal_store.dart';
import '../../core/engine/merchants.dart';
import '../../core/engine/networth.dart';
import '../../core/engine/nw_history.dart';
import '../../core/engine/recategorise.dart';
import '../../core/engine/review.dart';
import '../../core/engine/recurring.dart' as recurring;
import '../../core/engine/rewards.dart';
import '../../core/engine/rule_engine.dart' as eng;
import '../../core/engine/types.dart' show Direction, TxnSource;
import '../api/api_exception.dart';
import '../../core/network/cloud_access.dart';
import '../api/dto.dart';
import '../cap_snapshot.dart';
import '../insights.dart';
import '../models.dart';
import '../wealth_service.dart';
import '../../core/engine/prices.dart';
import '../recategoriser.dart';
import '../repository.dart';
import '../rules.dart';
import '../statements.dart';
import '../../core/engine/card_value.dart';
import 'card_cycles.dart';
import 'card_value_report.dart';
import 'catalog_service.dart';
import 'database.dart';
import 'ids.dart';
import 'ingest_pipeline.dart';
import 'splits_store.dart';
import '../digit_suggestion.dart';
import 'statement_service.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

const _cardGradients = [
  [Color(0xFF0B1F4B), Color(0xFF1E3A8A), Color(0xFFB91C1C)],
  [Color(0xFF111827), Color(0xFF374151), Color(0xFF0EA5E9)],
  [Color(0xFF3B0764), Color(0xFF7C3AED), Color(0xFFEC4899)],
  [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF22D3EE)],
];
const _accountGradients = [
  [Color(0xFF1B2433), Color(0xFF2E3B50)],
  [Color(0xFF173530), Color(0xFF285A50)],
  [Color(0xFF38332D), Color(0xFF575047)],
];

double _aed(int minor) => minor / 100;

String _monthKey(int year, int month) => '$year-${month.toString().padLeft(2, '0')}-01';

/// The on-device data source. Everything personal is computed here from the
/// encrypted database; nothing leaves the phone. Features that need a server
/// (splits with other people, family sharing, statement parsing, Gmail) go
/// to [shared] when a backend is configured and report "not supported"
/// otherwise.
class LocalPulseRepository implements PulseRepository, Recategoriser, NetWorthHistorySource, CapSource {
  LocalPulseRepository({
    required this.db,
    required this.catalog,
    required this.pipeline,
    this.shared,
    this.wealth,
    this.statementService,
    DateTime Function()? clock,
    bool Function()? cloudReady,
  }) : _clock = clock ?? DateTime.now,
       _cloudReady = cloudReady ?? (() => currentCloudAccess().isReady);

  /// Statement PDFs read on this device; without it uploads need the server.
  final LocalStatementService? statementService;

  late final LocalSplitsStore _splits = LocalSplitsStore(db, clock: _clock);

  /// Jewellery, funds and prices (optional so older call sites still work).
  final WealthService? wealth;

  final PulseDatabase db;
  final CatalogService catalog;
  final IngestPipeline pipeline;
  final PulseRepository? shared;
  final DateTime Function() _clock;

  /// Whether a Pulse sign-in exists for the backend (overridden in tests).
  final bool Function() _cloudReady;

  CalDate get _today => toDubaiDate(_clock());

  // ---- loading helpers -------------------------------------------------------

  Future<Map<String, AccountRow>> _accountMap() async => {
    for (final a in await db.select(db.accounts).get()) a.id: a,
  };

  Future<Map<String, CategoryRow>> _categoryMap() async => {
    for (final c in await db.select(db.categories).get()) c.id: c,
  };

  static String _label(AccountRow a) {
    final base = (a.institution?.isNotEmpty ?? false) ? a.institution! : a.name;
    return a.last4 == null ? base : '$base ••${a.last4}';
  }

  static CategoryKind _kind(String k) => switch (k) {
    'income' => CategoryKind.income,
    'transfer' => CategoryKind.transfer,
    _ => CategoryKind.expense,
  };

  static SpendCategory _spendCategory(CategoryRow? c, {bool income = false}) {
    if (c == null) return income ? SpendCategory.income : SpendCategory.other;
    final known = SpendCategory.byId(c.id);
    if (known != null) return known;
    if (c.id == 'other_income') return SpendCategory.income;
    if (c.id == 'transfer') return SpendCategory.cardPayments;
    return SpendCategory.custom(c.id, c.name, kind: _kind(c.kind), iconKey: c.iconKey);
  }

  Transaction _toTx(TxRow t, Map<String, AccountRow> accounts, Map<String, CategoryRow> cats) {
    final income = t.direction == 'credit';
    final acct = accounts[t.accountId];
    final norm = t.merchantNormalized?.trim() ?? '';
    final raw = t.merchantRaw?.trim() ?? '';
    return Transaction(
      id: t.id,
      merchant: norm.isNotEmpty ? norm : (raw.isNotEmpty ? raw : 'Unknown merchant'),
      amount: _aed(t.amountMinor),
      category: _spendCategory(cats[t.categoryId], income: income),
      rawDescription: raw.isNotEmpty ? raw : null,
      date: t.postedAt,
      source: txSourceFor(t.source),
      cardId: t.accountId,
      accountLabel: acct == null ? 'Account' : _label(acct),
      isIncome: income,
      excluded: t.excludeFromBudget,
      pendingHold: t.tags.contains('pending_hold'),
      reviewed: t.reviewed,
      receiptNotes: t.receiptNotes,
      note: t.notes,
      receiptRef: t.receiptRef,
      confidence: categoryConfidence(
        hasCategory: t.categoryId != null,
        isOther: t.categoryId == 'other',
        ruleApplied: t.appliedRuleId != null,
        fromStatement: t.statementLocked,
        learned: t.tags.contains('"${eng.learnedTag}"'),
      ),
      learned: t.tags.contains('"${eng.learnedTag}"'),
    );
  }

  @override
  Future<void> setReviewed(Iterable<String> txIds, bool reviewed) async {
    final ids = txIds.toList();
    if (ids.isEmpty) return;
    await (db.update(db.transactions)..where((t) => t.id.isIn(ids))).write(
      TransactionsCompanion(reviewed: Value(reviewed)),
    );
  }

  Future<List<TxRow>> _txRows({DateTime? since}) async {
    await _planSalary();
    return _txRowsQuery(since: since);
  }

  Future<List<TxRow>> _txRowsQuery({DateTime? since}) => (db.select(db.transactions)
        ..where((t) => t.deletedAt.isNull() & (since == null ? const Constant(true) : t.postedAt.isBiggerOrEqualValue(since)))
        ..orderBy([(t) => OrderingTerm.desc(t.postedAt), (t) => OrderingTerm.desc(t.id)]))
      .get();

  Future<Transaction> _txById(String id) async {
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(id))).getSingle();
    return _toTx(row, await _accountMap(), await _categoryMap());
  }

  /// Row id of the category the UI picked.
  Future<String> _categoryId(SpendCategory c) async {
    final row = await (db.select(db.categories)..where((t) => t.id.equals(c.id))).getSingleOrNull();
    if (row != null) return row.id;
    throw ApiException(message: 'No "${c.label}" category exists.', code: 'category_unavailable');
  }

  // ---- transactions ------------------------------------------------------------

  @override
  Future<List<Transaction>> transactions() async {
    final (rows, accounts, cats) = await (_txRows(), _accountMap(), _categoryMap()).wait;
    return [for (final t in rows) _toTx(t, accounts, cats)];
  }

  @override
  Future<TxPage> transactionsPage({String? cursor, int limit = 50}) async {
    if (cursor == null) await _planSalary();
    final q = db.select(db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.postedAt), (t) => OrderingTerm.desc(t.id)])
      ..limit(limit + 1);
    if (cursor != null) {
      final i = cursor.indexOf('|');
      final at = DateTime.fromMillisecondsSinceEpoch(int.parse(cursor.substring(0, i)), isUtc: true);
      final id = cursor.substring(i + 1);
      q.where((t) => t.postedAt.isSmallerThanValue(at) | (t.postedAt.equals(at) & t.id.isSmallerThanValue(id)));
    }
    final (rows, accounts, cats) = await (q.get(), _accountMap(), _categoryMap()).wait;
    final page = rows.take(limit).toList();
    final next = rows.length > limit ? '${page.last.postedAt.toUtc().millisecondsSinceEpoch}|${page.last.id}' : null;
    return TxPage([for (final t in page) _toTx(t, accounts, cats)], nextCursor: next);
  }

  @override
  Future<Transaction> recategorise(String txId, SpendCategory category, {bool remember = false}) async {
    final catId = await _categoryId(category);
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
    await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(
      TransactionsCompanion(categoryId: Value(catId), reviewed: const Value(true)),
    );
    if (remember) {
      final key = merchantKey(row.merchantNormalized ?? row.merchantRaw);
      if (key != null) {
        final existing = await (db.select(db.merchantRules)..where((r) => r.merchantKey.equals(key))).getSingleOrNull();
        final conditions = jsonEncode([
          {'field': 'merchant', 'op': 'equals', 'value': key},
        ]);
        if (existing != null) {
          await (db.update(db.merchantRules)..where((r) => r.id.equals(existing.id))).write(
            MerchantRulesCompanion(categoryId: Value(catId), conditions: Value(conditions)),
          );
        } else {
          await db.into(db.merchantRules).insert(
            MerchantRulesCompanion.insert(
              id: newId(),
              merchantKey: Value(key),
              name: Value('${row.merchantNormalized ?? row.merchantRaw} is ${category.label}'),
              priority: const Value(1000),
              conditions: Value(conditions),
              categoryId: Value(catId),
            ),
          );
        }
      }
    }
    return _txById(txId);
  }

  // ---- scoped re-categorise ----------------------------------------------------------

  RecatRow _recatRow(TxRow t) => RecatRow(
    id: t.id,
    categoryId: t.categoryId,
    merchantRaw: t.merchantRaw,
    merchantNormalized: t.merchantNormalized,
    direction: Direction.tryParse(t.direction),
  );

  @override
  Future<RecatPreview?> previewRecategorise(String txId, SpendCategory to) async {
    final row = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
    if (row == null) return null;
    final key = recategoriseKey(normalized: row.merchantNormalized, raw: row.merchantRaw, direction: Direction.tryParse(row.direction));
    if (key == null) return null;
    final plan = planRecategorise(
      key: key,
      targetCategoryId: await _categoryId(to),
      rows: [for (final t in await _txRows()) _recatRow(t)],
      excludeId: txId,
    );
    return RecatPreview(merchant: row.merchantNormalized ?? normalizeMerchant(row.merchantRaw) ?? key, pastCount: plan.pastCount);
  }

  @override
  Future<RecatUndo> recategoriseScoped(String txId, SpendCategory to, RecategoriseScope scope) async {
    final catId = await _categoryId(to);
    return db.transaction(() async {
      final row = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingle();
      await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(TransactionsCompanion(categoryId: Value(catId), reviewed: const Value(true)));
      final key = recategoriseKey(normalized: row.merchantNormalized, raw: row.merchantRaw, direction: Direction.tryParse(row.direction));
      if (scope == RecategoriseScope.once || key == null) {
        return RecatUndo(txId: txId, txCategoryId: row.categoryId);
      }
      final label = row.merchantNormalized ?? normalizeMerchant(row.merchantRaw) ?? key;
      final conditions = jsonEncode([
        {'field': 'merchant', 'op': 'equals', 'value': key},
      ]);
      final existing = await (db.select(db.merchantRules)..where((r) => r.merchantKey.equals(key))).getSingleOrNull();
      String ruleId;
      Map<String, Object?>? replaced;
      if (existing != null) {
        ruleId = existing.id;
        replaced = {
          'category_id': existing.categoryId,
          'conditions': existing.conditions,
          'name': existing.name,
          'is_active': existing.isActive,
        };
        await (db.update(db.merchantRules)..where((r) => r.id.equals(existing.id))).write(
          MerchantRulesCompanion(categoryId: Value(catId), conditions: Value(conditions), isActive: const Value(true)),
        );
      } else {
        ruleId = newId();
        await db.into(db.merchantRules).insert(
          MerchantRulesCompanion.insert(
            id: ruleId,
            merchantKey: Value(key),
            name: Value('$label is ${to.label}'),
            priority: const Value(1000),
            conditions: Value(conditions),
            categoryId: Value(catId),
          ),
        );
      }
      final before = <String, (String?, String?)>{};
      if (scope == RecategoriseScope.all) {
        final rows = await _txRows();
        final plan = planRecategorise(key: key, targetCategoryId: catId, rows: [for (final t in rows) _recatRow(t)], excludeId: txId);
        final byId = {for (final t in rows) t.id: t};
        for (final id in plan.pastIds) {
          before[id] = (byId[id]!.categoryId, byId[id]!.appliedRuleId);
          await (db.update(db.transactions)..where((t) => t.id.equals(id))).write(
            TransactionsCompanion(categoryId: Value(catId), appliedRuleId: Value(ruleId)),
          );
        }
      }
      return RecatUndo(
        txId: txId,
        txCategoryId: row.categoryId,
        createdRuleId: replaced == null ? ruleId : null,
        replacedRule: replaced == null ? null : {'id': ruleId, ...replaced},
        pastBefore: before,
      );
    });
  }

  @override
  Future<void> undoRecategorise(RecatUndo undo) => db.transaction(() async {
    for (final e in undo.pastBefore.entries) {
      await (db.update(db.transactions)..where((t) => t.id.equals(e.key))).write(
        TransactionsCompanion(categoryId: Value(e.value.$1), appliedRuleId: Value(e.value.$2)),
      );
    }
    await (db.update(db.transactions)..where((t) => t.id.equals(undo.txId))).write(
      TransactionsCompanion(categoryId: Value(undo.txCategoryId)),
    );
    final created = undo.createdRuleId;
    if (created != null) {
      await (db.update(db.transactions)..where((t) => t.appliedRuleId.equals(created))).write(
        const TransactionsCompanion(appliedRuleId: Value(null)),
      );
      await (db.delete(db.merchantRules)..where((r) => r.id.equals(created))).go();
    }
    final old = undo.replacedRule;
    if (old != null) {
      await (db.update(db.merchantRules)..where((r) => r.id.equals(old['id']! as String))).write(
        MerchantRulesCompanion(
          categoryId: Value(old['category_id'] as String?),
          conditions: Value(old['conditions']! as String),
          name: Value(old['name'] as String?),
          isActive: Value(old['is_active'] as bool),
        ),
      );
    }
  });

  Future<AccountRow> _cashAccount() async {
    final existing = await (db.select(db.accounts)
          ..where((a) => a.type.equals('cash') & a.deletedAt.isNull())
          ..limit(1))
        .getSingleOrNull();
    if (existing != null) return existing;
    final id = newId();
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: id,
        type: 'cash',
        name: 'Cash',
        // No anchor: every transaction on the pot counts.
        balanceAnchorMinor: const Value(0),
      ),
    );
    return (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();
  }

  @override
  Future<Transaction> addManualTransaction({
    required String merchant,
    required double amount,
    required SpendCategory category,
    DateTime? date,
    String? note,
  }) async {
    final acct = await _cashAccount();
    final catId = await _categoryId(category);
    final id = newId();
    final name = merchant.trim();
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        accountId: acct.id,
        amountMinor: (amount.abs() * 100).round(),
        direction: category.isIncome ? 'credit' : 'debit',
        categoryId: Value(catId),
        merchantRaw: Value(name),
        merchantNormalized: Value(name),
        notes: Value(note == null || note.trim().isEmpty ? null : note.trim()),
        postedAt: (date ?? _clock()).toUtc(),
        source: 'manual',
        sources: const Value('["manual"]'),
        reviewed: const Value(true),
      ),
    );
    return _txById(id);
  }

  @override
  Future<void> setTransactionNote(String txId, String? note) async {
    final n = note?.trim();
    await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(
      TransactionsCompanion(notes: Value(n == null || n.isEmpty ? null : n)),
    );
  }

  @override
  Future<void> deleteTransaction(String txId) async {
    await (db.update(db.transactions)..where((t) => t.id.equals(txId))).write(
      TransactionsCompanion(deletedAt: Value(_clock().toUtc())),
    );
  }

  // ---- manual salary ------------------------------------------------------

  static const _salaryKey = 'salary.manual';

  @override
  Future<ManualSalary?> manualSalary() async {
    final raw = await db.setting(_salaryKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map;
      final a = m['amountMinor'] as int, d = m['day'] as int;
      return a > 0 && d >= 1 && d <= 31 ? ManualSalary(amountMinor: a, day: d) : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> setManualSalary(ManualSalary? salary) async {
    await db.putSetting(
      _salaryKey,
      salary == null ? '' : jsonEncode({'amountMinor': salary.amountMinor, 'day': salary.day}),
    );
    await _planSalary();
  }

  /// Keeps this month's salary credit in step with the salary you entered:
  /// a planned credit appears on payday, and gives way to the real one the
  /// moment a salary credit is detected (which also updates the amount).
  Future<void> _planSalary() async {
    final s = await manualSalary();
    final today = _today;
    final monthStart = DateTime.utc(today.year, today.month, 1).subtract(const Duration(hours: 4));
    final planId = 'salary-plan-${today.year}-${today.month.toString().padLeft(2, '0')}';
    final plan = await (db.select(db.transactions)..where((t) => t.id.equals(planId))).getSingleOrNull();
    if (s == null) {
      if (plan != null && plan.deletedAt == null) await deleteTransaction(planId);
      return;
    }
    final real = await (db.select(db.transactions)
          ..where((t) =>
              t.categoryId.equals('salary') &
              t.direction.equals('credit') &
              t.deletedAt.isNull() &
              t.postedAt.isBiggerOrEqualValue(monthStart) &
              t.id.equals(planId).not())
          ..limit(1))
        .getSingleOrNull();
    if (real != null) {
      if (plan != null && plan.deletedAt == null) await deleteTransaction(planId);
      if (real.amountMinor != s.amountMinor && real.amountMinor >= 50000 && real.currency == 'AED') {
        await db.putSetting(_salaryKey, jsonEncode({'amountMinor': real.amountMinor, 'day': s.day}));
      }
      return;
    }
    if (plan != null) return;
    final day = math.min(s.day, DateUtils.getDaysInMonth(today.year, today.month));
    if (today.day < day) return;
    final acct = await _cashAccount();
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: planId,
        accountId: acct.id,
        amountMinor: s.amountMinor,
        direction: 'credit',
        categoryId: Value(await _categoryId(SpendCategory.salary)),
        merchantRaw: const Value('Salary'),
        merchantNormalized: const Value('Salary'),
        notes: const Value('Added from the salary you entered. Replaced when the real credit arrives.'),
        postedAt: DateTime.utc(today.year, today.month, day, 4),
        source: 'manual',
        sources: const Value('["salary_plan"]'),
        reviewed: const Value(true),
      ),
    );
  }

  @override
  Future<int> importTransactions(List<ImportedTransaction> txs) async {
    if (txs.isEmpty) return 0;
    final acct = await _cashAccount();
    String key(DateTime d, int minor, String name, String cat) => '${d.year}-${d.month}-${d.day}|$minor|${name.toLowerCase()}|$cat';
    final existing = <String>{
      for (final r in await (db.select(db.transactions)..where((t) => t.sources.equals('["import"]'))).get())
        key(r.postedAt.toLocal(), r.amountMinor, r.merchantRaw ?? '', r.categoryId ?? ''),
    };
    var added = 0;
    await db.transaction(() async {
      for (final t in txs) {
        if (t.amountMinor <= 0) continue;
        final catId = await _categoryId(t.category);
        final name = t.merchant.trim().isEmpty ? t.category.label : t.merchant.trim();
        final k = key(t.date, t.amountMinor, name, catId);
        if (!existing.add(k)) continue;
        await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: newId(),
            accountId: acct.id,
            amountMinor: t.amountMinor,
            direction: t.isIncome ? 'credit' : 'debit',
            categoryId: Value(catId),
            merchantRaw: Value(name),
            merchantNormalized: Value(name),
            postedAt: DateTime(t.date.year, t.date.month, t.date.day, 12).toUtc(),
            source: 'manual',
            sources: const Value('["import"]'),
            reviewed: const Value(true),
          ),
        );
        added++;
      }
    });
    return added;
  }

  // ---- categories & budgets ------------------------------------------------------

  @override
  Future<List<SpendCategory>> categories() async {
    final rows = await (db.select(db.categories)..where((c) => c.isHidden.equals(false) & c.isCustom.equals(true))).get();
    return [
      ...SpendCategory.defaults,
      for (final r in rows) SpendCategory.custom(r.id, r.name, kind: _kind(r.kind), iconKey: r.iconKey),
    ];
  }

  @override
  Future<SpendCategory> createCategory({required String name, CategoryKind kind = CategoryKind.expense, String? iconKey}) async {
    final id = newId('c_');
    await db.into(db.categories).insert(
      CategoriesCompanion.insert(
        id: id,
        name: name.trim(),
        kind: Value(kind.name),
        isCustom: const Value(true),
        sortOrder: const Value(1000),
        iconKey: Value(iconKey),
      ),
    );
    return SpendCategory.custom(id, name.trim(), kind: kind, iconKey: iconKey);
  }

  @override
  Future<SpendCategory> setCategoryIcon(SpendCategory category, String iconKey) async {
    if (!category.custom) return category;
    await (db.update(db.categories)..where((c) => c.id.equals(category.id) & c.isCustom.equals(true))).write(
      CategoriesCompanion(iconKey: Value(iconKey)),
    );
    return SpendCategory.custom(category.id, category.label, kind: category.kind, iconKey: iconKey);
  }

  /// Limit per category in force for [month] (`yyyy-MM-01`): the latest
  /// budget row at or before it. 0 means "no budget".
  Map<String, int> _effectiveBudgets(List<BudgetRow> all, String month) {
    final best = <String, BudgetRow>{};
    for (final b in all) {
      if (b.month.compareTo(month) > 0) continue;
      final cur = best[b.categoryId];
      if (cur == null || b.month.compareTo(cur.month) > 0) best[b.categoryId] = b;
    }
    return {
      for (final e in best.entries)
        if (e.value.limitMinor > 0) e.key: e.value.limitMinor,
    };
  }

  bool _countsAsSpend(TxRow t, Map<String, CategoryRow> cats) {
    if (t.direction != 'debit' || t.excludeFromBudget || t.currency != 'AED') return false;
    final kind = cats[t.categoryId]?.kind ?? 'expense';
    return kind == 'expense';
  }

  @override
  Future<BudgetOverview> budgetOverview() async {
    final today = _today;
    final dim = daysInMonth(today.year, today.month);
    final since = DateTime.utc(today.year, today.month - 5, 1).subtract(const Duration(days: 1));
    final (rows, accounts, cats, budgets) = await (
      _txRows(since: since),
      _accountMap(),
      _categoryMap(),
      db.select(db.budgets).get(),
    ).wait;
    final thisMonth = [
      for (final t in rows)
        if (toDubaiDate(t.postedAt).year == today.year && toDubaiDate(t.postedAt).month == today.month) t,
    ];
    final spend = [for (final t in thisMonth) if (_countsAsSpend(t, cats)) t];
    final spentByCat = <String, int>{};
    for (final t in spend) {
      final k = t.categoryId ?? 'other';
      spentByCat[k] = (spentByCat[k] ?? 0) + t.amountMinor;
    }
    final limits = _effectiveBudgets(budgets, _monthKey(today.year, today.month));
    final lines = [
      for (final e in limits.entries)
        BudgetLine(
          category: _spendCategory(cats[e.key]),
          planned: _aed(e.value),
          spent: _aed(spentByCat[e.key] ?? 0),
        ),
    ]..sort((a, b) => b.spent.compareTo(a.spent));
    final planned = limits.values.fold<int>(0, (a, b) => a + b);
    final spent = spend.fold<int>(0, (a, t) => a + t.amountMinor);

    final trend = <MonthlyTotal>[];
    for (var i = 5; i >= 0; i--) {
      final idx = today.year * 12 + today.month - 1 - i;
      final y = idx ~/ 12, m = idx % 12 + 1;
      var s = 0;
      for (final t in rows) {
        final d = toDubaiDate(t.postedAt);
        if (d.year == y && d.month == m && _countsAsSpend(t, cats)) s += t.amountMinor;
      }
      final p = _effectiveBudgets(budgets, _monthKey(y, m)).values.fold<int>(0, (a, b) => a + b);
      trend.add(MonthlyTotal(_months[m - 1], _aed(s), _aed(p)));
    }

    final byMerchant = <String, (SpendCategory, int, int)>{};
    final byCard = <String, double>{}, byAccount = <String, double>{};
    for (final t in spend) {
      final tx = _toTx(t, accounts, cats);
      final cur = byMerchant[tx.merchant];
      byMerchant[tx.merchant] = (cur?.$1 ?? tx.category, (cur?.$2 ?? 0) + t.amountMinor, (cur?.$3 ?? 0) + 1);
      final target = accounts[t.accountId]?.type == 'credit_card' ? byCard : byAccount;
      target[tx.accountLabel] = (target[tx.accountLabel] ?? 0) + tx.amount;
    }
    final merchants = [
      for (final e in byMerchant.entries) MerchantTotal(e.key, e.value.$1, _aed(e.value.$2), e.value.$3),
    ]..sort((a, b) => b.total.compareTo(a.total));

    return BudgetOverview(
      planned: _aed(planned),
      spent: _aed(spent),
      daysLeft: dim - today.day + 1,
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
  Future<void> setBudget(SpendCategory category, double monthly) async {
    final catId = await _categoryId(category);
    final today = _today;
    final month = _monthKey(today.year, today.month);
    final minor = monthly <= 0 ? 0 : (monthly * 100).round();
    final existing = await (db.select(db.budgets)..where((b) => b.categoryId.equals(catId) & b.month.equals(month))).getSingleOrNull();
    if (existing != null) {
      await (db.update(db.budgets)..where((b) => b.id.equals(existing.id))).write(BudgetsCompanion(limitMinor: Value(minor)));
    } else {
      if (minor == 0) {
        // Nothing in force to clear, unless an earlier month's budget carries over.
        final carried = _effectiveBudgets(await db.select(db.budgets).get(), month)[catId];
        if (carried == null) return;
      }
      await db.into(db.budgets).insert(BudgetsCompanion.insert(id: newId(), categoryId: catId, month: month, limitMinor: minor));
    }
  }

  // ---- automations -----------------------------------------------------------------

  Future<Map<String, AccountDto>> _accountDtos() async => {
    for (final a in (await db.select(db.accounts).get()).where((a) => a.deletedAt == null))
      a.id: AccountDto(id: a.id, type: a.type, name: a.name, institution: a.institution, last4: a.last4),
  };

  Future<Map<String, CategoryDto>> _categoryDtos() async => {
    for (final c in await db.select(db.categories).get())
      c.id: CategoryDto(id: c.id, name: c.name, kind: c.kind, slug: c.slug, userId: c.isCustom ? 'me' : null, isHidden: c.isHidden),
  };

  AutomationRule? _ruleFromRow(RuleRow r, Map<String, CategoryDto> cats, Map<String, AccountDto> accounts) => ruleFromJson(
    {
      'id': r.id,
      'conditions': jsonDecode(r.conditions),
      'category_id': r.categoryId,
      'rename_merchant': r.renameMerchant,
      'exclude_from_budget': r.excludeFromBudget,
      'mark_transfer': r.markTransfer,
      'is_active': r.isActive,
    },
    categories: cats,
    accounts: accounts,
  );

  @override
  Future<List<AutomationRule>> rules() async {
    final (rows, cats, accounts) = await (
      (db.select(db.merchantRules)..orderBy([(r) => OrderingTerm.asc(r.priority), (r) => OrderingTerm.asc(r.createdAt)])).get(),
      _categoryDtos(),
      _accountDtos(),
    ).wait;
    return [for (final r in rows) ?_ruleFromRow(r, cats, accounts)];
  }

  Future<Map<String, Object?>> _ruleBody(AutomationRule rule) async {
    final accounts = await _accountDtos();
    return ruleToJson(
      rule,
      categoryId: rule.category == null ? null : await _categoryId(rule.category!),
      accounts: accounts.values,
    );
  }

  eng.TxnFacts _facts(TxRow t) => eng.TxnFacts(
    merchantRaw: t.merchantRaw,
    merchantNormalized: t.merchantNormalized,
    notes: t.notes,
    amountMinor: t.amountMinor,
    direction: Direction.tryParse(t.direction),
    accountId: t.accountId,
    source: TxnSource.tryParse(t.source),
  );

  @override
  Future<RulePreviewSummary?> previewRule(AutomationRule rule) async {
    final body = await _ruleBody(rule);
    final compiled = eng.compileRule(
      [for (final c in body['conditions']! as List) Map<String, Object?>.from(c as Map)],
      categoryId: body['category_id'] as String?,
      renameMerchant: body['rename_merchant'] as String?,
      excludeFromBudget: body['exclude_from_budget'] == true,
    );
    final rows = await _txRows();
    final p = eng.previewRule(compiled, [for (final t in rows) (id: t.id, facts: _facts(t), categoryId: t.categoryId)]);
    return RulePreviewSummary(matched: p.matchedCount, wouldChange: p.wouldChangeIds.length);
  }

  @override
  Future<AutomationRule> saveRule(AutomationRule rule) async {
    final body = await _ruleBody(rule);
    final id = newId();
    await db.into(db.merchantRules).insert(
      MerchantRulesCompanion.insert(
        id: id,
        name: Value(body['name'] as String?),
        priority: const Value(100),
        isActive: Value(body['is_active'] != false),
        conditions: Value(jsonEncode(body['conditions'])),
        categoryId: Value(body['category_id'] as String?),
        renameMerchant: Value(body['rename_merchant'] as String?),
        excludeFromBudget: Value(body['exclude_from_budget'] == true),
      ),
    );
    final row = await (db.select(db.merchantRules)..where((r) => r.id.equals(id))).getSingle();
    if (row.isActive) await _applyRuleToHistory(row);
    return _ruleFromRow(row, await _categoryDtos(), await _accountDtos()) ?? rule.copyWith(id: id);
  }

  Future<void> _applyRuleToHistory(RuleRow row) async {
    final compiled = compileStoredRule(row);
    final rows = await _txRows();
    await db.transaction(() async {
      for (final t in rows) {
        if (!compiled.matches(_facts(t))) continue;
        await (db.update(db.transactions)..where((x) => x.id.equals(t.id))).write(
          TransactionsCompanion(
            categoryId: row.categoryId == null ? const Value.absent() : Value(row.categoryId),
            merchantNormalized: row.renameMerchant == null ? const Value.absent() : Value(row.renameMerchant),
            excludeFromBudget: row.excludeFromBudget ? const Value(true) : const Value.absent(),
            appliedRuleId: Value(row.id),
          ),
        );
      }
    });
  }

  @override
  Future<void> deleteRule(String id) async {
    await (db.update(db.transactions)..where((t) => t.appliedRuleId.equals(id))).write(
      const TransactionsCompanion(appliedRuleId: Value(null)),
    );
    await (db.delete(db.merchantRules)..where((r) => r.id.equals(id))).go();
  }

  // ---- cards -------------------------------------------------------------------------

  /// Amount owed on a card account: the anchored balance plus what was
  /// spent (less what was paid) since.
  Future<int> _owed(AccountRow a) async {
    final base = a.balanceAnchorMinor ?? 0;
    final after = await _netSince(a);
    return base - after;
  }

  /// Credits minus debits on [a] after its balance anchor (AED only).
  Future<int> _netSince(AccountRow a) async {
    final q = db.select(db.transactions)
      ..where((t) => t.accountId.equals(a.id) & t.deletedAt.isNull() & t.currency.equals('AED'));
    if (a.balanceAnchorAt != null) q.where((t) => t.postedAt.isBiggerThanValue(a.balanceAnchorAt!));
    var net = 0;
    for (final t in await q.get()) {
      net += t.direction == 'credit' ? t.amountMinor : -t.amountMinor;
    }
    return net;
  }

  static CardNetwork _network(String? n) => switch (n) {
    'mastercard' => CardNetwork.mastercard,
    'amex' => CardNetwork.amex,
    _ => CardNetwork.visa,
  };

  static double _pct(double rate, CardSpec s) => rate * s.pointValueAed * 100;

  static String _highlight(CardSpec s) {
    final best = [...s.rules]..sort((a, b) => b.rate.compareTo(a.rate));
    if (best.isEmpty) return 'Earns ${_pct(s.baseRate, s).toStringAsFixed(1)}% on everything';
    return '${_pct(best.first.rate, s).toStringAsFixed(1)}% on ${best.first.name.toLowerCase()}';
  }

  static CardArtSpec? _artOf(CatalogCardRow cat) {
    try {
      return CatalogCard.artFromPerks(
        Map<String, Object?>.from(jsonDecode(cat.perks) as Map),
      );
    } on Object {
      return null;
    }
  }

  CreditCard _cardModel({
    required String id,
    required String issuer,
    required String name,
    required String last4,
    required CatalogCardRow cat,
    required CardSpec spec,
    required int index,
    bool owned = true,
    double limit = 0,
    double balance = 0,
    DateTime? dueDate,
    DateTime? statementDate,
    CycleResult? cycle,
  }) {
    final rates = <SpendCategory, double>{};
    final caps = <SpendCategory, RewardCap>{};
    for (final r in spec.rules) {
      for (final slug in r.categories) {
        final c = SpendCategory.byId(slug);
        if (c == null) continue;
        final pct = _pct(r.rate, spec);
        if ((rates[c] ?? 0) < pct) rates[c] = pct;
        if (r.capUnits != null) {
          caps[c] = RewardCap(
            limit: r.capUnits! * spec.pointValueAed,
            used: (cycle?.usage[r.name]?.usedUnits ?? 0) * spec.pointValueAed,
          );
        }
      }
    }
    final earnedUnits = cycle?.earnedUnits ?? 0;
    return CreditCard(
      id: id,
      issuer: issuer,
      name: name,
      last4: last4,
      network: _network(cat.network),
      gradient: _cardGradients[index % _cardGradients.length],
      limit: limit,
      balance: balance,
      dueDate: dueDate ?? DateTime(_clock().year + 1, _clock().month, 1),
      hasDueDate: dueDate != null,
      minDue: 0,
      rewardsLabel: spec.isCashback ? 'Cashback this cycle' : 'Points this cycle',
      rewardPoints: spec.isCashback ? 0 : earnedUnits.round(),
      rewardValueAed: cycle == null ? 0 : _aed(cycle.earnedValueMinor(spec)),
      categoryRates: rates,
      annualFee: _aed(cat.annualFeeMinor),
      owned: owned,
      highlight: _highlight(spec),
      statementDate: statementDate,
      baseRate: _pct(spec.baseRate, spec),
      caps: caps,
      rulesVerifiedOn: cat.verifiedOn == null ? null : DateTime.tryParse(cat.verifiedOn!),
      catalogId: cat.id,
      art: _artOf(cat),
    );
  }

  Future<CreditCard> _ownedToModel(OwnedCard c) async {
    final today = _today;
    final cycle = await cycleState(db, c, today);
    final owed = await _owed(c.account);
    DateTime? due;
    if (c.account.dueDay != null && c.account.dueDay != 0) {
      final d = nextDueFromDay(today, c.account.dueDay!);
      due = DateTime(d.year, d.month, d.day);
    }
    DateTime? stmt;
    if (c.account.statementDay != null) {
      final d = cycleBounds(today, c.account.statementDay).$1.addDays(-1);
      stmt = DateTime(d.year, d.month, d.day);
    }
    return _cardModel(
      id: c.account.id,
      issuer: c.catalog.issuer,
      name: c.catalog.name,
      last4: c.account.last4 ?? '----',
      cat: c.catalog,
      spec: c.spec,
      index: c.user.colorIndex,
      limit: _aed(c.account.creditLimitMinor ?? 0),
      balance: owed < 0 ? 0 : _aed(owed),
      dueDate: due,
      statementDate: stmt,
      cycle: cycle,
    );
  }

  @override
  Future<CapSnapshot> capSnapshot() async {
    final today = _today;
    final cards = await loadOwnedCards(db);
    return CapSnapshot(
      today: today,
      cards: await capStatuses(db, cards, today),
      held: await rankables(db, cards, today),
      history: await spendHistory(db, today),
    );
  }

  @override
  Future<List<CreditCard>> myCards() async => [
    for (final c in await loadOwnedCards(db)) await _ownedToModel(c),
  ];

  @override
  Future<List<CreditCard>> cardCatalog() async {
    final rows = await db.select(db.catalogCards).get();
    final out = <CreditCard>[];
    for (final (i, r) in rows.indexed) {
      try {
        final spec = parseStructure(Map<String, Object?>.from(jsonDecode(r.rewardStructure) as Map));
        out.add(_cardModel(id: r.id, issuer: r.issuer, name: r.name, last4: '----', cat: r, spec: spec, index: i, owned: false));
      } on Object {
        continue;
      }
    }
    out.sort((a, b) => '${a.issuer} ${a.name}'.compareTo('${b.issuer} ${b.name}'));
    return out;
  }

  @override
  Future<CreditCard> addCard({
    required String catalogId,
    required String last4,
    double? limit,
    int? statementDay,
    int? dueDay,
    double owed = 0,
  }) async {
    final cat = await (db.select(db.catalogCards)..where((c) => c.id.equals(catalogId))).getSingleOrNull();
    if (cat == null) throw const ApiException(message: 'That card is not in the catalog.', code: 'unknown_card');
    // Empty is fine: quick-add skips the digits and they can be added later.
    if (last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)) {
      throw const ApiException(message: 'Enter the last four digits of the card.', code: 'invalid_last4');
    }
    final accountId = newId();
    final count = (await db.select(db.userCards).get()).length;
    await db.transaction(() async {
      await db.into(db.accounts).insert(
        AccountsCompanion.insert(
          id: accountId,
          type: 'credit_card',
          name: cat.name,
          institution: Value(cat.issuer),
          last4: Value(last4.isEmpty ? null : last4),
          creditLimitMinor: Value(limit == null ? null : (limit * 100).round()),
          statementDay: Value(statementDay),
          dueDay: Value(dueDay),
          balanceAnchorMinor: Value((owed * 100).round()),
          balanceAnchorAt: Value(_clock().toUtc()),
        ),
      );
      await db.into(db.userCards).insert(
        UserCardsCompanion.insert(id: newId(), catalogCardId: catalogId, accountId: Value(accountId), colorIndex: Value(count)),
      );
    });
    await pipeline.reprocessPending();
    return (await myCards()).firstWhere((c) => c.id == accountId);
  }

  @override
  Future<void> setCardLast4(String accountId, String last4) async {
    if (!RegExp(r'^\d{4}$').hasMatch(last4)) {
      throw const ApiException(message: 'Enter the last four digits of the card.', code: 'invalid_last4');
    }
    await (db.update(db.accounts)..where((a) => a.id.equals(accountId))).write(AccountsCompanion(last4: Value(last4)));
    await pipeline.reprocessPending();
  }

  @override
  Future<List<DigitSuggestion>> digitSuggestions() => pipeline.digitSuggestions();

  @override
  Future<void> removeCard(String id) async {
    final now = _clock().toUtc();
    await (db.update(db.userCards)..where((u) => u.accountId.equals(id))).write(UserCardsCompanion(deletedAt: Value(now)));
    await (db.update(db.accounts)..where((a) => a.id.equals(id))).write(AccountsCompanion(deletedAt: Value(now)));
  }

  @override
  Future<List<BestCardPick>> bestCard(SpendCategory category, double amount) async {
    final cards = await loadOwnedCards(db);
    if (cards.isEmpty) return const [];
    final amountMinor = (amount * 100).round();
    final ranked = rankCards(
      await rankables(db, cards, _today),
      category: rewardSlug(category.id),
      amountMinor: amountMinor,
    );
    return [
      for (final r in ranked)
        BestCardPick(
          cardId: r.card.id,
          name: r.card.title,
          ratePct: amountMinor == 0 ? 0 : r.quote.valueMinor / amountMinor * 100,
          estimate: _aed(r.quote.valueMinor),
          hitsCap: r.quote.capped,
          verified: cards.firstWhere((c) => c.account.id == r.card.id).catalog.verifiedOn != null,
        ),
    ];
  }

  // ---- accounts & wealth ---------------------------------------------------------------

  Future<List<AccountRow>> _liquidAccounts() => (db.select(db.accounts)
        ..where((a) => a.deletedAt.isNull() & a.type.isNotValue('credit_card'))
        ..orderBy([(a) => OrderingTerm.asc(a.createdAt), (a) => OrderingTerm.asc(a.id)]))
      .get();

  /// Account balance in minor units. The Cash pot never goes below zero: money
  /// spent in cash with no float entered is spending, not an overdrawn account.
  Future<int> _balance(AccountRow a) async {
    final raw = (a.balanceAnchorMinor ?? 0) + await _netSince(a);
    return a.type == 'cash' && raw < 0 ? 0 : raw;
  }

  static BankAccountKind _accountKind(AccountRow a) => switch (a.type) {
    'wallet' => BankAccountKind.wallet,
    'cash' => BankAccountKind.cash,
    _ => a.name.toLowerCase().contains('saving') ? BankAccountKind.savings : BankAccountKind.current,
  };

  @override
  Future<List<BankAccount>> bankAccounts() async {
    final accounts = await _liquidAccounts();
    final today = _today;
    final out = <BankAccount>[];
    for (final (i, a) in accounts.indexed) {
      var inflow = 0, outflow = 0;
      final rows = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(a.id) & t.deletedAt.isNull() & t.currency.equals('AED')))
          .get();
      for (final t in rows) {
        final d = toDubaiDate(t.postedAt);
        if (d.year != today.year || d.month != today.month) continue;
        if (t.direction == 'credit') {
          inflow += t.amountMinor;
        } else {
          outflow += t.amountMinor;
        }
      }
      final kind = _accountKind(a);
      out.add(
        BankAccount(
          id: a.id,
          bank: a.institution ?? (kind == BankAccountKind.cash ? 'Cash' : a.name),
          name: a.institution == null ? (kind == BankAccountKind.cash ? 'On hand' : kind.label) : a.name,
          kind: kind,
          last4: a.last4,
          balance: _aed(await _balance(a)),
          gradient: _accountGradients[i % _accountGradients.length],
          monthIn: _aed(inflow),
          monthOut: _aed(outflow),
          matchLabels: [_label(a)],
          updatedAt: a.balanceAnchorAt,
        ),
      );
    }
    return out;
  }

  @override
  Future<BankAccount> addBankAccount({
    required String bank,
    required String name,
    required BankAccountKind kind,
    String? last4,
    double balance = 0,
  }) async {
    if (last4 != null && last4.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(last4)) {
      throw const ApiException(message: 'Enter the last four digits, or leave it empty.', code: 'invalid_last4');
    }
    final id = newId();
    final type = switch (kind) {
      BankAccountKind.wallet => 'wallet',
      BankAccountKind.cash => 'cash',
      _ => 'bank',
    };
    final label = kind == BankAccountKind.savings && !name.toLowerCase().contains('saving') ? 'Savings $name'.trim() : name.trim();
    await db.into(db.accounts).insert(
      AccountsCompanion.insert(
        id: id,
        type: type,
        name: label.isEmpty ? kind.label : label,
        institution: Value(bank.trim().isEmpty ? null : bank.trim()),
        last4: Value(last4 == null || last4.isEmpty ? null : last4),
        balanceAnchorMinor: Value((balance * 100).round()),
        balanceAnchorAt: Value(_clock().toUtc()),
      ),
    );
    await pipeline.reprocessPending();
    return (await bankAccounts()).firstWhere((a) => a.id == id);
  }

  static AssetKind _assetKind(String k) => switch (k) {
    'cash' => AssetKind.cash,
    'fd' => AssetKind.fixedDeposit,
    'stock' || 'crypto' => AssetKind.stocks,
    'gold' || 'gold_jewellery' => AssetKind.gold,
    'real_estate' => AssetKind.realEstate,
    _ => AssetKind.other,
  };

  static String _assetWire(AssetKind k) => switch (k) {
    AssetKind.cash => 'cash',
    AssetKind.fixedDeposit => 'fd',
    AssetKind.stocks => 'stock',
    AssetKind.gold => 'gold',
    AssetKind.realEstate => 'real_estate',
    _ => 'other',
  };

  @override
  Future<Asset> addAsset({required String name, required AssetKind kind, required double value}) async {
    if (kind == AssetKind.liability) {
      final id = newId();
      await db.into(db.liabilities).insert(
        LiabilitiesCompanion.insert(id: id, kind: 'other', name: name.trim(), outstandingMinor: (value * 100).round()),
      );
      return Asset(id: id, name: name.trim(), kind: kind, value: value);
    }
    final id = newId();
    await db.into(db.assets).insert(
      AssetsCompanion.insert(
        id: id,
        kind: _assetWire(kind),
        name: name.trim(),
        manualValueMinor: Value((value * 100).round()),
        valuedAt: Value(_clock().toUtc()),
      ),
    );
    return Asset(id: id, name: name.trim(), kind: kind, value: value);
  }

  @override
  Future<void> updateAsset(String id, {required String name, required double value}) async {
    final label = name.trim();
    if (label.isEmpty) throw const ApiException(message: 'Give it a name');
    final minor = (value * 100).round();
    if (id.startsWith('account:')) {
      await (db.update(db.accounts)..where((a) => a.id.equals(id.substring(8)))).write(
        AccountsCompanion(name: Value(label), balanceAnchorMinor: Value(minor), balanceAnchorAt: Value(_clock().toUtc())),
      );
      return;
    }
    final updated = await (db.update(db.liabilities)..where((l) => l.id.equals(id))).write(
      LiabilitiesCompanion(name: Value(label), outstandingMinor: Value(minor)),
    );
    if (updated > 0) return;
    await (db.update(db.assets)..where((a) => a.id.equals(id))).write(
      AssetsCompanion(name: Value(label), manualValueMinor: Value(minor), valuedAt: Value(_clock().toUtc())),
    );
  }

  @override
  Future<void> deleteAsset(String id) async {
    final now = Value(_clock().toUtc());
    if (id.startsWith('account:')) {
      await (db.update(db.accounts)..where((a) => a.id.equals(id.substring(8)))).write(AccountsCompanion(deletedAt: now));
      return;
    }
    final updated = await (db.update(db.liabilities)..where((l) => l.id.equals(id))).write(LiabilitiesCompanion(deletedAt: now));
    if (updated > 0) return;
    await (db.update(db.assets)..where((a) => a.id.equals(id))).write(AssetsCompanion(deletedAt: now));
  }

  @override
  Future<List<Asset>> assets() async {
    final (assetRows, liabilityRows, accounts, cards) = await (
      (db.select(db.assets)..where((a) => a.deletedAt.isNull())).get(),
      (db.select(db.liabilities)..where((l) => l.deletedAt.isNull() & l.accountId.isNull())).get(),
      _liquidAccounts(),
      loadOwnedCards(db),
    ).wait;
    final out = <Asset>[];
    for (final a in accounts) {
      final balance = await _balance(a);
      // An empty Cash pot is just a place for cash expenses; it is not an asset yet.
      if (a.type == 'cash' && balance <= 0) continue;
      out.add(Asset(id: 'account:${a.id}', name: _label(a), kind: AssetKind.cash, value: _aed(balance), note: 'Account balance', editable: true));
    }
    for (final a in assetRows) {
      out.add(Asset(id: a.id, name: a.name, kind: _assetKind(a.kind), value: _aed(a.manualValueMinor ?? a.costBasisMinor ?? 0), editable: true));
    }
    if (wealth != null) out.addAll(await wealth!.assets());
    for (final l in liabilityRows) {
      out.add(Asset(id: l.id, name: l.name, kind: AssetKind.liability, value: _aed(l.outstandingMinor), note: l.lender ?? '', editable: true));
    }
    for (final c in cards) {
      final owed = await _owed(c.account);
      if (owed > 0) out.add(Asset(id: 'card:${c.account.id}', name: c.title, kind: AssetKind.liability, value: _aed(owed), note: 'Card balance'));
    }
    return out;
  }

  @override
  Future<NetWorth> netWorth() async {
    final all = await assets();
    final result = computeNetWorth(
      [for (final a in all) if (!a.isLiability) AssetInput('asset', 'AED', (a.value * 100).round())],
      [for (final a in all) if (a.isLiability) LiabilityInput('liability', 'AED', (a.value * 100).round())],
    );
    final today = _today;
    await _saveSnapshot(today, result);
    final snaps = await (db.select(db.netWorthSnapshots)..orderBy([(s) => OrderingTerm.asc(s.snapshotDate)])).get();
    final series = <double>[], labels = <String>[];
    for (var i = 5; i >= 0; i--) {
      final idx = today.year * 12 + today.month - 1 - i;
      final y = idx ~/ 12, m = idx % 12 + 1;
      labels.add(_months[m - 1]);
      if (i == 0) {
        series.add(_aed(result.netWorthMinor));
        continue;
      }
      final end = '$y-${m.toString().padLeft(2, '0')}-31';
      final before = snaps.where((s) => s.snapshotDate.compareTo(end) <= 0).toList();
      // No history yet: hold the current value flat rather than invent one.
      series.add(before.isEmpty ? _aed(result.netWorthMinor) : _aed(before.last.netWorthMinor));
    }
    final prev = series.length > 1 ? series[series.length - 2] : series.last;
    final change = series.last - prev;
    final book = wealth == null ? null : await wealth!.book();
    return NetWorth(
      total: _aed(result.netWorthMinor),
      series: series,
      labels: labels,
      changeAed: change,
      changePct: prev == 0 ? 0 : change / prev.abs() * 100,
      updatedAt: book?.fetchedAt,
      prices: book == null ? const [] : priceInputs(book),
      pricesLive: book != null && !book.isStale && book.origin == PriceOrigin.fetched,
    );
  }

  /// Stores (or refreshes) today's snapshot. At most one row a day.
  Future<void> _saveSnapshot(CalDate today, NetWorthResult result) async {
    final todayIso = today.toIso();
    final existing = await (db.select(db.netWorthSnapshots)..where((s) => s.snapshotDate.equals(todayIso))).getSingleOrNull();
    if (existing == null) {
      await db.into(db.netWorthSnapshots).insert(
        NetWorthSnapshotsCompanion.insert(
          id: newId(),
          snapshotDate: todayIso,
          assetsMinor: result.totalAssetsMinor,
          liabilitiesMinor: result.totalLiabilitiesMinor,
          netWorthMinor: result.netWorthMinor,
        ),
      );
    } else {
      await (db.update(db.netWorthSnapshots)..where((s) => s.id.equals(existing.id))).write(
        NetWorthSnapshotsCompanion(
          assetsMinor: Value(result.totalAssetsMinor),
          liabilitiesMinor: Value(result.totalLiabilitiesMinor),
          netWorthMinor: Value(result.netWorthMinor),
          breakdown: const Value('{}'),
        ),
      );
    }
  }

  static const _backfillMark = '"src":"backfill"';

  @override
  Future<List<NwPoint>> netWorthHistory() async {
    final all = await assets();
    final result = computeNetWorth(
      [for (final a in all) if (!a.isLiability) AssetInput('asset', 'AED', (a.value * 100).round())],
      [for (final a in all) if (a.isLiability) LiabilityInput('liability', 'AED', (a.value * 100).round())],
    );
    final today = _today;
    await _saveSnapshot(today, result);
    await _backfillSnapshots(today, result);
    final snaps = await (db.select(db.netWorthSnapshots)..orderBy([(s) => OrderingTerm.asc(s.snapshotDate)])).get();
    return [
      for (final s in snaps)
        NwPoint(
          CalDate.parse(s.snapshotDate),
          s.assetsMinor,
          s.liabilitiesMinor,
          estimated: s.breakdown.contains(_backfillMark),
        ),
    ];
  }

  /// Fills the days before the first real snapshot from transactions, so a
  /// new install has a line to show. Estimated rows are marked in
  /// `breakdown` and never overwrite a real snapshot. Re-run only when the
  /// ledger's reach changes.
  Future<void> _backfillSnapshots(CalDate today, NetWorthResult result) async {
    final accounts = await _accountMap();
    final rows = await (db.select(db.transactions)..where((t) => t.deletedAt.isNull() & t.currency.equals('AED'))).get();
    final flows = <NwFlow>[];
    for (final t in rows) {
      final a = accounts[t.accountId];
      if (a == null || a.deletedAt != null) continue;
      // Anything before the account's balance anchor is already in it.
      if (a.balanceAnchorAt != null && !t.postedAt.isAfter(a.balanceAnchorAt!)) continue;
      flows.add(NwFlow(toDubaiDate(t.postedAt), t.direction == 'credit' ? t.amountMinor : -t.amountMinor, isCard: a.type == 'credit_card'));
    }
    final snaps = await db.select(db.netWorthSnapshots).get();
    final real = [for (final s in snaps) if (!s.breakdown.contains(_backfillMark)) s.snapshotDate]..sort();
    final firstReal = real.isEmpty ? today : CalDate.parse(real.first);
    final earliest = flows.isEmpty ? null : flows.map((f) => f.date).reduce((a, b) => a < b ? a : b);
    final sig = '${earliest?.toIso()}|${firstReal.toIso()}|${flows.length ~/ 25}';
    if (await db.setting('nw_backfill_sig') == sig) return;
    final points = backfill(
      assetsNowMinor: result.totalAssetsMinor,
      liabilitiesNowMinor: result.totalLiabilitiesMinor,
      flows: flows,
      today: today,
      firstSnapshot: firstReal,
    );
    final byDate = {for (final s in snaps) s.snapshotDate: s};
    await db.batch((b) {
      for (final p in points) {
        final iso = p.date.toIso();
        final old = byDate[iso];
        if (old != null && !old.breakdown.contains(_backfillMark)) continue;
        if (old == null) {
          b.insert(
            db.netWorthSnapshots,
            NetWorthSnapshotsCompanion.insert(
              id: newId(),
              snapshotDate: iso,
              assetsMinor: p.assetsMinor,
              liabilitiesMinor: p.liabilitiesMinor,
              netWorthMinor: p.netMinor,
              breakdown: const Value('{$_backfillMark}'),
            ),
          );
        } else {
          b.update(
            db.netWorthSnapshots,
            NetWorthSnapshotsCompanion(
              assetsMinor: Value(p.assetsMinor),
              liabilitiesMinor: Value(p.liabilitiesMinor),
              netWorthMinor: Value(p.netMinor),
            ),
            where: (s) => s.id.equals(old.id),
          );
        }
      }
    });
    await db.putSetting('nw_backfill_sig', sig);
  }

  // ---- insights -----------------------------------------------------------------------------

  Future<double> _cash() async {
    var total = 0;
    for (final a in await _liquidAccounts()) {
      total += await _balance(a);
    }
    return _aed(total);
  }

  Future<List<CreditCard>> _dueBefore(DateTime end) async => [
    for (final c in await myCards())
      if (c.totalDue > 0 && !c.dueDate.isAfter(end)) c,
  ];

  @override
  Future<Cashflow> cashflow() async {
    final now = _clock();
    final today = _today;
    final since = DateTime.utc(today.year, today.month - 5, 1).subtract(const Duration(days: 1));
    final (rows, accounts, cats, cash) = await (_txRows(since: since), _accountMap(), _categoryMap(), _cash()).wait;
    final domain = [for (final t in rows) if (t.currency == 'AED') _toTx(t, accounts, cats)];
    final months = cashflowFromTransactions(domain, now: now);
    final end = DateTime(today.year, today.month + 1, 0);
    final dues = (await _dueBefore(end)).fold<double>(0, (a, c) => a + c.totalDue);
    final bills = _aed(await _billsLeft(rows));
    final committed = dues + bills;
    return Cashflow(
      months: months,
      balanceNow: cash,
      committed: committed,
      projectedEndBalance: projectEndBalance(
        balanceNow: cash,
        spentSoFar: months.last.spend,
        dayOfMonth: today.day,
        daysInMonth: DateUtils.getDaysInMonth(today.year, today.month),
        committed: committed,
      ),
    );
  }

  @override
  Future<CategoryTrends> categoryTrends() async {
    final today = _today;
    final since = DateTime.utc(today.year, today.month - 5, 1).subtract(const Duration(days: 1));
    final (rows, cats) = await (_txRows(since: since), _categoryMap()).wait;
    final monthIdx = [
      for (var i = 5; i >= 0; i--) today.year * 12 + today.month - 1 - i,
    ];
    final by = <String, List<double>>{};
    for (final t in rows) {
      if (!_countsAsSpend(t, cats)) continue;
      final d = toDubaiDate(t.postedAt);
      final i = monthIdx.indexOf(d.year * 12 + d.month - 1);
      if (i < 0) continue;
      (by[t.categoryId ?? 'other'] ??= List.filled(6, 0.0))[i] += _aed(t.amountMinor);
    }
    final series = [
      for (final e in by.entries) CategoryTrend(_spendCategory(cats[e.key]), e.value),
    ]..sort((a, b) => b.values.last.compareTo(a.values.last));
    return CategoryTrends([for (final i in monthIdx) _months[i % 12]], series.take(6).toList());
  }

  /// Known recurring payments still to come before month end.
  Future<int> _billsLeft(List<TxRow> rows) async {
    final today = _today;
    final dismissed = {
      for (final r in await db.select(db.recurringChoices).get())
        if (r.choice == 'ignored') r.seriesKey,
    };
    final charges = [
      for (final t in rows)
        if (t.direction == 'debit' && t.currency == 'AED')
          if (merchantKey(t.merchantNormalized ?? t.merchantRaw) case final key?)
            recurring.Charge(toDubaiDate(t.postedAt), t.amountMinor, t.merchantNormalized ?? t.merchantRaw ?? key, key, t.categoryId),
    ];
    final end = CalDate(today.year, today.month, daysInMonth(today.year, today.month));
    var total = 0;
    for (final s in recurring.detect(charges, today)) {
      if (dismissed.contains(s.key) || s.status == 'lapsed') continue;
      total += recurring.occurrencesBetween(s, today, end).length * s.typicalAmountMinor;
    }
    return total;
  }

  /// Goals' monthly set-aside, from the pure engine, with linked goals read
  /// from the live Wealth list.
  Future<List<GoalReservation>> _goalReserve() async {
    final store = LocalGoalStore(db);
    final goals = await store.goals();
    if (goals.isEmpty) return const [];
    final contribs = await store.contributions();
    final linked = goals.any((g) => g.linkedRef != null) ? {for (final a in await assets()) a.id: a} : <String, Asset>{};
    return goalReservations(GoalService.inputs(goals, contribs, linked), _today);
  }

  @override
  Future<SafeToSpend> safeToSpend() async {
    final today = _today;
    final end = DateTime(today.year, today.month + 1, 0);
    final since = DateTime.utc(today.year - 1, today.month, 1);
    final (budget, cash, dues, rows, goals) = await (
      budgetOverview(),
      _cash(),
      _dueBefore(end),
      _txRows(since: since),
      _goalReserve(),
    ).wait;
    final bills = _aed(await _billsLeft(rows));
    return computeSafeToSpend(
      cash: cash,
      // Without budgets only the cash limit applies.
      budgetLeft: budget.planned > 0 ? budget.remaining : double.infinity,
      bills: bills,
      cardDues: dues.fold<double>(0, (a, c) => a + c.totalDue),
      goals: _aed(totalReserved(goals)),
      daysLeft: budget.daysLeft,
      goalLines: [for (final g in goals) GoalLine(g.goalId, g.name, _aed(g.amountMinor))],
    );
  }

  @override
  Future<HealthScore> healthScore() async {
    final (flowData, cards, accounts) = await (cashflow(), myCards(), _liquidAccounts()).wait;
    final active = flowData.months.where((m) => m.income > 0 || m.spend > 0).toList();
    if (accounts.isEmpty || active.isEmpty) {
      return const HealthScore(0, [], 'Add an account and some spending to see a score.', insufficient: true);
    }
    final full = flowData.months.length > 1 ? flowData.months[flowData.months.length - 2] : flowData.months.last;
    final limits = cards.fold<double>(0, (a, c) => a + c.limit);
    final balances = cards.fold<double>(0, (a, c) => a + c.balance);
    final avg = active.fold<double>(0, (a, m) => a + m.spend) / active.length;
    return computeHealthScore(
      savingsRate: full.savingsRate,
      utilisation: limits == 0 ? 0 : balances / limits,
      onTimeRate: 1, // Needs statement history; neutral until statements are added.
      runwayMonths: avg == 0 ? 0 : flowData.balanceNow / avg,
    );
  }

  // ---- capture ------------------------------------------------------------------------------

  /// Runs a synthetic card tap through the real ingest pipeline. The reward
  /// banner then appears exactly as for a real capture.
  @override
  Future<Transaction> simulateCapture() async {
    final cards = await loadOwnedCards(db);
    final accounts = cards.isNotEmpty ? [for (final c in cards) c.account] : await _liquidAccounts();
    if (accounts.isEmpty) {
      throw const ApiException(message: 'Add a card or account first, then try again.', code: 'not_supported');
    }
    final now = _clock();
    final pick = accounts[now.millisecond % accounts.length];
    const samples = [
      ('Carrefour', 8500),
      ('Talabat', 6200),
      ('ADNOC', 15000),
      ('Spinneys', 12400),
      ('Starbucks', 2800),
    ];
    final (merchant, amount) = samples[now.second % samples.length];
    final outcome = await pipeline.ingest(
      IngestInput(
        channel: TxnSource.googleWallet,
        externalId: 'demo:${now.microsecondsSinceEpoch}',
        receivedAt: now,
        appName: 'Wallet',
        fields: IngestFields(
          amountMinor: amount + (now.microsecond % 50) * 100 ~/ 100,
          merchant: merchant,
          last4: pick.last4,
          postedAt: now,
        ),
      ),
    );
    final id = outcome.transactionId;
    if (id == null) {
      throw const ApiException(message: 'The tap could not be matched to an account.', code: 'not_matched');
    }
    return _txById(id);
  }

  /// Rewards, benefits, rings and hints per owned card, all on the device.
  Future<CardValueReport> cardValueReport() => buildCardValueReport(db, _today);

  /// The banner content for a capture outcome that earned something.
  Future<RewardMomentData?> momentFor(IngestOutcome o) async {
    final r = o.reward;
    final id = o.transactionId;
    if (r == null || id == null) return null;
    final tx = await _txById(id);
    final card = (await myCards()).where((c) => c.id == r.accountId).firstOrNull;
    if (card == null) return null;
    return RewardMomentData(
      tx: tx,
      card: card,
      earned: _aed(r.earnedValueMinor),
      ratePct: r.ratePct,
      cap: r.capLimitAed == null ? null : RewardCap(limit: r.capLimitAed!, used: r.capUsedAed ?? 0),
      nudge: r.nudge,
      check: r.check,
    );
  }

  // ---- needs a server ---------------------------------------------------------------------------

  Future<T> _needsServer<T>(String what, Future<T> Function(PulseRepository s) call) {
    final s = shared;
    if (s == null) {
      return Future.error(NeedsSignInException(what));
    }
    return call(s);
  }

  Future<T> _orDefault<T>(T fallback, Future<T> Function(PulseRepository s) call) async {
    final s = shared;
    if (s == null) return fallback;
    try {
      return await call(s);
    } on Object {
      // Offline, a 401, a bad payload: the on-device ledger still works, so
      // shared features show their empty state instead of an error screen.
      return fallback;
    }
  }

  /// Groups made on this phone, plus (best effort) the ones a configured
  /// server already has. A server outage never hides the local groups.
  @override
  Future<List<SplitGroup>> splitGroups() async {
    final mine = await _splits.groups();
    final remote = await _orDefault(const <SplitGroup>[], (s) => s.splitGroups());
    final ids = {for (final g in mine) g.id};
    return [...mine, for (final g in remote) if (!ids.contains(g.id)) g];
  }

  @override
  Future<SplitGroup> createSplitGroup({
    required String name,
    String emoji = '👥',
    List<NewGroupMember> members = const [],
  }) async {
    // Signed in to the backend: make a shared group on the server, so people
    // added by phone number who use Pulse see it too. Offline, signed out, or
    // a server problem: keep it on this phone (it still works, just unshared).
    final s = shared;
    if (s != null && _cloudReady()) {
      try {
        return await s.createSplitGroup(name: name, emoji: emoji, members: members);
      } on ApiException catch (e) {
        // A rejected request (bad phone number, ...) is the person's to fix.
        if (e.isPermanent) rethrow;
      } on Object {
        // Offline or unavailable: fall through to a group on this phone.
      }
    }
    return _splits.createGroup(name: name, emoji: emoji, members: members);
  }

  @override
  Future<SplitExpense> addSplitExpense(String groupId, SplitExpense expense) async {
    if (await _splits.hasGroup(groupId)) return _splits.addExpense(groupId, expense);
    return _needsServer('Splitting with others', (s) => s.addSplitExpense(groupId, expense));
  }

  @override
  Future<Member> addMember(String groupId, {required String name, String? phone}) async {
    if (await _splits.hasGroup(groupId)) return _splits.addMember(groupId, name: name, phone: phone);
    return _needsServer('Splitting with others', (s) => s.addMember(groupId, name: name, phone: phone));
  }

  @override
  Future<Set<String>> matchContacts(List<String> phoneHashes) => _orDefault(<String>{}, (s) => s.matchContacts(phoneHashes));

  @override
  Future<SettlementRecord> markSettlementPaid(String groupId, {required String from, required String to, required double amount}) async {
    if (await _splits.hasGroup(groupId)) return _splits.markPaid(groupId, from: from, to: to, amount: amount);
    return _needsServer('Settling up', (s) => s.markSettlementPaid(groupId, from: from, to: to, amount: amount));
  }

  @override
  Future<SettlementRecord> confirmSettlement(String groupId, String settlementId) async {
    if (await _splits.hasGroup(groupId)) return _splits.confirm(groupId, settlementId);
    return _needsServer('Settling up', (s) => s.confirmSettlement(groupId, settlementId));
  }

  @override
  Future<void> undoSettlement(String groupId, String settlementId) async {
    if (await _splits.hasGroup(groupId)) return _splits.undo(groupId, settlementId);
    return _needsServer('Settling up', (s) => s.undoSettlement(groupId, settlementId));
  }

  @override
  Future<List<Statement>> statements() {
    final svc = statementService;
    return svc != null ? svc.statements() : _orDefault(const [], (s) => s.statements());
  }

  @override
  Future<Reconciliation> reconciliation(String statementId) {
    final svc = statementService;
    return svc != null ? svc.reconciliation(statementId) : _needsServer('Statements', (s) => s.reconciliation(statementId));
  }

  @override
  Future<UploadResult> uploadStatement({required Uint8List bytes, required String filename, String? institution}) async {
    final svc = statementService;
    if (svc == null) {
      return _needsServer('Statement upload', (s) => s.uploadStatement(bytes: bytes, filename: filename, institution: institution));
    }
    final r = await svc.upload(bytes: bytes, filename: filename, institution: institution);
    return UploadResult(id: r.id, duplicate: r.duplicate);
  }

  @override
  Future<void> reprocessStatement(String statementId) {
    final svc = statementService;
    return svc != null ? svc.reprocess(statementId) : _needsServer('Statements', (s) => s.reprocessStatement(statementId));
  }

  @override
  Future<List<StatementPassword>> statementPasswords() => _orDefault(const [], (s) => s.statementPasswords());

  @override
  Future<void> setStatementPassword(String institution, String password) =>
      _needsServer('Statement passwords', (s) => s.setStatementPassword(institution, password));

  @override
  Future<Uri?> startGmailConnect() => _needsServer('Gmail', (s) => s.startGmailConnect());

  @override
  Future<List<EmailConnection>> emailConnections() => _orDefault(const [], (s) => s.emailConnections());

  @override
  Future<Household> household() async {
    final b = await budgetOverview();
    return Household('Household', [
      FamilyMember(id: 'me', name: 'You', relation: 'You', sharing: SharingLevel.totals, isYou: true, spent: b.spent, budget: b.planned),
    ]);
  }

  @override
  Future<FamilyMember> inviteFamilyMember({required String name, required String phone, required String relation}) =>
      _needsServer('Family sharing', (s) => s.inviteFamilyMember(name: name, phone: phone, relation: relation));

  @override
  Future<void> setSharing(String memberId, SharingLevel level) => _needsServer('Family sharing', (s) => s.setSharing(memberId, level));
}

/// Everything the reward banner needs for one capture.
class RewardMomentData {
  const RewardMomentData({
    required this.tx,
    required this.card,
    required this.earned,
    required this.ratePct,
    this.cap,
    this.nudge,
    this.check,
  });
  final Transaction tx;
  final CreditCard card;
  final double earned, ratePct;
  final RewardCap? cap;
  final String? nudge;
  final CardCheck? check;
}
