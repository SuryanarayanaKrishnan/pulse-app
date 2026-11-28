import 'package:drift/drift.dart';

import '../../core/engine/budget_moves.dart';
import '../../core/engine/flex_budget.dart';
import 'database.dart';
import 'default_categories.dart';
import 'ids.dart';

enum BudgetMode {
  flex('flex'),
  category('category');

  const BudgetMode(this.key);
  final String key;
  static BudgetMode fromKey(String? k) => k == 'category' ? category : flex;
}

/// What the flex budget needs to know about one category.
class CategoryPlan {
  const CategoryPlan({
    required this.id,
    required this.group,
    this.kind = 'expense',
    this.hidden = false,
    this.rollover = false,
    this.rolloverStart,
    this.rolloverStartMinor = 0,
    this.cycleCostMinor = 0,
    this.cycleMonths = 1,
    this.groupChosen = false,
  });
  final String id;
  final BudgetGroup group;

  /// The user picked [group] (as opposed to the default for the category).
  final bool groupChosen;
  final String kind;
  final bool hidden;
  final bool rollover;
  final String? rolloverStart;
  final int rolloverStartMinor;
  final int cycleCostMinor;
  final int cycleMonths;

  bool get isExpense => kind == 'expense';

  /// Non-monthly always rolls over: that is what a sinking fund is.
  bool get rolls => rollover || group == BudgetGroup.nonMonthly;

  CategoryPlan copyWith({
    BudgetGroup? group,
    bool? rollover,
    String? rolloverStart,
    int? rolloverStartMinor,
    int? cycleCostMinor,
    int? cycleMonths,
  }) => CategoryPlan(
    id: id,
    group: group ?? this.group,
    groupChosen: group != null || groupChosen,
    kind: kind,
    hidden: hidden,
    rollover: rollover ?? this.rollover,
    rolloverStart: rolloverStart ?? this.rolloverStart,
    rolloverStartMinor: rolloverStartMinor ?? this.rolloverStartMinor,
    cycleCostMinor: cycleCostMinor ?? this.cycleCostMinor,
    cycleMonths: cycleMonths ?? this.cycleMonths,
  );
}

class LimitRow {
  const LimitRow(this.categoryId, this.month, this.limitMinor);
  final String categoryId;
  final String month;
  final int limitMinor;
}

/// Storage for the flex budget: the drift database, or memory (demo data,
/// web builds, tests).
abstract class BudgetPlanStore {
  Future<BudgetMode> mode();
  Future<void> setMode(BudgetMode m);
  Future<List<CategoryPlan>> categories();
  Future<void> saveCategoryPlan(CategoryPlan c);
  Future<List<LimitRow>> limits();

  /// Sets the limit for [month] (0 clears it for that month).
  Future<void> saveLimit(String categoryId, String month, int minor);

  /// Moves not undone, oldest first.
  Future<List<BudgetMove>> moves();
  Future<void> addMove(BudgetMove m);
  Future<void> undoMove(String id);
}

class LocalBudgetPlanStore implements BudgetPlanStore {
  LocalBudgetPlanStore(this.db);
  final PulseDatabase db;

  @override
  Future<BudgetMode> mode() async {
    final r = await (db.select(
      db.budgetPrefs,
    )..where((t) => t.id.equals('main'))).getSingleOrNull();
    return BudgetMode.fromKey(r?.mode);
  }

  @override
  Future<void> setMode(BudgetMode m) => db
      .into(db.budgetPrefs)
      .insertOnConflictUpdate(
        BudgetPrefsCompanion(id: const Value('main'), mode: Value(m.key)),
      );

  @override
  Future<List<CategoryPlan>> categories() async => [
    for (final c in await db.select(db.categories).get())
      CategoryPlan(
        id: c.id,
        group: BudgetGroup.resolve(c.budgetGroup, isFixed: c.isFixed),
        groupChosen: BudgetGroup.fromKey(c.budgetGroup) != null,
        kind: c.kind,
        hidden: c.isHidden,
        rollover: c.rollover,
        rolloverStart: c.rolloverStart,
        rolloverStartMinor: c.rolloverStartMinor,
        cycleCostMinor: c.cycleCostMinor,
        cycleMonths: c.cycleMonths < 1 ? 1 : c.cycleMonths,
      ),
  ];

  @override
  Future<void> saveCategoryPlan(CategoryPlan c) =>
      (db.update(db.categories)..where((t) => t.id.equals(c.id))).write(
        CategoriesCompanion(
          budgetGroup: Value(c.groupChosen ? c.group.key : null),
          rollover: Value(c.rollover),
          rolloverStart: Value(c.rolloverStart),
          rolloverStartMinor: Value(c.rolloverStartMinor),
          cycleCostMinor: Value(c.cycleCostMinor),
          cycleMonths: Value(c.cycleMonths),
        ),
      );

  @override
  Future<List<LimitRow>> limits() async => [
    for (final b in await db.select(db.budgets).get())
      LimitRow(b.categoryId, b.month, b.limitMinor),
  ];

  @override
  Future<void> saveLimit(String categoryId, String month, int minor) async {
    final q = db.select(db.budgets)
      ..where((b) => b.categoryId.equals(categoryId) & b.month.equals(month));
    final existing = await q.getSingleOrNull();
    if (existing != null) {
      await (db.update(db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(limitMinor: Value(minor)));
    } else {
      await db
          .into(db.budgets)
          .insert(
            BudgetsCompanion.insert(
              id: newId(),
              categoryId: categoryId,
              month: month,
              limitMinor: minor,
            ),
          );
    }
  }

  @override
  Future<List<BudgetMove>> moves() async => [
    for (final r
        in await (db.select(db.budgetMoves)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get())
      BudgetMove(
        id: r.id,
        month: r.month,
        fromId: r.fromCategoryId,
        toId: r.toCategoryId,
        amountMinor: r.amountMinor,
        scope: MoveScope.fromKey(r.scope),
      ),
  ];

  @override
  Future<void> addMove(BudgetMove m) => db
      .into(db.budgetMoves)
      .insert(
        BudgetMovesCompanion.insert(
          id: m.id,
          scope: Value(m.scope.key),
          month: m.month,
          fromCategoryId: m.fromId,
          toCategoryId: m.toId,
          amountMinor: m.amountMinor,
        ),
      );

  @override
  Future<void> undoMove(String id) =>
      (db.update(db.budgetMoves)..where((t) => t.id.equals(id))).write(
        BudgetMovesCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );
}

class MemoryBudgetPlanStore implements BudgetPlanStore {
  MemoryBudgetPlanStore({
    List<CategoryPlan>? categories,
    List<LimitRow> limits = const [],
    BudgetMode mode = BudgetMode.flex,
  }) : _cats = [...(categories ?? defaultCategoryPlans())],
       _limits = [...limits],
       _mode = mode; // ignore: prefer_initializing_formals
  final List<CategoryPlan> _cats;
  final List<LimitRow> _limits;
  final List<BudgetMove> _moves = [];
  BudgetMode _mode;

  @override
  Future<BudgetMode> mode() async => _mode;

  @override
  Future<void> setMode(BudgetMode m) async => _mode = m;

  @override
  Future<List<CategoryPlan>> categories() async => List.of(_cats);

  @override
  Future<void> saveCategoryPlan(CategoryPlan c) async {
    final i = _cats.indexWhere((e) => e.id == c.id);
    i < 0 ? _cats.add(c) : _cats[i] = c;
  }

  @override
  Future<List<LimitRow>> limits() async => List.of(_limits);

  @override
  Future<void> saveLimit(String categoryId, String month, int minor) async {
    _limits.removeWhere((l) => l.categoryId == categoryId && l.month == month);
    _limits.add(LimitRow(categoryId, month, minor));
  }

  @override
  Future<List<BudgetMove>> moves() async => List.of(_moves);

  @override
  Future<void> addMove(BudgetMove m) async => _moves.add(m);

  @override
  Future<void> undoMove(String id) async =>
      _moves.removeWhere((m) => m.id == id);
}

/// The default categories with their default groups.
List<CategoryPlan> defaultCategoryPlans() => [
  for (final c in defaultCategories)
    CategoryPlan(
      id: c.slug,
      group: BudgetGroup.resolve(
        null,
        isFixed: c.isFixed && c.kind == 'expense',
      ),
      kind: c.kind,
    ),
];

/// A believable demo budget for the current month and the two before it:
/// bills at set amounts, a flexible pool, and two sinking funds.
MemoryBudgetPlanStore demoBudgetPlanStore({DateTime? now}) {
  final n = now ?? DateTime.now();
  final start = monthIndex(monthKeyFor(n)) - 1;
  final limits = <LimitRow>[];
  const planned = {
    'rent': 625000,
    'telecom': 40000,
    'utilities': 70000,
    'groceries': 160000,
    'dining': 90000,
    'transport': 60000,
    'shopping': 100000,
    'entertainment': 40000,
    'health': 50000,
    'travel': 250000,
  };
  limits.addAll([
    for (final e in planned.entries)
      LimitRow(e.key, monthKeyOf(start), e.value),
  ]);
  final plans = defaultCategoryPlans().map((c) {
    return switch (c.id) {
      'travel' => c.copyWith(
        group: BudgetGroup.nonMonthly,
        cycleCostMinor: 3000000,
        cycleMonths: 12,
        rolloverStart: monthKeyOf(start),
      ),
      'education' => c.copyWith(
        group: BudgetGroup.nonMonthly,
        cycleCostMinor: 1800000,
        cycleMonths: 3,
        rolloverStart: monthKeyOf(start),
      ),
      'groceries' => c.copyWith(
        rollover: true,
        rolloverStart: monthKeyOf(start),
      ),
      _ => c,
    };
  }).toList();
  return MemoryBudgetPlanStore(categories: plans, limits: limits);
}
