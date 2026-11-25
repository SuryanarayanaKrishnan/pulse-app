import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/providers.dart';
import '../../core/engine/dates.dart';
import '../../core/engine/review.dart';
import '../../data/models.dart';
import '../../data/providers.dart';

/// Now, as a function so tests can move the clock.
final reviewClockProvider = Provider<DateTime Function()>((_) => DateTime.now);

const _kvKey = 'review.zero_days';

/// The unreviewed payments in review order (see [orderReviewQueue]).
final reviewQueueProvider = FutureProvider<List<Transaction>>((ref) async {
  final txs = await ref.watch(transactionsProvider.future);
  final byId = {for (final t in txs) t.id: t};
  final order = orderReviewQueue([
    for (final t in txs)
      ReviewCandidate(
        id: t.id,
        amount: t.amount,
        confidence: t.confidence,
        date: t.date,
        reviewed: t.reviewed,
      ),
  ]);
  return [for (final id in order) byId[id]!];
});

/// How many payments are waiting.
final reviewCountProvider = Provider<AsyncValue<int>>(
  (ref) => ref.watch(reviewQueueProvider).whenData((q) => q.length),
);

/// Days the inbox reached zero. Kept on this device only.
class ReviewDaysController extends AsyncNotifier<Set<CalDate>> {
  @override
  Future<Set<CalDate>> build() async =>
      decodeZeroDays(await ref.read(kvStoreProvider).read(_kvKey));

  CalDate get _today => toDubaiDate(ref.read(reviewClockProvider)());

  /// Today counts as an inbox-zero day.
  Future<void> markToday() async {
    final days = withInboxZero(await future, _today);
    state = AsyncData(days);
    await ref.read(kvStoreProvider).write(_kvKey, encodeZeroDays(days));
  }
}

final reviewDaysProvider =
    AsyncNotifierProvider<ReviewDaysController, Set<CalDate>>(ReviewDaysController.new);

/// The current streak, in days.
final reviewStreakProvider = Provider<int>((ref) {
  final days = ref.watch(reviewDaysProvider).value;
  if (days == null) return 0;
  return reviewStreak(days, toDubaiDate(ref.watch(reviewClockProvider)()));
});

/// A calm one-liner about what the card earns, or null when it earns nothing
/// worth saying (cash, a bank account, income).
String? rewardsNote(Transaction tx, List<CreditCard> cards) {
  if (tx.isIncome) return null;
  final card = cards.where((c) => c.id == tx.cardId).firstOrNull;
  if (card == null) return null;
  final rate = card.categoryRates[tx.category] ?? card.baseRate;
  if (rate <= 0) return null;
  final earned = tx.amount * rate / 100;
  final amount = earned >= 10 ? earned.toStringAsFixed(0) : earned.toStringAsFixed(2);
  return 'Earns about AED $amount on ${card.name} (${_pct(rate)})';
}

String _pct(double r) =>
    '${r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1)}%';
