import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/statement_parser.dart';

/// Synthetic statements (invented merchants and amounts) with the backend
/// parser's output as ground truth: the Dart port must read them identically.
void main() {
  final gold =
      jsonDecode(File('test/fixtures/statements/golden_synthetic.json').readAsStringSync())
          as List;

  for (final g in gold) {
    final inst = g['institution'] as String;
    final kind = g['kind'] as String;
    test('$inst $kind matches the backend parser', () {
      final stmt = parseStatement(g['text'] as String, institution: inst);
      final e = g['expected'] as Map<String, dynamic>;
      expect(stmt, isNotNull);
      expect(stmt!.kind == StatementKind.creditCard ? 'credit_card' : 'bank_account', e['kind']);
      expect(stmt.last4, e['last4']);
      expect(stmt.currency, e['currency']);
      String d(Object? v) => v == null ? 'None' : (v as dynamic).toIso();
      expect(d(stmt.periodStart), e['period_start']);
      expect(d(stmt.periodEnd), e['period_end']);
      expect(d(stmt.statementDate), e['statement_date']);
      expect(d(stmt.dueDate), e['due_date']);
      expect(stmt.openingMinor, e['opening']);
      expect(stmt.closingMinor, e['closing']);
      expect(stmt.minDueMinor, e['min_due']);
      expect(stmt.totalPaymentsMinor, e['payments']);
      expect(stmt.totalPurchasesMinor, e['purchases']);
      expect(stmt.warnings, e['warnings']);
      final lines = e['lines'] as List;
      expect(stmt.lines.length, lines.length);
      for (var i = 0; i < lines.length; i++) {
        final l = stmt.lines[i], x = lines[i] as Map<String, dynamic>;
        expect(
          (l.postedOn.toIso(), l.description, l.amountMinor, l.direction.name,
              l.foreignAmountMinor, l.foreignCurrency, l.balanceMinor),
          (x['d'], x['desc'], x['amt'], x['dir'], x['fa'], x['fc'], x['bal']),
          reason: 'line $i',
        );
      }
    });
  }

  test('money tokens', () {
    expect(parseMoney('1,234.50')!.minor, 123450);
    expect(parseMoney('(12.00)')!.negative, isTrue);
    expect(parseMoney('250.00 Cr')!.marker, 'CR');
    expect(parseMoney('AED 10.00')!.minor, 1000);
    expect(parseMoney('abc'), isNull);
  });

  test('garbage gives no statement', () {
    expect(parseStatement('hello world\nnothing here'), isNull);
  });
}
