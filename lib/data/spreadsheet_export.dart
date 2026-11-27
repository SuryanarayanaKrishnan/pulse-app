import 'dart:typed_data';

import '../core/engine/sheet_export.dart';
import 'budget_plan_service.dart';
import 'models.dart';

String _day(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

double _aed(int minor) => minor / 100;

/// The month's budget, every column the Budget screen shows, one row per
/// category. Amounts are numbers (AED), so a sheet can total them.
SheetTable budgetTable(BudgetPlanView plan, List<SpendCategory> cats) {
  String name(String id) => cats
      .firstWhere((c) => c.id == id, orElse: () => SpendCategory(id, id))
      .label;
  final rows = <List<Cell>>[
    [
      'Category',
      'Monthly budget (AED)',
      'Spent this month (AED)',
      'Remaining (AED)',
      'Group',
      'Carried in (AED)',
      'Rolls over',
      'Moved in/out (AED)',
      'Yearly or cycle cost (AED)',
      'Cycle (months)',
      'Month',
    ],
    for (final r in plan.rows)
      [
        name(r.id),
        _aed(r.plannedMinor),
        _aed(r.spentMinor),
        _aed(r.remainingMinor),
        r.group.label,
        _aed(r.carryMinor ?? 0),
        r.config.rollover ? 'Yes' : 'No',
        _aed(r.movedMinor),
        r.config.cycleCostMinor > 0 ? _aed(r.config.cycleCostMinor) : null,
        r.config.cycleCostMinor > 0 ? r.config.cycleMonths : null,
        plan.month,
      ],
  ];
  return SheetTable('Budget', rows);
}

/// Every payment, newest first, with every field the app keeps. Amount is
/// always positive; Type says Expense or Income, as an imported ledger expects.
SheetTable transactionsTable(List<Transaction> txs) {
  final sorted = [...txs]..sort((a, b) => b.date.compareTo(a.date));
  return SheetTable('Transactions', [
    [
      'Date',
      'Description',
      'Category',
      'Amount (AED)',
      'Type',
      'Account',
      'Source',
      'Reviewed',
      'Excluded from budget',
      'Pending hold',
      'Notes',
    ],
    for (final t in sorted)
      [
        _day(t.date),
        t.merchant,
        t.category.label,
        t.amount,
        t.isIncome ? 'Income' : 'Expense',
        t.accountLabel,
        t.source.label,
        t.reviewed ? 'Yes' : 'No',
        t.excluded ? 'Yes' : 'No',
        t.pendingHold ? 'Yes' : 'No',
        t.receiptNotes ?? '',
      ],
  ]);
}

class SpreadsheetExport {
  const SpreadsheetExport._();

  /// One workbook: Budget and Transactions sheets.
  static Uint8List xlsx(
    BudgetPlanView? plan,
    List<SpendCategory> cats,
    List<Transaction> txs,
  ) => buildXlsx([
    if (plan != null) budgetTable(plan, cats),
    transactionsTable(txs),
  ]);

  static String budgetCsv(BudgetPlanView plan, List<SpendCategory> cats) =>
      buildCsv(budgetTable(plan, cats).rows);
  static String transactionsCsv(List<Transaction> txs) =>
      buildCsv(transactionsTable(txs).rows);
}
