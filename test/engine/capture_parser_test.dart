import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/capture_parser.dart';
import 'package:pulse/core/engine/dates.dart';

const goldBill = '''
AL MANAMA JEWELLERY L.L.C
Dubai Gold Souk, Deira
Tax Invoice            Date: 14/03/2023
Description          Gross Wt   Net Wt
Gold Chain 22K       21.40 gm   20.35 gm
Purity 916
Making charges            150.00
Gold value               4,820.00
VAT 5%                     248.50
Total Amount       AED 5,218.50
''';

const brokerage = '''
Portfolio
Total value \$18,420.55

VOO
Vanguard S&P 500 ETF
2.5 shares
Avg cost \$410.20
Last price \$512.30
Market value \$1,280.75

AAPL
Apple Inc.
10 shares
Avg cost \$150.00
Last price \$225.10
Market value \$2,251.00

TSLA
Qty 3
Value \$720.00
''';

void main() {
  group('gold bill', () {
    test('reads net weight, karat, total, date and item', () {
      final g = parseGoldBill(goldBill);
      expect(g.weightGrams, 20.35);
      expect(g.karat, 22);
      expect(g.amountMinor, 521850);
      expect(g.date, const CalDate(2023, 3, 14));
      expect(g.name, 'Gold chain');
      expect(g.missing, isEmpty);
      expect(g.approximate, isFalse);
    });

    test('falls back to fineness for the karat', () {
      final g = parseGoldBill('Gold bar 100 grams\nFineness 999.9\nAED 28,000');
      expect(g.weightGrams, 100);
      expect(g.karat, 24);
      expect(g.name, 'Gold bar');
      expect(g.amountMinor, 2800000);
    });

    test('reports what it could not read', () {
      final g = parseGoldBill('Gold ring\nthank you');
      expect(g.usable, isFalse);
      expect(g.missing, ['weight', 'karat']);
    });

    test('a gross-only weight still counts but net wins', () {
      final g = parseGoldBill('Gross weight 12 g\nNet weight 10.5 g\n18K gold');
      expect(g.weightGrams, 10.5);
      expect(g.karat, 18);
    });
  });

  group('portfolio', () {
    test('reads each position under its ticker', () {
      final list = parsePortfolio(brokerage);
      expect(list.map((h) => h.symbol), ['VOO', 'AAPL', 'TSLA']);
      final voo = list.first;
      expect(voo.quantity, 2.5);
      expect(voo.avgCost, 410.20);
      expect(voo.price, 512.30);
      expect(voo.value, 1280.75);
      expect(voo.name, contains('Vanguard'));
      expect(list[2].quantity, 3);
      expect(list[2].value, 720.0);
    });

    test('derives units from value and price when no quantity shown', () {
      final h = parsePortfolio('QQQ\nPrice 400.00\nValue \$2,000.00').single;
      expect(h.quantity, isNull);
      expect(h.units, 5);
    });

    test('ignores headings and words that only look like tickers', () {
      expect(parsePortfolio('PORTFOLIO\nTOTAL VALUE\nDAY GAIN +1.2%'), isEmpty);
    });

    test('recognises a fund by its name', () {
      final h = parsePortfolio('Vanguard S&P 500 ETF\n4 shares\n\$2,000.00')
          .single;
      expect(h.symbol, 'VOO');
      expect(h.quantity, 4);
    });
  });

  group('classify', () {
    test('tells a gold bill from a portfolio from noise', () {
      expect(classify(goldBill), CaptureKind.goldBill);
      expect(classify(brokerage), CaptureKind.portfolio);
      expect(classify('hello world, nothing here'), CaptureKind.unknown);
    });

    test('parseCapture routes by kind', () {
      expect(parseCapture(goldBill).gold?.weightGrams, 20.35);
      expect(parseCapture(brokerage).holdings, hasLength(3));
      expect(parseCapture('nothing').isEmpty, isTrue);
    });
  });

  group('approximate entries', () {
    test('"about 20g 22k gold bought 2023"', () {
      final r = parseApproximate('about 20g 22k gold bought 2023');
      final g = r.gold!;
      expect(r.kind, CaptureKind.goldBill);
      expect(g.weightGrams, 20);
      expect(g.karat, 22);
      expect(g.date?.year, 2023);
      expect(g.approximate, isTrue);
      expect(g.note, contains('2023'));
    });

    test('assumes 22K when the karat is not given and says so', () {
      final g = parseApproximate('~10 grams gold bar').gold!;
      expect(g.karat, 22);
      expect(g.note, contains('assumed'));
      expect(g.name, 'Gold bar');
    });

    test('a price paid is picked up', () {
      final g = parseApproximate('gold chain 15g 22k paid AED 4,000 in 2022')
          .gold!;
      expect(g.amountMinor, 400000);
      expect(g.weightGrams, 15);
    });

    test('"50 shares of VOO bought 2022 avg 400"', () {
      final h = parseApproximate('50 shares of VOO bought 2022 avg 400')
          .holdings
          .single;
      expect(h.symbol, 'VOO');
      expect(h.quantity, 50);
      expect(h.avgCost, 400);
      expect(h.approximate, isTrue);
    });

    test('quantity unknown is flagged, not invented', () {
      final h = parseApproximate('some VTI from a few years back')
          .holdings
          .single;
      expect(h.symbol, 'VTI');
      expect(h.quantity, isNull);
      expect(h.note, contains('unknown'));
    });

    test('empty or meaningless text yields nothing', () {
      expect(parseApproximate('   ').isEmpty, isTrue);
      expect(parseApproximate('hello there').isEmpty, isTrue);
    });
  });

  group('numbers', () {
    test('grouping and decimal commas', () {
      expect(parseLooseNumber('1,234.50'), 1234.5);
      expect(parseLooseNumber('12,5'), 12.5);
      expect(parseLooseNumber('1,234'), 1234);
      expect(numbersIn('AED 5,218.50 and 20.35 gm'), [5218.5, 20.35]);
    });
  });
}
