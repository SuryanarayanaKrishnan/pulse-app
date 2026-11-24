import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/statement_parser.dart';
import 'package:pulse/data/local/statement_service.dart' show reconcile;

/// Synthetic statements (invented merchants and amounts) with the backend
/// parser's output as ground truth: the Dart port must read them identically.
void main() {
  final gold = jsonDecode(
    File('test/fixtures/statements/golden_synthetic.json').readAsStringSync(),
  ) as List;

  for (final g in gold) {
    final inst = g['institution'] as String;
    final kind = g['kind'] as String;
    test('$inst $kind matches the backend parser', () {
      final stmt = parseStatement(g['text'] as String, institution: inst);
      final e = g['expected'] as Map<String, dynamic>;
      expect(stmt, isNotNull);
      expect(
        stmt!.kind == StatementKind.creditCard ? 'credit_card' : 'bank_account',
        e['kind'],
      );
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
          (
            l.postedOn.toIso(),
            l.description,
            l.amountMinor,
            l.direction.name,
            l.foreignAmountMinor,
            l.foreignCurrency,
            l.balanceMinor,
          ),
          (x['d'], x['desc'], x['amt'], x['dir'], x['fa'], x['fc'], x['bal']),
          reason: 'line $i',
        );
      }
    });
  }

  realLayoutTests();

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

/// Layouts seen in real statement PDFs (names, numbers and amounts replaced;
/// the structure, label order and quirks are as printed by each bank).
void realLayoutTests() {
  Map<String, Object?> read(String file, {String? institution}) {
    final s = parseStatement(
      File('test/fixtures/statements/layouts/$file').readAsStringSync(),
      institution: institution,
    )!;
    final r = reconcile(s).status;
    return {
      'last4': s.last4,
      'statement': s.statementDate?.toIso(),
      'due': s.dueDate?.toIso(),
      'min': s.minDueMinor,
      'opening': s.openingMinor,
      'closing': s.closingMinor,
      'lines': s.lines.length,
      'credits': s.lines.where((l) => l.direction.name == 'credit').length,
      'recon': r,
    };
  }

  test('Emirates NBD: label row, value row below, "104.00CR"', () {
    expect(read('enbd_card.txt', institution: 'enbd'), {
      'last4': '1234',
      'statement': '2026-04-01',
      'due': '2026-04-26',
      'min': 15000,
      'opening': 20000,
      'closing': 52000,
      'lines': 4,
      'credits': 1,
      'recon': 'matched',
    });
  });

  test(
    'Sharjah Islamic: unlabelled summary rows, dd/mm rows, duplicate amounts',
    () {
      final m = read('sib_card.txt');
      expect(m, {
        'last4': '1234',
        'statement': '2026-03-14',
        'due': '2026-03-30',
        'min': 10000,
        'opening': 100000,
        'closing': 85000,
        'lines': 5,
        'credits': 2,
        'recon': 'matched',
      });
    },
  );

  test('Mashreq card: dd/mm rows with a reference and a trailing minus for credits', () {
    expect(read('mashreq_card.txt', institution: 'mashreq'), {
      'last4': '1234',
      'statement': '2026-03-12',
      'due': '2026-04-09',
      'min': 5000,
      'opening': 12000,
      'closing': 7500,
      'lines': 2,
      'credits': 1,
      'recon': 'matched',
    });
  });

  test(
    'Dubai First: statement and due date come from the line after "CREDIT"',
    () {
      final m = read('fab_card.txt', institution: 'fab');
      expect(m['statement'], '2026-03-22');
      expect(m['due'], '2026-04-16');
      expect(m['lines'], 1);
    },
  );
}
