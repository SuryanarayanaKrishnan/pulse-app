import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/capture_parser.dart';
import 'package:pulse/core/engine/markets.dart';

void main() {
  typedFundTests();
  group('listingOf', () {
    test('US tickers stay bare', () {
      expect(listingOf('voo').symbol, 'VOO');
      expect(listingOf('voo.us').symbol, 'VOO');
      expect(listingOf(r'$AAPL').exchange, Exchange.us);
      expect(listingOf('BRK.B').symbol, 'BRK.B');
    });
    test('suffix and prefix forms agree', () {
      for (final raw in ['reliance.ns', 'RELIANCE.NSE', 'NSE:reliance']) {
        final l = listingOf(raw);
        expect(l.symbol, 'RELIANCE.NS');
        expect(l.currency, 'INR');
        expect(l.quoteTicker, 'reliance.ns');
      }
    });
    test('UAE and BSE have no free price source', () {
      final d = listingOf('emaar.dfm');
      expect(d.symbol, 'EMAAR.DFM');
      expect(d.currency, 'AED');
      expect(d.quoteTicker, isNull);
      expect(listingOf('ADX:FAB').exchange, Exchange.adx);
      expect(listingOf('500325.BO').quoteTicker, isNull);
    });
  });

  group('portfolio screenshots with exchanges', () {
    test('suffix ticker keeps its exchange and currency', () {
      final h = parsePortfolio(
        'EMAAR.DFM Emaar Properties\n1,000 shares\nAvg cost 9.40\nLast price 13.20',
      ).single;
      expect(h.symbol, 'EMAAR.DFM');
      expect(h.currency, 'AED');
      expect(h.quantity, 1000);
      expect(h.avgCost, 9.40);
    });
    test('Indian broker lines become NSE tickers', () {
      const text = '''
Holdings
RELIANCE
Qty. 10  Avg. cost 2,400.50
LTP ₹2,950.00
HDFCBANK
Qty. 25  Avg. cost 1,500.00
LTP ₹1,650.25
''';
      final hs = parsePortfolio(text);
      expect(hs.map((h) => h.symbol), ['RELIANCE.NS', 'HDFCBANK.NS']);
      expect(hs.first.currency, 'INR');
      expect(hs.first.quantity, 10);
      expect(hs.first.avgCost, 2400.5);
      expect(hs.last.price, 1650.25);
    });
    test('without rupees a bare long word is not a ticker', () {
      expect(parsePortfolio('Holdings\nRELIANCE\nsomething'), isEmpty);
    });
  });

  group('Indian mutual funds', () {
    const app = '''
Mutual Funds
Parag Parikh Flexi Cap Fund -
Direct Plan - Growth
Invested ₹1,20,000
Current value ₹1,48,250.40
Units 1,820.455
NAV ₹81.43
SIP ₹5,000 on the 5th
HDFC Index Fund Nifty 50 Plan Direct Growth
Invested ₹50,000
Current ₹53,100
Units 250.120
''';

    test('reads names, units, money and SIP', () {
      final fs = parseMutualFunds(app);
      expect(fs, hasLength(2));
      final a = fs.first;
      expect(a.name, 'Parag Parikh Flexi Cap Fund - Direct Plan - Growth');
      expect(a.units, 1820.455);
      expect(a.nav, 81.43);
      expect(a.invested, 120000);
      expect(a.current, 148250.40);
      expect(a.sipAmountMinor, 500000);
      expect(a.sipDay, 5);
      expect(a.avgCostNav, closeTo(120000 / 1820.455, 1e-9));
      expect(a.approximate, isFalse);
      final b = fs.last;
      expect(b.units, 250.12);
      expect(b.hasSip, isFalse);
      expect(b.navUsed, closeTo(53100 / 250.12, 1e-9));
      expect(b.approximate, isTrue);
    });

    test('classify prefers funds when India signals are present', () {
      expect(classify(app), CaptureKind.mutualFunds);
      expect(parseCapture(app).funds, hasLength(2));
    });

    test('a US ETF line with "Fund" is not an Indian fund', () {
      const us =
          'VOO Vanguard S&P 500 ETF\n10 shares\nAvg cost 400.00\nLast price 500.00';
      expect(classify(us), CaptureKind.portfolio);
    });
  });
}

void typedFundTests() {
  group('typed fund entries', () {
    test('lakh and k, amount is today\'s value', () {
      final f = parseApproximateFund('about ₹1.5 lakh in Parag Parikh Flexi Cap')!;
      expect(f.name, 'Parag Parikh Flexi Cap');
      expect(f.current, 150000);
      expect(f.invested, isNull);
      expect(f.units, isNull);
      expect(f.approximate, isTrue);
    });
    test('"invested" makes the amount what was put in, with SIP', () {
      final f = parseApproximateFund(
        'invested 50k in HDFC Index Fund Nifty 50 since 2021, SIP 2000',
      )!;
      expect(f.name, 'HDFC Index Fund Nifty 50');
      expect(f.invested, 50000);
      expect(f.current, isNull);
      expect(f.sipAmountMinor, 200000);
      expect(f.sipDay, isNull);
    });
    test('units without money', () {
      final f = parseApproximateFund('500 units of Mirae Asset Large Cap fund')!;
      expect(f.units, 500);
      expect(f.name, 'Mirae Asset Large Cap fund');
    });
    test('routes through parseApproximate; US and NSE stocks stay stocks', () {
      expect(parseApproximate('about ₹1 lakh in Parag Parikh Flexi Cap').kind, CaptureKind.mutualFunds);
      expect(parseApproximate('50 shares of VOO avg 400').kind, CaptureKind.portfolio);
      expect(parseApproximate('10 shares of RELIANCE.NS avg 1200').holdings.single.symbol, 'RELIANCE.NS');
    });
  });
}
