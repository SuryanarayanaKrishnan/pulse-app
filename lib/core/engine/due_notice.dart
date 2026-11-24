/// Payment-due emails with no PDF, e.g. Tabby Card: "Due on 3 December",
/// "A no-fee minimum amount of 2,341.75 ...", "2,390.13 statement amount".
/// Amounts carry no currency (AED). Used as a monthly cross-check against the
/// per-purchase capture.
class DueNotice {
  const DueNotice(
    this.institution,
    this.dueDate,
    this.minDueMinor, [
    this.statementMinor,
  ]);
  final String institution;
  final DateTime dueDate;
  final int minDueMinor;
  final int? statementMinor;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, //
};

final _due = RegExp(
  r'due on (\d{1,2}) ([A-Za-z]{3,9})(?:,? (\d{4}))?',
  caseSensitive: false,
);
final _min = RegExp(
  r'no-fee minimum amount of\s+(\d[\d,]*(?:\.\d{1,2})?)',
  caseSensitive: false,
);
final _stmt = RegExp(
  r'(\d[\d,]*(?:\.\d{1,2})?)\s+statement amount',
  caseSensitive: false,
);

int _minor(String s) {
  final parts = s.replaceAll(',', '').split('.');
  final frac = parts.length > 1 ? parts[1] : '';
  return int.parse(parts[0]) * 100 + int.parse(('${frac}00').substring(0, 2));
}

/// The year is not printed: pick the next occurrence of that day on or after
/// the email date.
DueNotice? parseTabbyCardDue(String text, {required DateTime receivedAt}) {
  final t = text.replaceAll(RegExp(r'\s+'), ' ');
  final due = _due.firstMatch(t), min = _min.firstMatch(t);
  if (due == null || min == null) return null;
  final month = _months[due.group(2)!.substring(0, 3).toLowerCase()];
  if (month == null) return null;
  final day = int.parse(due.group(1)!);
  var year = due.group(3) != null ? int.parse(due.group(3)!) : receivedAt.year;
  var d = DateTime(year, month, day);
  if (d.month != month) return null;
  final today = DateTime(receivedAt.year, receivedAt.month, receivedAt.day);
  if (due.group(3) == null && d.isBefore(today))
    d = DateTime(year + 1, month, day);
  final stmt = _stmt.firstMatch(t);
  return DueNotice(
    'tabby',
    d,
    _minor(min.group(1)!),
    stmt == null ? null : _minor(stmt.group(1)!),
  );
}
