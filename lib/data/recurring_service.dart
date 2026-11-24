import 'package:drift/drift.dart';

import '../core/engine/dates.dart';
import '../core/engine/merchants.dart' show merchantKey;
import '../core/engine/recurring.dart' show Charge;
import '../core/engine/recurring_plan.dart';
import '../core/engine/spend_report.dart';
import 'local/database.dart';
import 'models.dart';

/// Where the user's confirm / ignore verdicts live.
abstract interface class RecurringStore {
  Future<Map<String, RecChoice>> choices();

  /// Records [choice] for [seriesKey]; null clears it.
  Future<void> setChoice(String seriesKey, RecChoice? choice, {String merchant = ''});
}

class DriftRecurringStore implements RecurringStore {
  DriftRecurringStore(this.db);
  final PulseDatabase db;

  @override
  Future<Map<String, RecChoice>> choices() async => {
    for (final r in await db.select(db.recurringChoices).get())
      if (RecChoice.tryParse(r.choice) != null) r.seriesKey: RecChoice.tryParse(r.choice)!,
  };

  @override
  Future<void> setChoice(String seriesKey, RecChoice? choice, {String merchant = ''}) async {
    if (choice == null) {
      await (db.delete(db.recurringChoices)..where((t) => t.seriesKey.equals(seriesKey))).go();
      return;
    }
    var name = merchant;
    if (name.isEmpty) {
      name = (await (db.select(db.recurringChoices)..where((t) => t.seriesKey.equals(seriesKey))).getSingleOrNull())?.merchant ?? '';
    }
    await db.into(db.recurringChoices).insertOnConflictUpdate(
      RecurringChoicesCompanion(
        seriesKey: Value(seriesKey),
        choice: Value(choice.name),
        merchant: Value(name),
        decidedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}

/// For demo data and tests: choices last until the app closes.
class MemoryRecurringStore implements RecurringStore {
  final _m = <String, RecChoice>{};

  @override
  Future<Map<String, RecChoice>> choices() async => Map.of(_m);

  @override
  Future<void> setChoice(String seriesKey, RecChoice? choice, {String merchant = ''}) async {
    if (choice == null) {
      _m.remove(seriesKey);
    } else {
      _m[seriesKey] = choice;
    }
  }
}

/// Spending as the detector sees it: debits that are not excluded, income or
/// transfers, keyed by normalised merchant.
List<Charge> chargesFrom(Iterable<Transaction> txs) => [
  for (final t in txs)
    if (!t.isIncome && !t.excluded && !t.category.isIncome)
      if (merchantKey(t.merchant) case final key?)
        Charge(toDubaiDate(t.date), (t.amount * 100).round(), t.merchant, key, t.category.id),
];

/// Spend rows for the Reports page: expense-category debits that are not
/// excluded (card payments and transfers are not spend).
List<SpendRow> spendRowsFrom(Iterable<Transaction> txs) => [
  for (final t in txs)
    if (!t.isIncome && !t.excluded && !t.category.isIncome && !t.category.isTransfer)
      SpendRow(
        date: toDubaiDate(t.date),
        amountMinor: (t.amount * 100).round(),
        categoryId: t.category.id,
        merchant: t.merchant,
      ),
];
