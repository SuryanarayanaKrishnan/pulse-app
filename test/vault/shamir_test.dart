import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/vault/shamir.dart';

List<List<T>> subsets<T>(List<T> items, int size) {
  if (size == 0) return [<T>[]];
  if (items.length < size) return [];
  final first = items.first;
  return [
    for (final rest in subsets(items.sublist(1), size - 1)) [first, ...rest],
    ...subsets(items.sublist(1), size),
  ];
}

void main() {
  final rnd = Random(7);
  final secret = [for (var i = 0; i < 16; i++) rnd.nextInt(256)];

  test('GF(256) arithmetic: known AES-field products and inverses', () {
    expect(Shamir.mul(0x57, 0x83), 0xc1); // FIPS-197 example
    for (var a = 1; a < 256; a++) {
      expect(Shamir.mul(a, Shamir.div(1, a)), 1, reason: '$a');
    }
    expect(Shamir.mul(0, 77), 0);
  });

  test('2-of-3: every pair recovers the secret, in any order', () {
    final shares = Shamir.split(secret, random: rnd);
    expect(shares.map((s) => s.x), [1, 2, 3]);
    for (final pair in subsets(shares, 2)) {
      expect(Shamir.combine(pair), secret);
      expect(Shamir.combine(pair.reversed.toList()), secret);
    }
    expect(Shamir.combine(shares), secret, reason: 'all three also work');
  });

  test('a single share recovers nothing and is refused', () {
    final shares = Shamir.split(secret, random: rnd);
    for (final s in shares) {
      expect(() => Shamir.combine([s]), throwsA(isA<ShamirException>()));
    }
  });

  test('a single share is statistically independent of the secret', () {
    // For a fixed x, the share byte is uniform whatever the secret byte is.
    final counts = <int, int>{};
    for (var i = 0; i < 4096; i++) {
      final s = Shamir.split([0x42], random: rnd);
      counts[s[0].y[0]] = (counts[s[0].y[0]] ?? 0) + 1;
    }
    expect(counts.length, greaterThan(240));
  });

  test('other thresholds: 3-of-5 over all subsets', () {
    final shares = Shamir.split(secret, threshold: 3, shares: 5, random: rnd);
    for (final trio in subsets(shares, 3)) {
      expect(Shamir.combine(trio), secret);
    }
    for (final pair in subsets(shares, 2)) {
      expect(() => Shamir.combine(pair), throwsA(isA<ShamirException>()));
    }
  });

  test('a wrong share gives a wrong secret, never the right one', () {
    final shares = Shamir.split(secret, random: rnd);
    final bad = ShamirShare(
      threshold: 2,
      x: 2,
      y: [for (final b in shares[1].y) b ^ 0x01],
    );
    expect(Shamir.combine([shares[0], bad]), isNot(secret));
    final other = Shamir.split(secret, random: Random(99));
    expect(
      Shamir.combine([shares[0], other[1]]),
      isNot(secret),
      reason: 'a share from a different split',
    );
  });

  test('duplicates and mixed splits are refused', () {
    final shares = Shamir.split(secret, random: rnd);
    expect(
      () => Shamir.combine([shares[0], shares[0]]),
      throwsA(isA<ShamirException>()),
    );
    final longer = Shamir.split([...secret, 1], random: rnd);
    expect(
      () => Shamir.combine([shares[0], longer[1]]),
      throwsA(isA<ShamirException>()),
    );
    expect(
      () => Shamir.split(secret, threshold: 1, random: rnd),
      throwsA(isA<ShamirException>()),
    );
    expect(
      () => Shamir.split(secret, threshold: 4, shares: 3, random: rnd),
      throwsA(isA<ShamirException>()),
    );
  });

  test('text form: round trip, lenient spacing and case, typos caught', () {
    final shares = Shamir.split(secret, random: rnd);
    final text = shares[1].encode();
    expect(text, startsWith('PVS1-2-02-'));
    final back = ShamirShare.parse(text);
    expect([back.x, back.threshold, ...back.y], [2, 2, ...shares[1].y]);
    expect(
      ShamirShare.parse('  ${text.toLowerCase().replaceAll('-', ' ')}\n').y,
      shares[1].y,
    );
    final typo = text.replaceFirst(RegExp(r'-([0-9A-F])'), '-X');
    expect(() => ShamirShare.parse(typo), throwsA(isA<ShamirException>()));
    final flipped =
        text.substring(0, 14) +
        (text[14] == '0' ? '1' : '0') +
        text.substring(15);
    expect(
      () => ShamirShare.parse(flipped),
      throwsA(isA<ShamirException>()),
      reason: 'CRC catches a changed digit',
    );
    expect(() => ShamirShare.parse('hello'), throwsA(isA<ShamirException>()));
    expect(() => ShamirShare.parse(''), throwsA(isA<ShamirException>()));
  });
}
