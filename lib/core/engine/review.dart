/// Swipe-to-review logic: what to show first, and the calm streak.
///
/// Pure Dart, no Flutter and no I/O, so it is easy to test.
library;

import 'dates.dart';

/// How sure Pulse is that a captured payment landed in the right category.
/// 0 to 1; below [unsureBelow] the payment goes to the front of the queue.
const unsureBelow = 0.5;

/// A rough confidence for a captured payment's category.
///
/// A rule you made (or a statement line) is the most reliable; a guess from a
/// text message is fair; no category, or "Other", is a shrug.
double categoryConfidence({
  required bool hasCategory,
  bool isOther = false,
  bool ruleApplied = false,
  bool fromStatement = false,
  bool learned = false,
}) {
  if (!hasCategory || isOther) return 0.25;
  if (ruleApplied) return 0.95;
  if (learned) return 0.8;
  if (fromStatement) return 0.85;
  return 0.7;
}

/// What the queue needs to know about one payment.
class ReviewCandidate {
  const ReviewCandidate({
    required this.id,
    required this.amount,
    required this.confidence,
    required this.date,
    this.reviewed = false,
  });
  final String id;

  /// Always positive.
  final double amount;
  final double confidence;
  final DateTime date;
  final bool reviewed;
}

/// The unreviewed payments, in the order to show them: the unsure ones first,
/// then the biggest amounts, then the least confident, then the newest.
/// Stable and deterministic: the same inputs always give the same order.
List<String> orderReviewQueue(Iterable<ReviewCandidate> items) {
  final open = [
    for (final i in items)
      if (!i.reviewed) i,
  ];
  int cmp(ReviewCandidate a, ReviewCandidate b) {
    final ua = a.confidence < unsureBelow, ub = b.confidence < unsureBelow;
    if (ua != ub) return ua ? -1 : 1;
    final byAmount = b.amount.abs().compareTo(a.amount.abs());
    if (byAmount != 0) return byAmount;
    final byConf = a.confidence.compareTo(b.confidence);
    if (byConf != 0) return byConf;
    final byDate = b.date.compareTo(a.date);
    return byDate != 0 ? byDate : a.id.compareTo(b.id);
  }

  open.sort(cmp);
  return [for (final i in open) i.id];
}

/// Days on which the inbox reached zero.
///
/// The streak is the run of consecutive days ending today, or ending
/// yesterday when today has not been cleared yet: a day that is still going
/// never breaks anything. Missing a day simply starts a new run.
int reviewStreak(Set<CalDate> zeroDays, CalDate today) {
  if (zeroDays.isEmpty) return 0;
  final iso = {for (final d in zeroDays) d.toIso()};
  var day = iso.contains(today.toIso()) ? today : today.addDays(-1);
  var n = 0;
  while (iso.contains(day.toIso())) {
    n++;
    day = day.addDays(-1);
  }
  return n;
}

/// Adds [today] and forgets days older than [keepDays] (the list stays tiny).
Set<CalDate> withInboxZero(Set<CalDate> days, CalDate today, {int keepDays = 400}) => {
  for (final d in days)
    if (today.daysSince(d) <= keepDays) d,
  today,
};

/// Stored form: ISO dates, comma separated.
String encodeZeroDays(Set<CalDate> days) {
  final sorted = days.toList()..sort();
  return sorted.map((d) => d.toIso()).join(',');
}

Set<CalDate> decodeZeroDays(String? s) {
  if (s == null || s.isEmpty) return {};
  final out = <CalDate>{};
  for (final part in s.split(',')) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(part.trim());
    if (m == null) continue;
    out.add(CalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
  }
  return out;
}

/// Calm wording for the streak. Null when there is nothing worth saying.
String? streakLabel(int days) => switch (days) {
  <= 0 => null,
  1 => '1 day at inbox zero',
  final n => '$n days at inbox zero',
};
