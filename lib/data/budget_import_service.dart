import '../core/engine/budget_suggest.dart';
import '../core/engine/flex_budget.dart' show monthKeyFor;
import '../core/engine/sheet_import.dart';
import 'budget_plan_service.dart';
import 'models.dart';
import 'repository.dart';

/// Where one of the sheet's labels ends up.
sealed class ImportTarget {
  const ImportTarget();
}

/// One of Pulse's (or the user's existing) categories.
class ExistingTarget extends ImportTarget {
  const ExistingTarget(this.category);
  final SpendCategory category;
}

/// A new category with the sheet's own name, so nothing is merged away.
class NewTarget extends ImportTarget {
  const NewTarget(this.name);
  final String name;
}

class SkipTarget extends ImportTarget {
  const SkipTarget();
}

class LabelMapping {
  LabelMapping(this.label, this.target, {required this.sure});
  final SheetLabel label;
  ImportTarget target;

  /// Matched on the category's own name or an alias, not a guess.
  final bool sure;
}

class ImportResult {
  const ImportResult({
    required this.limitsSet,
    required this.categoriesCreated,
    required this.transactionsAdded,
    required this.transactionsSkipped,
  });
  final int limitsSet, categoriesCreated, transactionsAdded, transactionsSkipped;
}

/// Turns a sheet analysis into Pulse categories, monthly limits and history,
/// and applies a suggested budget. The reading itself is in `core/engine`.
class BudgetImportService {
  BudgetImportService({required this.repo, required this.plan});
  final PulseRepository repo;
  final BudgetPlanService plan;

  /// A typical month of spending per category from the ledger, in fils.
  Future<Map<String, int>> historyByCategory() async {
    final byMonth = BudgetPlanService.spendByMonth(await repo.transactions());
    final now = monthKeyFor(DateTime.now());
    // This month is not finished; leave it out.
    return typicalMonthly({
      for (final e in byMonth.entries) e.key: {for (final m in e.value.entries) if (m.key != now) m.key: m.value},
    });
  }

  /// Sets the suggested amounts as monthly limits from [month] on.
  Future<int> applySuggestion(SuggestedBudget s, DateTime month) async {
    var n = 0;
    for (final l in s.lines) {
      if (l.amountMinor <= 0) continue;
      await plan.setMonthly(l.categoryId, month, l.amountMinor);
      n++;
    }
    return n;
  }

  /// Default mapping for every label in [a]. With [keepOwnNames] only a label
  /// that is already a category's own name goes to it; every other label becomes a category of
  /// its own, so a detailed sheet keeps its detail.
  Future<List<LabelMapping>> proposeMappings(SheetAnalysis a, {bool keepOwnNames = false}) async {
    final custom = await repo.categories();
    final byName = {for (final c in [...SpendCategory.defaults, ...custom]) _n(c.label): c};
    final out = <LabelMapping>[];
    for (final l in a.orderedLabels) {
      final own = byName[_n(l.label)];
      if (own != null) {
        out.add(LabelMapping(l, ExistingTarget(own), sure: true));
        continue;
      }
      final m = matchCategory(l.label, income: l.isIncome);
      final cat = m == null ? null : _defaultById(m.id);
      if (cat != null && !keepOwnNames) {
        out.add(LabelMapping(l, ExistingTarget(cat), sure: m!.exact));
      } else {
        out.add(LabelMapping(l, NewTarget(l.label), sure: false));
      }
    }
    return out;
  }

  static const _otherIncome = SpendCategory('other_income', 'Other Income', kind: CategoryKind.income);
  static SpendCategory? _defaultById(String id) =>
      id == 'other_income' ? _otherIncome : SpendCategory.defaults.where((c) => c.id == id).firstOrNull;

  static String _n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Writes the plan: new categories, monthly limits where the amount
  /// changes (a limit carries forward until the next one), and history.
  Future<ImportResult> apply(
    SheetAnalysis a,
    List<LabelMapping> mappings, {
    bool importHistory = true,
  }) async {
    // Resolve targets, creating each new category once.
    final created = <String, SpendCategory>{};
    final resolved = <String, SpendCategory>{};
    var newCats = 0;
    for (final m in mappings) {
      final t = m.target;
      if (t is SkipTarget) continue;
      if (t is ExistingTarget) {
        resolved[_k(m.label)] = t.category;
      } else if (t is NewTarget) {
        final name = t.name.trim();
        var c = created[_n(name)];
        if (c == null) {
          c = await repo.createCategory(
            name: name,
            kind: m.label.isIncome ? CategoryKind.income : CategoryKind.expense,
          );
          created[_n(name)] = c;
          newCats++;
        }
        resolved[_k(m.label)] = c;
      }
    }

    // Limits: sum the labels that share a category, then write changes only.
    final perCat = <String, Map<String, int>>{};
    for (final m in mappings) {
      final cat = resolved[_k(m.label)];
      if (cat == null || cat.isIncome || cat.isTransfer) continue;
      final sums = perCat.putIfAbsent(cat.id, () => {});
      m.label.budget.forEach((month, v) => sums[month] = (sums[month] ?? 0) + v);
    }
    var limits = 0;
    for (final e in perCat.entries) {
      final months = e.value.keys.toList()..sort();
      int? prev;
      for (final month in months) {
        final v = e.value[month]!;
        if (v == prev) continue;
        prev = v;
        final y = int.parse(month.substring(0, 4)), mo = int.parse(month.substring(5, 7));
        await plan.setMonthly(e.key, DateTime(y, mo), v);
        limits++;
      }
    }

    // History: ledger payments, or a grid's Actual rows as one entry per month.
    var added = 0, skipped = 0;
    if (importHistory) {
      final txs = <ImportedTransaction>[];
      for (final t in a.transactions) {
        final cat = resolved[_n(t.label)];
        if (cat == null) continue;
        txs.add(ImportedTransaction(
          date: t.date,
          merchant: t.note.isNotEmpty ? '${t.label} · ${t.note}' : t.label,
          amountMinor: t.minor,
          category: cat,
          isIncome: t.isIncome || cat.isIncome,
        ));
      }
      for (final m in mappings) {
        final cat = resolved[_k(m.label)];
        if (cat == null) continue;
        m.label.actual.forEach((month, v) {
          if (v <= 0) return;
          final y = int.parse(month.substring(0, 4)), mo = int.parse(month.substring(5, 7));
          txs.add(ImportedTransaction(
            date: DateTime(y, mo, 15),
            merchant: '${m.label.label} (from your sheet)',
            amountMinor: v,
            category: cat,
            isIncome: m.label.isIncome || cat.isIncome,
          ));
        });
      }
      added = await repo.importTransactions(txs);
      skipped = txs.length - added;
    }
    return ImportResult(
      limitsSet: limits,
      categoriesCreated: newCats,
      transactionsAdded: added,
      transactionsSkipped: skipped,
    );
  }

  static String _k(SheetLabel l) => _n(l.label);
}
