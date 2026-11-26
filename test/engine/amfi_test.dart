import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/amfi.dart';

void main() {
  final text = File('test/fixtures/navall_sample.txt').readAsStringSync();
  final book = parseAmfiNavAll(text);

  test('parses rows, skips headings, N.A. and bad dates', () {
    expect(book.schemes.map((s) => s.code), [
      '100001',
      '100002',
      '100003',
      '200002',
    ]);
    expect(book.skipped, 2);
    expect(book.byCode('100001')!.nav, 215.1);
    expect(book.byCode('200002')!.nav, 1234.56);
    expect(book.asOf, '2026-11-25');
  });

  test('dates', () {
    expect(parseAmfiDate('05-Jan-2026'), '2026-01-05');
    expect(parseAmfiDate('5-feb-2026'), '2026-02-05');
    expect(parseAmfiDate('2026-01-05'), isNull);
    expect(parseAmfiDate('32-Jan-2026'), isNull);
  });

  test('ISIN match is exact and covers the reinvestment ISIN', () {
    expect(book.match(isin: 'inf000a01ab1', name: 'whatever')!.code, '100001');
    expect(book.match(isin: 'INF000A01AD7', name: 'x')!.code, '100002');
  });

  test('name match prefers the plan named; unknown names give null', () {
    expect(
      book.match(name: 'Example Flexi Cap Fund - Regular Plan - Growth')!.code,
      '100003',
    );
    expect(
      book.match(name: 'Example Flexi Cap Fund Direct Growth')!.code,
      '100001',
    );
    expect(book.match(name: 'Totally Different Biotech Fund'), isNull);
  });

  test('empty or garbage input is an empty book, not an error', () {
    expect(parseAmfiNavAll('<html>blocked</html>').isEmpty, isTrue);
  });
}
