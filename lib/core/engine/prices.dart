/// Price book: what the phone knows about gold and FX, parsed from the shared
/// snapshot (`GET /v1/prices/snapshot`), cached in the local DB, with a
/// bundled last-known fallback. Pure Dart, no I/O.
library;

/// One cached price. [symbol] examples: `XAU_AED_G_24K` (AED per gram of
/// 24k gold), `FX_USD_AED` (AED per 1 USD).
class PriceQuote {
  const PriceQuote({
    required this.symbol,
    required this.price,
    this.unit = 'AED',
    this.source,
    this.status = 'live',
    this.quotedAt,
    required this.fetchedAt,
  });
  final String symbol;
  final double price;
  final String unit;
  final String? source;
  final String status;
  final DateTime? quotedAt;
  final DateTime fetchedAt;
}

/// Where a [PriceBook] came from, for the "updated X ago" line.
enum PriceOrigin { fetched, cached, bundled }

class PriceBook {
  PriceBook(Iterable<PriceQuote> quotes, {this.origin = PriceOrigin.cached})
    : _quotes = {for (final q in quotes) q.symbol: q};

  final Map<String, PriceQuote> _quotes;
  final PriceOrigin origin;

  static const goldKarats = [24, 22, 21, 18];

  Iterable<PriceQuote> get quotes => _quotes.values;
  bool get isEmpty => _quotes.isEmpty;

  /// When gold was last fetched (what "updated X ago" says); without gold,
  /// the oldest fetch across everything.
  DateTime? get fetchedAt {
    final gold = _quotes['XAU_AED_G_24K']?.fetchedAt;
    if (gold != null) return gold;
    DateTime? oldest;
    for (final q in _quotes.values) {
      if (oldest == null || q.fetchedAt.isBefore(oldest)) oldest = q.fetchedAt;
    }
    return oldest;
  }

  /// True when every stored gold quote is flagged stale or unavailable by the
  /// backend, or the book is the bundled fallback.
  bool get isStale =>
      origin == PriceOrigin.bundled ||
      (gold24 != null && _quotes['XAU_AED_G_24K']!.status != 'live');

  PriceQuote? quote(String symbol) => _quotes[symbol];

  /// AED per gram of pure (24k) gold.
  double? get gold24 => _quotes['XAU_AED_G_24K']?.price;

  /// AED per gram at the given karat, from the stored per-karat quote when
  /// there is one, else derived from 24k.
  double? goldPerGram(int karat) {
    final direct = _quotes['XAU_AED_G_${karat}K']?.price;
    if (direct != null) return direct;
    final g = gold24;
    return g == null ? null : g * karat / 24;
  }

  /// AED per 1 unit of [currency]; AED is 1, USD falls back to the peg.
  double? fx(String currency) {
    final c = currency.toUpperCase();
    if (c == 'AED') return 1.0;
    final q = _quotes['FX_${c}_AED']?.price;
    if (q != null) return q;
    if (c == 'USD') return usdPeg;
    return null;
  }

  static const usdPeg = 3.6725;
}

double? _num(Object? v) => switch (v) {
  num n => n.toDouble(),
  String s => double.tryParse(s),
  _ => null,
};

DateTime? _time(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toUtc() : null;

/// Parses the backend snapshot into quotes. Tolerant: anything missing or
/// malformed is skipped, so a partial payload still updates what it can.
/// Decimals may arrive as strings.
List<PriceQuote> parseSnapshot(Object? json, {required DateTime fetchedAt}) {
  if (json is! Map) return const [];
  final out = <PriceQuote>[];
  final gold = json['gold'];
  if (gold is Map) {
    final status = gold['status'] is String ? gold['status'] as String : 'live';
    final perGram = gold['per_gram'];
    if (status != 'unavailable' && perGram is Map) {
      for (final k in PriceBook.goldKarats) {
        final aed = perGram['${k}k'] is Map
            ? _num((perGram['${k}k'] as Map)['aed'])
            : null;
        if (aed != null && aed > 0) {
          out.add(
            PriceQuote(
              symbol: 'XAU_AED_G_${k}K',
              price: aed,
              source: gold['source'] as String?,
              status: status,
              quotedAt: _time(gold['last_updated']),
              fetchedAt: fetchedAt,
            ),
          );
        }
      }
    }
  }
  final fx = json['fx'];
  if (fx is List) {
    for (final e in fx) {
      if (e is! Map) continue;
      final ccy = e['currency'];
      final rate = _num(e['aed_per_unit']);
      final status = e['status'] is String ? e['status'] as String : 'live';
      if (ccy is String &&
          rate != null &&
          rate > 0 &&
          status != 'unavailable') {
        out.add(
          PriceQuote(
            symbol: 'FX_${ccy.toUpperCase()}_AED',
            price: rate,
            source: e['source'] as String?,
            status: status,
            quotedAt: _time(e['last_updated']),
            fetchedAt: fetchedAt,
          ),
        );
      }
    }
  }
  return out;
}

/// Last-known values bundled with the app so a fresh install with no network
/// still shows a value. Illustrative demo figures (not live), dated by
/// [bundledPricesAsOf]; the UI labels them as such.
final bundledPricesAsOf = DateTime.utc(2026, 11, 1);

PriceBook bundledPriceBook() => PriceBook([
  for (final k in PriceBook.goldKarats)
    PriceQuote(
      symbol: 'XAU_AED_G_${k}K',
      price: double.parse((470.0 * k / 24).toStringAsFixed(2)),
      source: 'bundled demo value',
      status: 'stale',
      quotedAt: bundledPricesAsOf,
      fetchedAt: bundledPricesAsOf,
    ),
  PriceQuote(
    symbol: 'FX_USD_AED',
    price: 3.6725,
    source: 'bundled demo value',
    status: 'stale',
    quotedAt: bundledPricesAsOf,
    fetchedAt: bundledPricesAsOf,
  ),
  PriceQuote(
    symbol: 'FX_INR_AED',
    price: 0.0425,
    source: 'bundled demo value',
    status: 'stale',
    quotedAt: bundledPricesAsOf,
    fetchedAt: bundledPricesAsOf,
  ),
  PriceQuote(
    symbol: 'FX_EUR_AED',
    price: 4.28,
    source: 'bundled demo value',
    status: 'stale',
    quotedAt: bundledPricesAsOf,
    fetchedAt: bundledPricesAsOf,
  ),
  PriceQuote(
    symbol: 'FX_GBP_AED',
    price: 4.9,
    source: 'bundled demo value',
    status: 'stale',
    quotedAt: bundledPricesAsOf,
    fetchedAt: bundledPricesAsOf,
  ),
], origin: PriceOrigin.bundled);

/// Merges [primary] over [fallback] per symbol, so a partial cache is filled
/// from the bundled values. Origin follows [primary] when it has gold.
PriceBook mergeBooks(PriceBook primary, PriceBook fallback) {
  final merged = {
    for (final q in fallback.quotes) q.symbol: q,
    for (final q in primary.quotes) q.symbol: q,
  };
  return PriceBook(
    merged.values,
    origin: primary.gold24 != null ? primary.origin : PriceOrigin.bundled,
  );
}
