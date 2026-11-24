/// Small shared value types of the engine. Pure Dart, no Flutter imports.
library;

enum Direction {
  debit,
  credit;

  static Direction? tryParse(String? s) => switch (s) {
    'debit' => Direction.debit,
    'credit' => Direction.credit,
    _ => null,
  };
}

/// How a transaction entered the system (wire names match the backend).
enum TxnSource {
  statement('statement'),
  sms('sms'),
  notification('notification'),
  appleShortcut('apple_shortcut'),
  googleWallet('google_wallet'),
  samsungWallet('samsung_wallet'),
  manual('manual');

  const TxnSource(this.wire);
  final String wire;

  static TxnSource? tryParse(String? s) {
    for (final v in values) {
      if (v.wire == s) return v;
    }
    return null;
  }
}

/// Amount in minor units (fils) rounded half-to-even from a decimal string
/// such as `1,234.50`. Returns null when it is not a number.
int? parseMinorUnits(String raw) {
  final s = raw.replaceAll(',', '').trim();
  final m = RegExp(r'^(\d*)(?:\.(\d*))?$').firstMatch(s);
  if (m == null || (m[1]!.isEmpty && (m[2] ?? '').isEmpty)) return null;
  final whole = BigInt.parse(m[1]!.isEmpty ? '0' : m[1]!);
  final frac = (m[2] ?? '');
  var minor = whole * BigInt.from(100);
  if (frac.isEmpty) return minor.toInt();
  final padded = frac.padRight(2, '0');
  minor += BigInt.parse(padded.substring(0, 2));
  if (padded.length > 2) {
    final rest = padded.substring(2);
    final first = int.parse(rest[0]);
    final tail = rest.substring(1).replaceAll('0', '');
    final lastIsOdd = minor.isOdd;
    if (first > 5 || (first == 5 && (tail.isNotEmpty || lastIsOdd))) {
      minor += BigInt.one;
    }
  }
  return minor.toInt();
}

/// Banker's rounding (half to even), like Python's `round` / Decimal default.
int roundHalfEven(double x) {
  final f = x.floorToDouble();
  final diff = x - f;
  if (diff < 0.5) return f.toInt();
  if (diff > 0.5) return f.toInt() + 1;
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// Python-style `format(x, '.Nf')`: exact binary ties round half to even.
String fmtFixed(double x, int digits) {
  final scale = _pow10(digits);
  final scaled = x * scale;
  if ((scaled - scaled.truncateToDouble()).abs() == 0.5) {
    final even = roundHalfEven(scaled);
    return (even / scale).toStringAsFixed(digits);
  }
  return x.toStringAsFixed(digits);
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}

/// `round(x, digits)` the way Python does it for the values we meet.
double roundTo(double x, int digits) {
  final scale = _pow10(digits);
  return roundHalfEven((x * scale * 1e6).round() / 1e6) / scale;
}

/// `f"{n:,}"`-style thousands grouping of an integer.
String groupThousands(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Stable sort (Dart's [List.sort] makes no stability promise).
List<T> stableSorted<T>(Iterable<T> items, int Function(T a, T b) compare) {
  final indexed = [for (final e in items.indexed) e];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// statistics.median of ints.
double median(List<num> values) {
  final s = [...values]..sort();
  final n = s.length;
  if (n.isOdd) return s[n ~/ 2].toDouble();
  return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
}
