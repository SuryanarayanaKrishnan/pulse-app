import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/utils/money.dart';

void main() {
  group('Money', () {
    test('formats AED with grouping', () {
      expect(Money.aed(1234.5), 'AED 1,234.50');
      expect(Money.aed(1234.5, decimals: false), 'AED 1,235');
    });
    test('handles sign', () {
      expect(Money.aed(-45), '-AED 45.00');
      expect(Money.aed(45, sign: true), '+AED 45.00');
    });
    test('compact', () {
      expect(Money.aedCompact(1200000), 'AED 1.2M');
    });
  });
}
