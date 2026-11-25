/// Date helpers shared by the SMS parsers. UAE formats are day-first and the
/// UAE has no DST, so a fixed +04:00 offset is exact.
library;

const dubaiOffset = Duration(hours: 4);

/// Pattern fragment matching every supported format (no capture groups).
const dateRe =
    r'(?:\d{4}-\d{2}-\d{2}'
    r'|\d{1,2}[/.\-]\d{1,2}[/.\-]\d{2,4}'
    r'|\d{1,2}[\s\-]?[A-Za-z]{3,9}[\s\-,]*\d{2,4})';

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

final _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _numeric = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{2,4})$');
final _named = RegExp(r'^(\d{1,2})[\s\-]?([A-Za-z]{3,9})[\s\-,]*(\d{2,4})$');

int _year(String y) {
  final n = int.parse(y);
  return y.length == 2 ? n + 2000 : n;
}

/// A calendar date without a time zone (year, month, day).
class CalDate implements Comparable<CalDate> {
  const CalDate(this.year, this.month, this.day);
  final int year, month, day;

  DateTime toUtcMidnight() => DateTime.utc(year, month, day);

  /// Whole days from [other] to this date.
  int daysSince(CalDate other) =>
      toUtcMidnight().difference(other.toUtcMidnight()).inDays;

  CalDate addDays(int n) {
    final d = toUtcMidnight().add(Duration(days: n));
    return CalDate(d.year, d.month, d.day);
  }

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(CalDate other) => toUtcMidnight().compareTo(other.toUtcMidnight());
  bool operator <(CalDate o) => compareTo(o) < 0;
  bool operator >(CalDate o) => compareTo(o) > 0;
  bool operator <=(CalDate o) => compareTo(o) <= 0;
  bool operator >=(CalDate o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) =>
      other is CalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;
  @override
  int get hashCode => Object.hash(year, month, day);
  @override
  String toString() => toIso();

  static CalDate parse(String iso) {
    final m = _iso.firstMatch(iso)!;
    return CalDate(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
}

bool _valid(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1) return false;
  return d <= DateTime.utc(y, m + 1, 0).day;
}

/// Parses the date formats UAE banks use; null when invalid.
CalDate? parseDate(String value) {
  final s = value.trim();
  CalDate? mk(int y, int m, int d) => _valid(y, m, d) ? CalDate(y, m, d) : null;
  var m = _iso.firstMatch(s);
  if (m != null) return mk(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = _numeric.firstMatch(s);
  if (m != null) return mk(_year(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  m = _named.firstMatch(s);
  if (m != null) {
    final month = _months[m[2]!.substring(0, 3).toLowerCase()];
    if (month != null) return mk(_year(m[3]!), month, int.parse(m[1]!));
  }
  return null;
}

/// The Dubai calendar date of an instant.
CalDate toDubaiDate(DateTime dt) {
  final d = dt.toUtc().add(dubaiOffset);
  return CalDate(d.year, d.month, d.day);
}

/// A timestamp on day [d] (Dubai): keeps [near]'s time when it is the same
/// day, else noon.
DateTime atDate(CalDate d, [DateTime? near]) {
  if (near != null && toDubaiDate(near) == d) return near;
  return DateTime.utc(d.year, d.month, d.day, 12).subtract(dubaiOffset);
}
