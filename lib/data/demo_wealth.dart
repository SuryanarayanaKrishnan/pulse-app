import '../core/engine/dates.dart';
import '../core/engine/prices.dart';
import 'local/wealth_store.dart';
import 'wealth_models.dart';

/// Demo jewellery, documents and funds with a stored value history (for the
/// screenshots, the web demo and widget tests). Photos are `demo:n`
/// placeholders drawn by the app; nothing is read from disk.
MemoryWealthStore demoWealthStore({DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = CalDate(n.year, n.month, n.day);
  CalDate ahead(int days) => today.addDays(days);

  final necklace = JewelleryItem(
    id: 'jw1',
    name: 'Bridal necklace set',
    weightGrams: 64.2,
    karat: 22,
    purchasePriceMinor: 2410000,
    purchaseDate: const CalDate(2023, 5, 14),
    makingChargesMinor: 168000,
    notes: 'Dubai Gold Souk. Receipt in Documents.',
    photoPaths: const ['demo:0', 'demo:1', 'demo:2'],
    createdAt: n,
  );
  final bangles = JewelleryItem(
    id: 'jw2',
    name: 'Everyday bangles (4)',
    weightGrams: 38.5,
    karat: 21,
    purchasePriceMinor: 1425000,
    purchaseDate: const CalDate(2024, 2, 3),
    makingChargesMinor: 82000,
    photoPaths: const ['demo:3'],
    createdAt: n,
  );
  final bands = JewelleryItem(
    id: 'jw3',
    name: 'Wedding bands',
    weightGrams: 9.4,
    karat: 18,
    purchasePriceMinor: 405000,
    purchaseDate: const CalDate(2021, 11, 20),
    photoPaths: const ['demo:4'],
    createdAt: n,
  );

  // Eleven month-ends of stored valuations, drifting up with the gold price.
  const drift = [
    0.86,
    0.88,
    0.87,
    0.91,
    0.93,
    0.92,
    0.95,
    0.97,
    0.96,
    0.99,
    1.0,
  ];
  List<ValuationPoint> series(JewelleryItem i, int nowMinor) => [
    for (var k = 0; k < drift.length; k++)
      ValuationPoint(
        today.addDays(-(drift.length - 1 - k) * 30),
        (nowMinor * drift[k]).round(),
        null,
      ),
  ];
  const price = 470.0; // matches the bundled fallback
  int melt(JewelleryItem i) => (i.weightGrams * i.purity * price * 100).round();

  // A recent "fetch", so the demo reads as live prices.
  final fetched = n.toUtc().subtract(const Duration(minutes: 12));
  PriceQuote q(String symbol, double p) => PriceQuote(
    symbol: symbol,
    price: p,
    source: 'Demo price feed',
    quotedAt: fetched,
    fetchedAt: fetched,
  );

  return MemoryWealthStore(
    quotes: [
      for (final k in PriceBook.goldKarats)
        q('XAU_AED_G_${k}K', double.parse((price * k / 24).toStringAsFixed(2))),
      q('FX_USD_AED', 3.6725),
      q('FX_INR_AED', 0.0425),
    ],
    jewellery: [necklace, bangles, bands],
    history: {
      'jewellery:jw1': series(necklace, melt(necklace)),
      'jewellery:jw2': series(bangles, melt(bangles)),
      'jewellery:jw3': series(bands, melt(bands)),
    },
    documents: [
      WealthDocument(
        id: 'd1',
        title: 'Emirates ID',
        category: DocCategory.emiratesId,
        filePaths: const ['demo:0', 'demo:1'],
        dueOn: ahead(24),
        dueKind: 'expiry',
        remindDaysBefore: 30,
        createdAt: n,
      ),
      WealthDocument(
        id: 'd2',
        title: 'Home insurance policy',
        category: DocCategory.insurance,
        notes: 'Policy 88-4412. Renew with the agent.',
        filePaths: const ['demo:2'],
        dueOn: ahead(46),
        dueKind: 'renewal',
        remindDaysBefore: 14,
        createdAt: n,
      ),
      WealthDocument(
        id: 'd3',
        title: 'Passport',
        category: DocCategory.passport,
        filePaths: const ['demo:3'],
        dueOn: ahead(214),
        dueKind: 'expiry',
        remindDaysBefore: 90,
        createdAt: n,
      ),
      WealthDocument(
        id: 'd4',
        title: 'ADCB fixed deposit certificate',
        category: DocCategory.fdCertificate,
        filePaths: const ['demo:4'],
        dueOn: ahead(110),
        dueKind: 'maturity',
        remindDaysBefore: 7,
        createdAt: n,
      ),
      WealthDocument(
        id: 'd5',
        title: 'Marina 1BR title deed',
        category: DocCategory.titleDeed,
        filePaths: const ['demo:5'],
        createdAt: n,
      ),
    ],
    funds: [
      FundHolding(
        id: 'f1',
        kind: 'india_mf',
        schemeCode: '122639',
        name: 'Parag Parikh Flexi Cap Fund - Direct Growth',
        currency: 'INR',
        units: 2412.318,
        avgCostNav: 58.2,
        nav: 79.84,
        navDate: today.addDays(-1).toIso(),
        navSource: 'market',
        navFetchedAt: n.subtract(const Duration(hours: 5)),
        sipAmountMinor: 1500000,
        sipDay: 7,
        createdAt: n,
      ),
      FundHolding(
        id: 'f2',
        kind: 'india_mf',
        schemeCode: '120503',
        name: 'UTI Nifty 50 Index Fund - Direct Growth',
        currency: 'INR',
        units: 810.552,
        avgCostNav: 132.4,
        nav: 168.27,
        navDate: today.addDays(-1).toIso(),
        navSource: 'market',
        navFetchedAt: n.subtract(const Duration(hours: 5)),
        createdAt: n,
      ),
      FundHolding(
        id: 'f3',
        kind: 'manual',
        name: 'Emirates NBD Money Market Fund',
        currency: 'AED',
        units: 12500,
        avgCostNav: 1.082,
        nav: 1.1146,
        navDate: today.addDays(-3).toIso(),
        navSource: 'manual',
        sipAmountMinor: 100000,
        sipDay: 28,
        createdAt: n,
      ),
    ],
  );
}
