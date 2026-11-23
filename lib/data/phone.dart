import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Normalises a phone number to E.164, assuming the UAE (+971) for national
/// formats. Returns null when it cannot be a valid number.
///
///   "050 123 4567"      -> +971501234567
///   "+971 50 123 4567"  -> +971501234567
///   "00971501234567"    -> +971501234567
///   "971501234567"      -> +971501234567
///   "+44 7700 900123"   -> +447700900123
String? toE164(String raw, {String defaultCountryCode = '971'}) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  final plus = s.startsWith('+');
  var digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  String e164;
  if (plus) {
    e164 = digits;
  } else if (digits.startsWith('00')) {
    e164 = digits.substring(2);
  } else if (digits.startsWith(defaultCountryCode) && digits.length >= 11) {
    e164 = digits;
  } else if (digits.startsWith('0')) {
    e164 = defaultCountryCode + digits.replaceFirst(RegExp(r'^0+'), '');
  } else if (digits.length == 9 && digits.startsWith('5')) {
    // UAE mobile without trunk prefix.
    e164 = defaultCountryCode + digits;
  } else {
    return null;
  }
  // E.164: max 15 digits, country code never starts with 0.
  if (e164.length < 8 || e164.length > 15 || e164.startsWith('0')) return null;
  return '+$e164';
}

/// SHA-256 (hex) of the E.164 number. This is all that leaves the device
/// when matching contacts against Pulse users.
String phoneHash(String e164) => sha256.convert(utf8.encode(e164)).toString();

/// Hash for a raw number, or null when it cannot be normalised.
String? hashPhone(String raw) {
  final e = toE164(raw);
  return e == null ? null : phoneHash(e);
}

/// Display format for UAE mobiles: "+971 50 123 4567". Others are returned
/// as E.164.
String formatPhone(String e164) {
  final m = RegExp(r'^\+971(\d{2})(\d{3})(\d{4})$').firstMatch(e164);
  if (m == null) return e164;
  return '+971 ${m[1]} ${m[2]} ${m[3]}';
}
