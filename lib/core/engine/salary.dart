/// Salary detection from transaction descriptors and the recurring-salary
/// summary. Detection is deliberately conservative: a *credit* whose
/// descriptor carries a salary marker ("SALARY", "PAYROLL", "WPS" / "Wage
/// Protection System", "SAL CR") and is not an advance/loan/reversal. Port of
/// `app/services/salary.py`.
library;

import 'dart:math' as math;

import 'dates.dart';
import 'merchants.dart' show pythonTitle;
import 'rewards.dart' show daysInMonth;
import 'types.dart';

/// AED 500: below this a "salary" credit is almost certainly a fee refund.
const minSalaryMinor = 50000;

final _markers = <(String, RegExp)>[
  ('wps', RegExp(r'\bWPS\b|WAGE\s+PROTECTION')),
  ('payroll', RegExp(r'\bPAY\s?ROLL\b')),
  (
    'salary',
    RegExp(r'\bSALAR(?:Y|IES)\b|\bSAL\.?\s?(?:CR\b|CREDIT)|\bSALARY\b'),
  ),
];
final _notSalary = RegExp(
  r'\b(?:ADVANCE|LOAN|REVERS(?:AL|ED)|REFUND|FEE|CHARGE|CERTIFICATE|RETURN(?:ED)?|REJECT(?:ED)?)\b',
);
final _noise = RegExp(
  r'\b(?:WPS|PAY\s?ROLL|SALAR(?:Y|IES)|SAL|CR|CREDIT(?:ED)?|TRANSFER|TRF|PAYMENT|PMT|DEPOSIT|FOR|THE|MONTH|OF|'
  r'FROM|FRM|BY|REF|REFERENCE|NO|WAGE|PROTECTION|SYSTEM|INWARD|LOCAL|IPI|ACCOUNT|A/C|AC|ADCB|ENBD|FAB|MASHREQ)\b',
);
final _month = RegExp(
  r'\b(?:JAN(?:UARY)?|FEB(?:RUARY)?|MAR(?:CH)?|APR(?:IL)?|MAY|JUN(?:E)?|JUL(?:Y)?|AUG(?:UST)?|'
  r'SEP(?:T(?:EMBER)?)?|OCT(?:OBER)?|NOV(?:EMBER)?|DEC(?:EMBER)?)\b',
);
final _afterFrom = RegExp(r'\b(?:FROM|FRM|BY)\b\s*(.+)$');
final _stop = RegExp(
  r'\b(?:ON|AT|REF|DATED|VALUE|AVL|AVAILABLE|BAL(?:ANCE)?|TO|YOUR|ACCOUNT)\b|[.,;]\s|\.$',
);
const _acronyms = {
  'LLC',
  'FZE',
  'FZ',
  'FZCO',
  'FZ-LLC',
  'PJSC',
  'LTD',
  'PLC',
  'UAE',
  'DMCC',
  'WLL',
  'LLP',
  'INC',
};
final _ws = RegExp(r'\s+');

class SalaryMatch {
  const SalaryMatch(this.matchedBy, this.employer);
  final String matchedBy;
  final String? employer;
}

String? _employer(String text, {required bool allowBare}) {
  final upper = text.toUpperCase().replaceAll(_ws, ' ').trim();
  final m = _afterFrom.firstMatch(upper);
  String candidate;
  if (m != null) {
    candidate = m.group(1)!.split(_stop).first;
  } else if (allowBare) {
    candidate = upper;
  } else {
    return null;
  }
  candidate = candidate.replaceAll(_month, ' ');
  candidate = candidate.replaceAll(
    RegExp(
      r'\b(?:19|20)\d{2}\b|\b\d{2}[/.\-]\d{2}[/.\-]\d{2,4}\b|[#*]?\b\d{4,}\b',
    ),
    ' ',
  );
  candidate = candidate.replaceAll(_noise, ' ');
  candidate = candidate.replaceAll(RegExp(r"[^A-Z&.'() ]+"), ' ');
  candidate = candidate.replaceAll(_ws, ' ').trim();
  candidate = _strip(candidate, ' .-&');
  if (candidate.replaceAll(RegExp(r'[^A-Z]'), '').length < 3) return null;
  final words = [
    for (final w in candidate.split(' '))
      if (_acronyms.contains(w) || w.length <= 3) w else pythonTitle(w),
  ];
  final joined = words.join(' ');
  return joined.length > 160 ? joined.substring(0, 160) : joined;
}

String _strip(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

/// Is this credit a salary payment? [description] is the bank descriptor /
/// statement line, [smsText] the full message when it came from an SMS (often
/// "Salary credited..." with no merchant at all).
SalaryMatch? detectSalary(
  String? description,
  Direction? direction,
  int? amountMinor, [
  String? smsText,
]) {
  if (direction != Direction.credit) return null;
  if (amountMinor != null && amountMinor < minSalaryMinor) return null;
  final text = [description, smsText]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' ')
      .toUpperCase()
      .replaceAll(_ws, ' ');
  if (text.isEmpty || _notSalary.hasMatch(text)) return null;
  for (final (name, pattern) in _markers) {
    if (pattern.hasMatch(text)) {
      final employer = (description != null && description.isNotEmpty)
          ? _employer(description, allowBare: true)
          : null;
      return SalaryMatch(
        name,
        employer ??
            (smsText != null && smsText.isNotEmpty
                ? _employer(smsText, allowBare: false)
                : null),
      );
    }
  }
  return null;
}

class SalaryPayment {
  const SalaryPayment(
    this.receivedOn,
    this.amountMinor,
    this.employer,
    this.currency,
  );
  final CalDate receivedOn;
  final int amountMinor;
  final String? employer;
  final String currency;
}

class SalarySummary {
  const SalarySummary({
    required this.currency,
    required this.monthsObserved,
    required this.isRecurring,
    required this.averageMonthlyMinor,
    required this.typicalDay,
    required this.nextExpectedOn,
    required this.latestMonthMinor,
    required this.previousMonthMinor,
    required this.monthly,
    required this.employers,
  });
  final String? currency;
  final int monthsObserved;
  final bool isRecurring;
  final int? averageMonthlyMinor, typicalDay;
  final CalDate? nextExpectedOn;
  final int? latestMonthMinor, previousMonthMinor;

  /// (first of month, total), newest first.
  final List<(CalDate, int)> monthly;

  /// (employer, payments, latest amount), most recent first.
  final List<(String?, int, int)> employers;
}

CalDate _clampDay(int year, int month, int day) =>
    CalDate(year, month, math.min(day, daysInMonth(year, month)));

/// Recurring-salary summary over the payments of the user's dominant
/// currency.
SalarySummary summariseSalary(
  List<SalaryPayment> payments,
  CalDate today, {
  int averageOver = 3,
}) {
  if (payments.isEmpty) {
    return const SalarySummary(
      currency: null,
      monthsObserved: 0,
      isRecurring: false,
      averageMonthlyMinor: null,
      typicalDay: null,
      nextExpectedOn: null,
      latestMonthMinor: null,
      previousMonthMinor: null,
      monthly: [],
      employers: [],
    );
  }
  final counts = <String, int>{};
  for (final p in payments) {
    counts[p.currency] = (counts[p.currency] ?? 0) + 1;
  }
  var currency = counts.keys.first;
  for (final e in counts.entries) {
    if (e.value > counts[currency]!) currency = e.key;
  }
  final pays = stableSorted(
    payments.where((p) => p.currency == currency),
    (a, b) => b.receivedOn.compareTo(a.receivedOn),
  );
  final totals = <CalDate, int>{};
  for (final p in pays) {
    final m = CalDate(p.receivedOn.year, p.receivedOn.month, 1);
    totals[m] = (totals[m] ?? 0) + p.amountMinor;
  }
  final monthly = stableSorted(
    totals.entries,
    (a, b) => b.key.compareTo(a.key),
  );
  final recent = [for (final e in monthly.take(averageOver)) e.value];
  final byEmployer = <String?, List<SalaryPayment>>{};
  for (final p in pays) {
    byEmployer.putIfAbsent(p.employer, () => []).add(p);
  }
  List<SalaryPayment>? main;
  for (final ps in byEmployer.values) {
    if (main == null ||
        ps.length > main.length ||
        (ps.length == main.length &&
            ps.first.receivedOn > main.first.receivedOn)) {
      main = ps;
    }
  }
  final typicalDay = median([for (final p in main!.take(6)) p.receivedOn.day])
      .truncate();
  final latest = monthly.first.key;
  final candidate = _clampDay(
    latest.year + (latest.month == 12 ? 1 : 0),
    latest.month % 12 + 1,
    typicalDay,
  );
  final recurring = monthly.length >= 2;
  final nextExpected = recurring && candidate >= today.addDays(-10)
      ? candidate
      : null;
  final employers = stableSorted(
    byEmployer.entries,
    (a, b) => b.value.first.receivedOn.compareTo(a.value.first.receivedOn),
  );
  return SalarySummary(
    currency: currency,
    monthsObserved: monthly.length,
    isRecurring: recurring,
    averageMonthlyMinor: roundHalfEven(
      recent.fold<int>(0, (a, b) => a + b) / recent.length,
    ),
    typicalDay: typicalDay,
    nextExpectedOn: nextExpected,
    latestMonthMinor: monthly.first.value,
    previousMonthMinor: monthly.length > 1 ? monthly[1].value : null,
    monthly: [for (final e in monthly) (e.key, e.value)],
    employers: [
      for (final e in employers)
        (e.key, e.value.length, e.value.first.amountMinor),
    ],
  );
}
