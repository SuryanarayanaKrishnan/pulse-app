import 'package:drift/drift.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/investing.dart';
import '../wealth_models.dart';
import 'database.dart';

/// Stock/ETF holdings, investing rules and their planned buys. Two
/// implementations like the wealth store: drift (the phone) and memory (demo,
/// web, tests).
abstract class InvestingStore {
  Future<List<StockHolding>> holdings();
  Future<StockHolding> saveHolding(StockHolding h);
  Future<void> deleteHolding(String id);

  Future<List<InvestRule>> rules();
  Future<InvestRule> saveRule(InvestRule r);

  /// Soft-deletes the rule; its history of buys is kept.
  Future<void> deleteRule(String id);

  Future<List<RuleOccurrence>> occurrences({String? ruleId});
  Future<void> saveOccurrence(RuleOccurrence o);
}

CalDate? _date(String? iso) {
  if (iso == null) return null;
  try {
    return CalDate.parse(iso);
  } catch (_) {
    return null;
  }
}

class LocalInvestingStore implements InvestingStore {
  LocalInvestingStore(this.db);
  final PulseDatabase db;

  StockHolding _holding(InvestmentRow r) => StockHolding(
    id: r.id,
    symbol: r.symbol,
    name: r.name,
    currency: r.currency,
    quantity: r.quantity,
    avgCost: r.avgCost,
    lastPrice: r.lastPrice,
    priceAt: r.priceAt,
    priceSource: r.priceSource,
    purchaseDate: _date(r.purchaseDate),
    approximate: r.approximate,
    source: r.source,
    note: r.note,
    createdAt: r.createdAt,
  );

  @override
  Future<List<StockHolding>> holdings() async => [
    for (final r
        in await (db.select(db.investmentHoldings)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get())
      _holding(r),
  ];

  @override
  Future<StockHolding> saveHolding(StockHolding h) async {
    await db
        .into(db.investmentHoldings)
        .insertOnConflictUpdate(
          InvestmentHoldingsCompanion(
            id: Value(h.id),
            symbol: Value(h.symbol),
            name: Value(h.name),
            currency: Value(h.currency),
            quantity: Value(h.quantity),
            avgCost: Value(h.avgCost),
            lastPrice: Value(h.lastPrice),
            priceAt: Value(h.priceAt),
            priceSource: Value(h.priceSource),
            purchaseDate: Value(h.purchaseDate?.toIso()),
            approximate: Value(h.approximate),
            source: Value(h.source),
            note: Value(h.note),
            createdAt: Value(h.createdAt),
            deletedAt: const Value(null),
          ),
        );
    return h;
  }

  @override
  Future<void> deleteHolding(String id) =>
      (db.update(db.investmentHoldings)..where((t) => t.id.equals(id))).write(
        InvestmentHoldingsCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );

  InvestRule _rule(InvestingRuleRow r) => InvestRule(
    id: r.id,
    symbol: r.symbol,
    name: r.name,
    amountMinor: r.amountMinor,
    currency: r.currency,
    frequency: RuleFrequency.fromWire(r.frequency),
    day: r.day,
    startDate: _date(r.startDate) ?? const CalDate(2000, 1, 1),
    endDate: _date(r.endDate),
    active: r.active,
  );

  @override
  Future<List<InvestRule>> rules() async => [
    for (final r
        in await (db.select(db.investingRules)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get())
      _rule(r),
  ];

  @override
  Future<InvestRule> saveRule(InvestRule r) async {
    await db
        .into(db.investingRules)
        .insertOnConflictUpdate(
          InvestingRulesCompanion(
            id: Value(r.id),
            symbol: Value(r.symbol),
            name: Value(r.name),
            amountMinor: Value(r.amountMinor),
            currency: Value(r.currency),
            frequency: Value(r.frequency.wire),
            day: Value(r.day),
            startDate: Value(r.startDate.toIso()),
            endDate: Value(r.endDate?.toIso()),
            active: Value(r.active),
            deletedAt: const Value(null),
          ),
        );
    return r;
  }

  @override
  Future<void> deleteRule(String id) =>
      (db.update(db.investingRules)..where((t) => t.id.equals(id))).write(
        InvestingRulesCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );

  RuleOccurrence _occ(InvestingOccurrenceRow r) => RuleOccurrence(
    id: r.id,
    ruleId: r.ruleId,
    due: _date(r.dueDate) ?? const CalDate(2000, 1, 1),
    amountMinor: r.amountMinor,
    status: OccurrenceStatus.fromWire(r.status),
    price: r.price,
    units: r.units,
    decidedOn: _date(r.decidedOn),
  );

  @override
  Future<List<RuleOccurrence>> occurrences({String? ruleId}) async {
    final q = db.select(db.investingOccurrences);
    if (ruleId != null) q.where((t) => t.ruleId.equals(ruleId));
    q.orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return [for (final r in await q.get()) _occ(r)];
  }

  @override
  Future<void> saveOccurrence(RuleOccurrence o) async {
    await db
        .into(db.investingOccurrences)
        .insertOnConflictUpdate(
          InvestingOccurrencesCompanion(
            id: Value(o.id),
            ruleId: Value(o.ruleId),
            dueDate: Value(o.due.toIso()),
            amountMinor: Value(o.amountMinor),
            status: Value(o.status.name),
            price: Value(o.price),
            units: Value(o.units),
            decidedOn: Value(o.decidedOn?.toIso()),
          ),
        );
  }
}

class MemoryInvestingStore implements InvestingStore {
  MemoryInvestingStore({
    List<StockHolding> holdings = const [],
    List<InvestRule> rules = const [],
    List<RuleOccurrence> occurrences = const [],
  }) : _holdings = [...holdings],
       _rules = [...rules],
       _occ = [...occurrences];

  final List<StockHolding> _holdings;
  final List<InvestRule> _rules;
  final List<RuleOccurrence> _occ;

  static void _put<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    i < 0 ? list.add(item) : list[i] = item;
  }

  @override
  Future<List<StockHolding>> holdings() async => List.of(_holdings);
  @override
  Future<StockHolding> saveHolding(StockHolding h) async {
    _put<StockHolding>(_holdings, h, (e) => e.id);
    return h;
  }

  @override
  Future<void> deleteHolding(String id) async =>
      _holdings.removeWhere((e) => e.id == id);

  @override
  Future<List<InvestRule>> rules() async => List.of(_rules);
  @override
  Future<InvestRule> saveRule(InvestRule r) async {
    _put<InvestRule>(_rules, r, (e) => e.id);
    return r;
  }

  @override
  Future<void> deleteRule(String id) async =>
      _rules.removeWhere((e) => e.id == id);

  @override
  Future<List<RuleOccurrence>> occurrences({String? ruleId}) async => [
    for (final o in _occ)
      if (ruleId == null || o.ruleId == ruleId) o,
  ]..sort((a, b) => a.due.compareTo(b.due));
  @override
  Future<void> saveOccurrence(RuleOccurrence o) async =>
      _put<RuleOccurrence>(_occ, o, (e) => e.id);
}
