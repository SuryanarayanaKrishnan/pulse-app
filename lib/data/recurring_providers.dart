import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import '../core/engine/dates.dart';
import '../core/engine/nw_history.dart';
import '../core/engine/recurring.dart';
import '../core/engine/recurring_plan.dart';
import '../core/engine/spend_report.dart';
import '../core/household/household_engine.dart' show billShares;
import '../household/household_providers.dart';
import 'providers.dart';
import 'recurring_service.dart';
import 'repository.dart';

/// "Today" for these screens (Dubai calendar). Overridden in tests.
final recurringTodayProvider = Provider<CalDate>((ref) => toDubaiDate(DateTime.now()));

final recurringStoreProvider = Provider<RecurringStore>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return db == null ? MemoryRecurringStore() : DriftRecurringStore(db);
});

/// Confirm / ignore verdicts, with the setter.
class RecurringChoicesNotifier extends AsyncNotifier<Map<String, RecChoice>> {
  @override
  Future<Map<String, RecChoice>> build() => ref.watch(recurringStoreProvider).choices();

  Future<void> choose(Series s, RecChoice? choice) async {
    await ref.read(recurringStoreProvider).setChoice(s.key, choice, merchant: s.merchant);
    state = AsyncData(await ref.read(recurringStoreProvider).choices());
    // The projected bills in Safe to spend depend on what is ignored.
    ref.invalidate(safeToSpendProvider);
    ref.invalidate(cashflowProvider);
    if (choice == RecChoice.confirmed) {
      ref.read(analyticsProvider).track(AnalyticsEvent.recurringConfirmed(s.cadence));
    }
  }
}

final recurringChoicesProvider =
    AsyncNotifierProvider<RecurringChoicesNotifier, Map<String, RecChoice>>(RecurringChoicesNotifier.new);

final recurringChargesProvider = FutureProvider<List<Charge>>(
  (ref) async => chargesFrom(await ref.watch(transactionsProvider.future)),
);

final recurringSeriesProvider = FutureProvider<List<Series>>((ref) async {
  final charges = await ref.watch(recurringChargesProvider.future);
  return detect(charges, ref.watch(recurringTodayProvider));
});

/// The month the Recurring screen shows (first of month).
class RecurringMonthNotifier extends Notifier<CalDate> {
  @override
  CalDate build() => monthStart(ref.watch(recurringTodayProvider));
  void set(CalDate d) => state = monthStart(d);
}

final recurringMonthSelectionProvider = NotifierProvider<RecurringMonthNotifier, CalDate>(RecurringMonthNotifier.new);

final recurringMonthProvider = FutureProvider<RecurringMonth>((ref) async {
  final today = ref.watch(recurringTodayProvider);
  final month = ref.watch(recurringMonthSelectionProvider);
  final (series, charges, choices, cards, joint) = await (
    ref.watch(recurringSeriesProvider.future),
    ref.watch(recurringChargesProvider.future),
    ref.watch(recurringChoicesProvider.future),
    ref.watch(myCardsProvider.future),
    ref.watch(jointDataProvider.future),
  ).wait;
  return planMonth(
    series: series,
    charges: charges,
    today: today,
    anyDay: month,
    choices: choices,
    cardDues: [
      for (final c in cards)
        if (c.totalDue > 0) CardDueInput(c.id, '${c.issuer} ${c.name}', toDubaiDate(c.dueDate), (c.totalDue * 100).round()),
    ],
    bills: [
      if (joint != null)
        for (final b in joint.bills)
          BillInput(b.id, b.name, b.dueDay, billShares(b)[joint.me] ?? 0),
    ],
  );
});

/// Net worth by day: the repository's own history, or the month-end series
/// spread across days.
final netWorthHistoryProvider = FutureProvider<List<NwPoint>>((ref) async {
  final repo = ref.watch(repositoryProvider);
  if (repo is NetWorthHistorySource) return (repo as NetWorthHistorySource).netWorthHistory();
  final nw = await ref.watch(netWorthProvider.future);
  final today = ref.watch(recurringTodayProvider);
  final n = nw.series.length;
  return [
    for (var i = 0; i < n; i++)
      NwPoint(
        CalDate(today.year, today.month - (n - 1 - i), 1).addDays(i == n - 1 ? today.day - 1 : 27),
        (nw.series[i] * 100).round(),
        0,
      ),
  ];
});

class NwRangeNotifier extends Notifier<NwRange> {
  @override
  NwRange build() => NwRange.m6;
  void set(NwRange r) => state = r;
}

/// The chip the net worth chart is on; it stays while the app is open.
final nwRangeProvider = NotifierProvider<NwRangeNotifier, NwRange>(NwRangeNotifier.new);

/// Reports: the chosen span and how many months back it ends.
class ReportSpanNotifier extends Notifier<ReportSpan> {
  @override
  ReportSpan build() => ReportSpan.month;
  void set(ReportSpan s) => state = s;
}

final reportSpanProvider = NotifierProvider<ReportSpanNotifier, ReportSpan>(ReportSpanNotifier.new);

class ReportEndNotifier extends Notifier<CalDate> {
  @override
  CalDate build() => monthStart(ref.watch(recurringTodayProvider));
  void set(CalDate d) => state = monthStart(d);
}

/// The last month of the range (first of that month).
final reportEndProvider = NotifierProvider<ReportEndNotifier, CalDate>(ReportEndNotifier.new);

final spendRowsProvider = FutureProvider<List<SpendRow>>(
  (ref) async => spendRowsFrom(await ref.watch(transactionsProvider.future)),
);
