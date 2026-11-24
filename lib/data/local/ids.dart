import 'dart:math';

final _rng = Random.secure();

/// A random 128-bit id as 32 hex characters (collision-safe for local rows).
String newId([String prefix = '']) {
  final b = StringBuffer(prefix);
  for (var i = 0; i < 16; i++) {
    b.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}
