import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/cas_parser.dart';

void main() {
  final text = File('test/fixtures/cas/cams_detailed_synthetic.txt')
      .readAsStringSync();
  final st = parseCas(text);

  test('period, folios and schemes', () {
    expect((st.periodFrom, st.periodTo), ('2023-04-01', '2026-11-26'));
    expect(st.kind, CasKind.mutualFund);
    expect(st.schemes.map((s) => s.folio), [
      '1234567/89',
      '7654321',
      '7654321',
      '5550001',
      '5550001',
    ]);
    final a = st.schemes.first;
    expect(a.name, 'Example Flexi Cap Fund - Direct Plan - Growth');
    expect(a.isin, 'INF000A01AB1');
    expect(a.amc, 'Example Mutual Fund');
    expect(a.registrar, 'CAMS');
  });

  test('units, NAV, cost, value and transactions', () {
    final a = st.schemes.first;
    expect(a.closingUnits, 110.416);
    expect(a.nav, 215.1);
    expect(a.navDate, '2026-11-25');
    expect(a.costMinor, 2200000);
    expect(a.valueMinor, 2375000);
    expect(a.txns, hasLength(6));
    expect(a.txns.first.kind, CasTxnKind.sip);
    expect(a.txns.first.amountMinor, 500000);
    final red = a.txns.last;
    expect(
      (red.kind, red.units, red.amountMinor),
      (CasTxnKind.redemption, -9.302, -200000),
    );
    expect(a.unitsApproximate, isFalse);
    expect(a.avgCostNav, closeTo(22000 / 110.416, 1e-9));
  });

  test('a scheme heading that wraps onto two lines and ISIN on the next', () {
    final s = st.schemes.firstWhere((s) => s.isin == 'INF000B01ZZ0');
    expect(s.name, 'Sample Gilt Fund Direct Plan Growth');
    expect(s.closingUnits, 0);
  });

  test('opening balance and a partial statement are flagged approximate', () {
    final liquid = st.schemes.firstWhere((s) => s.isin == 'INF000B01XY3');
    expect(liquid.openingUnits, 10);
    expect(liquid.units, 18.1);
    final obscure = st.schemes.last;
    expect(obscure.txns, isEmpty);
    expect(obscure.avgCostNav, isNull);
    expect(obscure.units, 200);
  });

  test('the PAN, email and name are never read into the result', () {
    final dump = StringBuffer();
    for (final s in st.schemes) {
      dump.write('${s.folio}${s.name}${s.amc}${s.isin}${s.registrar}');
      for (final t in s.txns) {
        dump.write(t.description);
      }
    }
    dump.write(st.warnings.join());
    for (final secret in [
      'ABCDE1234F',
      'investor@example',
      'Sample Investor',
      'Sample Street',
    ]) {
      expect(dump.toString().contains(secret), isFalse, reason: secret);
    }
  });

  test('stamp duty lines are ignored without a warning', () {
    expect(st.warnings.where((w) => w.contains('layout')), isEmpty);
  });

  test('transaction kinds', () {
    expect(
      classifyCasTxn('Systematic Investment Purchase - Instalment 3/60'),
      CasTxnKind.sip,
    );
    expect(classifyCasTxn('Switch Out - To Other Fund'), CasTxnKind.switchOut);
    expect(classifyCasTxn('Switch-In'), CasTxnKind.switchIn);
    expect(classifyCasTxn('Dividend Reinvested'), CasTxnKind.dividendReinvest);
    expect(classifyCasTxn('IDCW Payout'), CasTxnKind.dividendPayout);
    expect(classifyCasTxn('Redemption'), CasTxnKind.redemption);
    expect(classifyCasTxn('Purchase'), CasTxnKind.purchase);
  });

  test('a demat statement or random text is recognised as not a fund CAS', () {
    final d = parseCas(
      File('test/fixtures/cas/demat_synthetic.txt').readAsStringSync(),
    );
    expect(d.kind, CasKind.demat);
    expect(d.isEmpty, isTrue);
    expect(parseCas('hello world').kind, CasKind.unknown);
    expect(parseCas('').warnings, isNotEmpty);
  });

  group('SIP detection', () {
    test('five labelled monthly instalments, still running', () {
      final h = detectSip(st.schemes.first, asOf: '2026-05-20')!;
      expect(
        (h.amountMinor, h.day, h.count, h.labelled, h.approximate),
        (500000, 5, 5, true, false),
      );
    });
    test('stale when the last instalment is long ago', () {
      expect(detectSip(st.schemes.first, asOf: '2026-11-25'), isNull);
    });
    test('a pattern without the SIP label is approximate', () {
      CasTxn buy(String d) => CasTxn(
        date: d,
        kind: CasTxnKind.purchase,
        description: 'Purchase',
        amountMinor: 200000,
        units: 1,
      );
      final s = CasScheme(
        folio: '1',
        name: 'X',
        closingUnits: 3,
        txns: [buy('2026-08-10'), buy('2026-09-10'), buy('2026-10-12')],
      );
      final h = detectSip(s, asOf: '2026-11-01')!;
      expect((h.labelled, h.approximate, h.day), (false, true, 10));
    });
    test('irregular lump sums and fully redeemed schemes give no hint', () {
      CasTxn buy(String d, int a) => CasTxn(
        date: d,
        kind: CasTxnKind.purchase,
        description: 'Purchase',
        amountMinor: a,
        units: 1,
      );
      final lumps = CasScheme(
        folio: '1',
        name: 'X',
        closingUnits: 3,
        txns: [
          buy('2026-01-10', 100000),
          buy('2026-05-10', 900000),
          buy('2026-10-12', 50000),
        ],
      );
      expect(detectSip(lumps, asOf: '2026-11-01'), isNull);
      expect(
        detectSip(st.schemes.firstWhere((s) => s.isin == 'INF000B01ZZ0')),
        isNull,
      );
    });
  });
}
