import '../core/engine/dates.dart';
import '../core/engine/valuation.dart';

/// Plain models for the Wealth additions: jewellery, documents, funds. Money
/// is integer minor units (fils) like the rest of the ledger.

class JewelleryItem {
  const JewelleryItem({
    required this.id,
    required this.name,
    required this.weightGrams,
    required this.karat,
    this.purityOverride,
    this.purchasePriceMinor,
    this.purchaseDate,
    this.makingChargesMinor,
    this.notes,
    this.photoPaths = const [],
    this.approximate = false,
    required this.createdAt,
  });

  final String id, name;
  final double weightGrams;
  final int karat;
  final double? purityOverride;
  final int? purchasePriceMinor, makingChargesMinor;
  final CalDate? purchaseDate;
  final String? notes;

  /// Files in the app-private attachments folder (or `demo:n` placeholders).
  final List<String> photoPaths;

  /// Weight, karat or price estimated rather than read off a bill.
  final bool approximate;
  final DateTime createdAt;

  double get purity => purityOverride ?? purityForKarat(karat);

  String get purityLabel => purityOverride != null
      ? '${(purityOverride! * 1000).round()} fineness'
      : '${karat}K · ${finenessLabel(karat)}';

  JewelleryItem copyWith({
    String? name,
    double? weightGrams,
    int? karat,
    double? purityOverride,
    bool clearPurity = false,
    int? purchasePriceMinor,
    bool clearPurchase = false,
    CalDate? purchaseDate,
    int? makingChargesMinor,
    bool clearMaking = false,
    String? notes,
    List<String>? photoPaths,
    bool? approximate,
  }) => JewelleryItem(
    id: id,
    name: name ?? this.name,
    weightGrams: weightGrams ?? this.weightGrams,
    karat: karat ?? this.karat,
    purityOverride: clearPurity
        ? null
        : (purityOverride ?? this.purityOverride),
    purchasePriceMinor: clearPurchase
        ? null
        : (purchasePriceMinor ?? this.purchasePriceMinor),
    purchaseDate: clearPurchase ? null : (purchaseDate ?? this.purchaseDate),
    makingChargesMinor: clearMaking
        ? null
        : (makingChargesMinor ?? this.makingChargesMinor),
    notes: notes ?? this.notes,
    photoPaths: photoPaths ?? this.photoPaths,
    approximate: approximate ?? this.approximate,
    createdAt: createdAt,
  );
}

enum DocCategory {
  titleDeed('title_deed', 'Title deed', 'renewal'),
  fdCertificate('fd_certificate', 'FD certificate', 'maturity'),
  insurance('insurance', 'Insurance', 'renewal'),
  passport('passport', 'Passport', 'expiry'),
  emiratesId('emirates_id', 'Emirates ID', 'expiry'),
  visa('visa', 'Visa', 'expiry'),
  other('other', 'Other', 'expiry');

  const DocCategory(this.wire, this.label, this.defaultDueKind);
  final String wire, label, defaultDueKind;

  static DocCategory fromWire(String s) =>
      values.firstWhere((c) => c.wire == s, orElse: () => other);
}

class WealthDocument {
  const WealthDocument({
    required this.id,
    required this.title,
    required this.category,
    this.notes,
    this.filePaths = const [],
    this.dueOn,
    this.dueKind = 'expiry',
    this.remindDaysBefore,
    this.notificationId,
    required this.createdAt,
  });

  final String id, title;
  final DocCategory category;
  final String? notes;
  final List<String> filePaths;
  final CalDate? dueOn;

  /// expiry | maturity | renewal
  final String dueKind;
  final int? remindDaysBefore;
  final int? notificationId;
  final DateTime createdAt;

  String get dueLabel => switch (dueKind) {
    'maturity' => 'Matures',
    'renewal' => 'Renews',
    _ => 'Expires',
  };
}

class FundHolding {
  const FundHolding({
    required this.id,
    required this.kind,
    this.schemeCode,
    required this.name,
    this.currency = 'INR',
    required this.units,
    this.avgCostNav,
    required this.nav,
    this.navDate,
    this.navSource = 'manual',
    this.navFetchedAt,
    this.sipAmountMinor,
    this.sipDay,
    required this.createdAt,
  });

  final String id;

  /// india_mf | manual
  final String kind;
  final String? schemeCode;
  final String name, currency;
  final double units, nav;
  final double? avgCostNav;
  final String? navDate;
  final String navSource;
  final DateTime? navFetchedAt;
  final int? sipAmountMinor, sipDay;
  final DateTime createdAt;

  bool get isIndian => kind == 'india_mf';
  bool get hasSip =>
      sipAmountMinor != null && sipAmountMinor! > 0 && sipDay != null;

  FundHolding copyWith({
    String? name,
    String? currency,
    double? units,
    double? avgCostNav,
    double? nav,
    String? navDate,
    String? navSource,
    DateTime? navFetchedAt,
    int? sipAmountMinor,
    int? sipDay,
    bool clearSip = false,
  }) => FundHolding(
    id: id,
    kind: kind,
    schemeCode: schemeCode,
    name: name ?? this.name,
    currency: currency ?? this.currency,
    units: units ?? this.units,
    avgCostNav: avgCostNav ?? this.avgCostNav,
    nav: nav ?? this.nav,
    navDate: navDate ?? this.navDate,
    navSource: navSource ?? this.navSource,
    navFetchedAt: navFetchedAt ?? this.navFetchedAt,
    sipAmountMinor: clearSip ? null : (sipAmountMinor ?? this.sipAmountMinor),
    sipDay: clearSip ? null : (sipDay ?? this.sipDay),
    createdAt: createdAt,
  );
}

/// One stored value of one thing on one day.
class ValuationPoint {
  const ValuationPoint(this.date, this.valueMinor, [this.unitPrice]);
  final CalDate date;
  final int valueMinor;
  final double? unitPrice;
}

/// A scheme found by fund search.
class FundScheme {
  const FundScheme(this.code, this.name);
  final String code, name;
}

class FundNav {
  const FundNav({
    required this.code,
    this.name,
    required this.navDate,
    required this.nav,
  });
  final String code;
  final String? name;
  final String navDate;
  final double nav;
}

/// A stock or ETF position: entered by hand, read from a portfolio screenshot
/// or built up by an investing rule. Priced from the last known close.
class StockHolding {
  const StockHolding({
    required this.id,
    required this.symbol,
    this.name,
    this.currency = 'USD',
    required this.quantity,
    this.avgCost,
    this.lastPrice,
    this.priceAt,
    this.priceSource,
    this.purchaseDate,
    this.approximate = false,
    this.source = 'manual',
    this.note,
    required this.createdAt,
  });

  final String id, symbol;
  final String? name;
  final String currency;
  final double quantity;

  /// Average cost per unit; null when unknown (then there is no P&L).
  final double? avgCost;
  final double? lastPrice;
  final DateTime? priceAt;
  final String? priceSource;
  final CalDate? purchaseDate;
  final bool approximate;

  /// screenshot | typed | manual | rule
  final String source;
  final String? note;
  final DateTime createdAt;

  String get title => name == null || name!.isEmpty ? symbol : name!;

  StockHolding copyWith({
    String? name,
    double? quantity,
    double? avgCost,
    bool clearAvg = false,
    double? lastPrice,
    DateTime? priceAt,
    String? priceSource,
    CalDate? purchaseDate,
    bool? approximate,
    String? source,
    String? note,
  }) => StockHolding(
    id: id,
    symbol: symbol,
    name: name ?? this.name,
    currency: currency,
    quantity: quantity ?? this.quantity,
    avgCost: clearAvg ? null : (avgCost ?? this.avgCost),
    lastPrice: lastPrice ?? this.lastPrice,
    priceAt: priceAt ?? this.priceAt,
    priceSource: priceSource ?? this.priceSource,
    purchaseDate: purchaseDate ?? this.purchaseDate,
    approximate: approximate ?? this.approximate,
    source: source ?? this.source,
    note: note ?? this.note,
    createdAt: createdAt,
  );
}
