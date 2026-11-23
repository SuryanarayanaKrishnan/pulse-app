import 'package:intl/intl.dart';

/// AED formatting helpers.
class Money {
  const Money._();

  static final _whole = NumberFormat('#,##0', 'en_US');
  static final _dec = NumberFormat('#,##0.00', 'en_US');
  static final _compact = NumberFormat.compact(locale: 'en_US');

  /// "AED 1,234.50" (or "AED 1,235" when [decimals] is false).
  static String aed(num value, {bool decimals = true, bool sign = false}) {
    final abs = value.abs();
    final body = decimals ? _dec.format(abs) : _whole.format(abs);
    final prefix = value < 0 ? '-' : (sign && value > 0 ? '+' : '');
    return '${prefix}AED $body';
  }

  /// Number only, no currency prefix.
  static String number(num value, {bool decimals = false}) =>
      (decimals ? _dec : _whole).format(value);

  /// "1.2M", "45K".
  static String compact(num value) => _compact.format(value);

  /// "AED 1.2M".
  static String aedCompact(num value) => 'AED ${compact(value)}';
}
