/// Shamir secret sharing over GF(2^8), in pure Dart.
///
/// A secret is split byte by byte: each byte becomes the constant term of a
/// random polynomial of degree `threshold - 1` over GF(256) (the AES field,
/// polynomial 0x11b), and share `x` holds the polynomial evaluated at `x`.
/// Any `threshold` shares recover the secret by Lagrange interpolation at 0;
/// fewer reveal nothing about it (information-theoretically).
///
/// Shamir shares carry no integrity check of their own: a wrong share simply
/// interpolates to a wrong secret. Callers detect that because the key it
/// derives fails AES-GCM authentication. The text form below adds a CRC so a
/// mistyped share is caught early with a friendly message instead.
library;

import 'dart:math';
import 'dart:typed_data';

class ShamirException implements Exception {
  const ShamirException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One share: the point [x] (1..255), the polynomial values [y] and the
/// threshold it was made for.
class ShamirShare {
  ShamirShare({required this.threshold, required this.x, required List<int> y})
    : y = Uint8List.fromList(y);

  final int threshold;
  final int x;
  final Uint8List y;

  static const _prefix = 'PVS1';

  /// `PVS1-2-01-ABCD-EF01-...-C0DE`: threshold, x, the bytes in groups of
  /// four hex digits, then a CRC-16 of everything before it.
  String encode() {
    final body = <int>[threshold, x, ...y];
    final crc = _crc16(body);
    final hexY = _hex(y);
    final groups = <String>[];
    for (var i = 0; i < hexY.length; i += 4) {
      groups.add(hexY.substring(i, min(i + 4, hexY.length)));
    }
    return '$_prefix-$threshold-${x.toRadixString(16).padLeft(2, '0').toUpperCase()}-${groups.join('-')}-${crc.toRadixString(16).padLeft(4, '0').toUpperCase()}';
  }

  /// Throws [ShamirException] for anything that is not a share this app made
  /// (wrong prefix, bad characters, failed CRC).
  static ShamirShare parse(String text) {
    final parts = text
        .trim()
        .toUpperCase()
        .split(RegExp(r'[\s-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length < 5 || parts.first != _prefix) {
      throw const ShamirException('That is not a Pulse key share.');
    }
    final k = int.tryParse(parts[1]);
    final x = int.tryParse(parts[2], radix: 16);
    final crc = int.tryParse(parts.last, radix: 16);
    final hexY = parts.sublist(3, parts.length - 1).join();
    if (k == null ||
        x == null ||
        crc == null ||
        hexY.isEmpty ||
        hexY.length.isOdd ||
        !RegExp(r'^[0-9A-F]+$').hasMatch(hexY)) {
      throw const ShamirException(
        'That key share looks incomplete. Check it character by character.',
      );
    }
    final y = <int>[
      for (var i = 0; i < hexY.length; i += 2)
        int.parse(hexY.substring(i, i + 2), radix: 16),
    ];
    if (k < 2 || k > 255 || x < 1 || x > 255 || _crc16([k, x, ...y]) != crc) {
      throw const ShamirException(
        'That key share has a typing mistake in it. Check it character by character.',
      );
    }
    return ShamirShare(threshold: k, x: x, y: y);
  }

  static String _hex(List<int> b) =>
      [for (final v in b) v.toRadixString(16).padLeft(2, '0')]
          .join()
          .toUpperCase();

  /// CRC-16/CCITT-FALSE.
  static int _crc16(List<int> data) {
    var crc = 0xFFFF;
    for (final b in data) {
      crc ^= b << 8;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 0x8000) != 0
            ? ((crc << 1) ^ 0x1021) & 0xFFFF
            : (crc << 1) & 0xFFFF;
      }
    }
    return crc;
  }
}

abstract final class Shamir {
  // exp/log tables for generator 3 over x^8 + x^4 + x^3 + x + 1.
  static final List<int> _exp = List<int>.filled(512, 0);
  static final List<int> _log = List<int>.filled(256, 0);
  static bool _ready = false;

  static void _init() {
    if (_ready) return;
    var v = 1;
    for (var i = 0; i < 255; i++) {
      _exp[i] = v;
      _log[v] = i;
      // v * 3 = v * 2 xor v
      var twice = v << 1;
      if (twice & 0x100 != 0) twice ^= 0x11b;
      v = twice ^ v;
    }
    for (var i = 255; i < 512; i++) {
      _exp[i] = _exp[i - 255];
    }
    _ready = true;
  }

  static int mul(int a, int b) {
    _init();
    if (a == 0 || b == 0) return 0;
    return _exp[_log[a] + _log[b]];
  }

  static int div(int a, int b) {
    _init();
    if (b == 0) throw ArgumentError('division by zero in GF(256)');
    if (a == 0) return 0;
    return _exp[_log[a] + 255 - _log[b]];
  }

  /// Splits [secret] into [shares] pieces, any [threshold] of which recover
  /// it. Pass a [random] (use `Random.secure()`) so tests can be deterministic.
  static List<ShamirShare> split(
    List<int> secret, {
    int threshold = 2,
    int shares = 3,
    required Random random,
  }) {
    _init();
    if (secret.isEmpty) throw const ShamirException('Nothing to split.');
    if (threshold < 2 || shares < threshold || shares > 255) {
      throw const ShamirException('Unsupported share counts.');
    }
    final ys = [for (var i = 0; i < shares; i++) Uint8List(secret.length)];
    for (var pos = 0; pos < secret.length; pos++) {
      final coeff = <int>[
        secret[pos],
        for (var d = 1; d < threshold; d++) random.nextInt(256),
      ];
      // The leading coefficient is forced non-zero so the degree is exact.
      if (coeff.last == 0) coeff[coeff.length - 1] = 1 + random.nextInt(255);
      for (var s = 0; s < shares; s++) {
        final x = s + 1;
        var acc = 0;
        for (var d = coeff.length - 1; d >= 0; d--) {
          acc = mul(acc, x) ^ coeff[d];
        }
        ys[s][pos] = acc;
      }
    }
    return [
      for (var s = 0; s < shares; s++)
        ShamirShare(threshold: threshold, x: s + 1, y: ys[s]),
    ];
  }

  /// Recovers the secret from at least `threshold` distinct shares.
  /// Fewer, duplicates or shares of different lengths throw; a *wrong*
  /// share cannot be detected here and yields a wrong secret.
  static Uint8List combine(List<ShamirShare> shares) {
    _init();
    if (shares.isEmpty) throw const ShamirException('No key shares given.');
    final k = shares.first.threshold;
    final len = shares.first.y.length;
    if (shares.any((s) => s.threshold != k || s.y.length != len)) {
      throw const ShamirException('These key shares do not belong together.');
    }
    final xs = shares.map((s) => s.x).toSet();
    if (xs.length != shares.length)
      throw const ShamirException('The same key share was given twice.');
    if (shares.length < k)
      throw ShamirException('Need $k key shares; only ${shares.length} given.');
    final use = shares.take(k).toList();
    final out = Uint8List(len);
    for (var pos = 0; pos < len; pos++) {
      var acc = 0;
      for (var i = 0; i < use.length; i++) {
        var num = 1;
        var den = 1;
        for (var j = 0; j < use.length; j++) {
          if (i == j) continue;
          num = mul(num, use[j].x);
          den = mul(den, use[i].x ^ use[j].x);
        }
        acc ^= mul(use[i].y[pos], div(num, den));
      }
      out[pos] = acc;
    }
    return out;
  }
}
