/// Credit-card due dates and pay-by nudges (pure). Total due is the
/// statement's closing balance; minimum due is the smaller figure printed on
/// it. Both shrink by payments made since the statement date. Port of
/// `app/services/dues.py`.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'rewards.dart' show daysInMonth;
import 'types.dart';

const utilisationInfoPct = 30.0;
const utilisationWarnPct = 70.0;

String aed(int minor) {
  final neg = minor < 0;
  final a = minor.abs();
  return '${neg ? '-' : ''}AED ${groupThousands(a ~/ 100)}.${(a % 100).toString().padLeft(2, '0')}';
}

class CardInput {
  const CardInput({
    required this.accountId,
    required this.name,
    this.last4,
    this.creditLimitMinor,
    this.dueDay,
    this.statementDate,
    this.dueDate,
    this.minDueMinor,
    this.totalDueMinor,
    this.paidSinceStatementMinor = 0,
    this.owedNowMinor,
  });
  final String accountId, name;
  final String? last4;
  final int? creditLimitMinor, dueDay;
  final CalDate? statementDate, dueDate;
  final int? minDueMinor, totalDueMinor;
  final int paidSinceStatementMinor;

  /// Live amount owed (statement + new spend - payments).
  final int? owedNowMinor;
}

class Nudge {
  const Nudge(this.level, this.message);

  /// urgent | warn | info
  final String level, message;
}

class CardDue {
  CardDue({
    required this.accountId,
    required this.name,
    required this.last4,
    required this.source,
    required this.statementDate,
    required this.dueDate,
    required this.daysLeft,
    required this.minimumDueMinor,
    required this.totalDueMinor,
    required this.remainingMinimumDueMinor,
    required this.remainingTotalDueMinor,
    required this.paidSinceStatementMinor,
    required this.status,
    required this.creditLimitMinor,
    required this.owedNowMinor,
    required this.utilisationPct,
    required this.availableCreditMinor,
  });
  final String accountId, name;
  final String? last4;

  /// statement | account_settings | none
  final String source;
  final CalDate? statementDate, dueDate;
  final int? daysLeft;
  final int? minimumDueMinor, totalDueMinor;
  final int? remainingMinimumDueMinor, remainingTotalDueMinor;
  final int paidSinceStatementMinor;

  /// overdue | due_soon | upcoming | paid | unknown
  final String status;
  final int? creditLimitMinor, owedNowMinor;
  final double? utilisationPct;
  final int? availableCreditMinor;
  List<Nudge> nudges = const [];
}

CalDate nextDueFromDay(CalDate today, int dueDay) {
  for (final offset in [0, 1]) {
    final idx = today.year * 12 + today.month - 1 + offset;
    final y = idx ~/ 12, m = idx % 12 + 1;
    final d = CalDate(y, m, math.min(dueDay, daysInMonth(y, m)));
    if (d >= today) return d;
  }
  throw StateError('unreachable');
}

CardDue cardDue(CardInput c, CalDate today) {
  var due = c.dueDate;
  var source = 'statement';
  if (due == null && c.dueDay != null && c.dueDay != 0) {
    due = nextDueFromDay(today, c.dueDay!);
    source = 'account_settings';
  }
  if (due == null) source = 'none';
  final hasAmounts = c.totalDueMinor != null && c.dueDate != null;
  final remTotal = c.totalDueMinor != null
      ? math.max(0, c.totalDueMinor! - c.paidSinceStatementMinor)
      : null;
  final remMin = c.minDueMinor != null
      ? math.max(0, c.minDueMinor! - c.paidSinceStatementMinor)
      : null;
  final daysLeft = due?.daysSince(today);
  final String status;
  if (hasAmounts && remTotal == 0) {
    status = 'paid';
  } else if (daysLeft == null) {
    status = 'unknown';
  } else if (daysLeft < 0 && hasAmounts) {
    status = 'overdue';
  } else if (daysLeft <= 5) {
    status = 'due_soon';
  } else {
    status = 'upcoming';
  }
  double? util;
  int? avail;
  if (c.creditLimitMinor != null && c.creditLimitMinor != 0 && c.owedNowMinor != null) {
    util = roundTo(math.max(0, c.owedNowMinor!) / c.creditLimitMinor! * 100, 1);
    avail = c.creditLimitMinor! - c.owedNowMinor!;
  }
  final out = CardDue(
    accountId: c.accountId,
    name: c.name,
    last4: c.last4,
    source: (hasAmounts || due != null) ? source : 'none',
    statementDate: c.statementDate,
    dueDate: due,
    daysLeft: daysLeft,
    minimumDueMinor: c.minDueMinor,
    totalDueMinor: c.totalDueMinor,
    remainingMinimumDueMinor: remMin,
    remainingTotalDueMinor: remTotal,
    paidSinceStatementMinor: c.paidSinceStatementMinor,
    status: status,
    creditLimitMinor: c.creditLimitMinor,
    owedNowMinor: c.owedNowMinor,
    utilisationPct: util,
    availableCreditMinor: avail,
  );
  out.nudges = nudges(out);
  return out;
}

List<Nudge> nudges(CardDue d) {
  final out = <Nudge>[];
  final label = d.name + (d.last4 != null ? ' ...${d.last4}' : '');
  if ((d.status == 'overdue' || d.status == 'due_soon') &&
      d.dueDate != null &&
      d.remainingTotalDueMinor != null) {
    final mn = aed(d.remainingMinimumDueMinor ?? 0);
    final total = aed(d.remainingTotalDueMinor!);
    if (d.status == 'overdue') {
      out.add(Nudge('urgent', '$label was due ${d.dueDate!.toIso()}: pay at least $mn now ($total clears the statement).'));
    } else {
      final left = d.daysLeft ?? 0;
      final level = left <= 2 ? 'urgent' : 'warn';
      final when = left == 0 ? 'today' : 'in $left day${left != 1 ? 's' : ''}';
      out.add(Nudge(level, '$label is due $when (${d.dueDate!.toIso()}): minimum $mn, full statement $total.'));
    }
  } else if (d.status == 'due_soon' && d.dueDate != null) {
    out.add(Nudge('warn', '$label is due ${d.dueDate!.toIso()}; add the statement for exact amounts.'));
  }
  final u = d.utilisationPct;
  if (u != null) {
    if (u >= utilisationWarnPct) {
      out.add(Nudge('warn', '$label is ${fmtFixed(u, 0)}% of its limit used.'));
    } else if (u >= utilisationInfoPct) {
      out.add(Nudge('info', '$label is ${fmtFixed(u, 0)}% used; keeping cards under ${fmtFixed(utilisationInfoPct, 0)}% of the limit is commonly advised.'));
    }
  }
  return out;
}
