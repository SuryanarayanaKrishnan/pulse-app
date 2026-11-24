/// The invite: how a second phone learns the household id and key.
///
/// The code is the secret. It is shown on the inviting phone (as text and a
/// QR code) and typed or pasted on the other; it never goes through the
/// server, which only ever stores ciphertext made with the key inside it.
/// Anyone who sees the code can read the household log, so it is meant to
/// be passed in person or over a channel you trust.
///
/// Layout (45+ bytes, base32): version(1) | household id(16) | key(32) |
/// checksum(4, first bytes of SHA-256 over the rest) so a mistyped code is
/// caught before anything is created.
library;

import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class HouseholdInvite {
  HouseholdInvite({required this.householdId, required List<int> key})
    : key = Uint8List.fromList(key) {
    if (householdId.length != 32 || !RegExp(r'^[0-9a-f]{32}$').hasMatch(householdId)) {
      throw const FormatException('Household id');
    }
    if (key.length != 32) throw const FormatException('Household key');
  }

  /// 32 lowercase hex characters.
  final String householdId;
  final Uint8List key;

  static const _prefix = 'PULSE-HH1';
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  Uint8List _bytes() {
    final id = <int>[
      for (var i = 0; i < 32; i += 2) int.parse(householdId.substring(i, i + 2), radix: 16),
    ];
    final body = [1, ...id, ...key];
    final sum = sha256.convert(body).bytes.sublist(0, 4);
    return Uint8List.fromList([...body, ...sum]);
  }

  /// `PULSE-HH1-XXXXX-XXXXX-...`, groups of five for reading aloud.
  String encode() {
    final s = _base32(_bytes());
    final groups = <String>[];
    for (var i = 0; i < s.length; i += 5) {
      groups.add(s.substring(i, i + 5 > s.length ? s.length : i + 5));
    }
    return '$_prefix-${groups.join('-')}';
  }

  /// Throws [FormatException] for anything that is not a complete, intact
  /// invite (typo, truncation, another kind of code).
  static HouseholdInvite decode(String code) {
    var s = code.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');
    if (!s.startsWith(_prefix.replaceAll('-', ''))) {
      throw const FormatException('Not a household invite');
    }
    s = s.substring(_prefix.replaceAll('-', '').length);
    final bytes = _unbase32(s);
    if (bytes.length != 1 + 16 + 32 + 4 || bytes[0] != 1) {
      throw const FormatException('Not a household invite');
    }
    final body = bytes.sublist(0, 49);
    final sum = sha256.convert(body).bytes.sublist(0, 4);
    for (var i = 0; i < 4; i++) {
      if (bytes[49 + i] != sum[i]) {
        throw const FormatException('The code has a typo');
      }
    }
    final id = bytes
        .sublist(1, 17)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return HouseholdInvite(householdId: id, key: bytes.sublist(17, 49));
  }

  static String _base32(List<int> data) {
    final out = StringBuffer();
    var buffer = 0, bits = 0;
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        out.write(_alphabet[(buffer >> (bits - 5)) & 31]);
        bits -= 5;
      }
      buffer &= (1 << bits) - 1;
    }
    if (bits > 0) out.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return out.toString();
  }

  static Uint8List _unbase32(String s) {
    final out = <int>[];
    var buffer = 0, bits = 0;
    for (final ch in s.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0) throw const FormatException('Not a household invite');
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        out.add((buffer >> (bits - 8)) & 255);
        bits -= 8;
        buffer &= (1 << bits) - 1;
      }
    }
    return Uint8List.fromList(out);
  }
}
