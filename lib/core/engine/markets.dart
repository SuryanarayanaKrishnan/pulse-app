/// Which exchange a ticker lives on and what it trades in.
///
/// US tickers are stored bare (`VOO`). Everything else carries its exchange
/// suffix (`RELIANCE.NS`, `EMAAR.DFM`) so a symbol is unambiguous on its own.
/// Pure Dart, no I/O.
library;

enum Exchange {
  us('US', 'US', 'USD', 'US markets', livePrice: true),
  nse('NSE', 'NS', 'INR', 'India (NSE)', livePrice: true),
  bse('BSE', 'BO', 'INR', 'India (BSE)', livePrice: false),
  dfm('DFM', 'DFM', 'AED', 'Dubai (DFM)', livePrice: false),
  adx('ADX', 'ADX', 'AED', 'Abu Dhabi (ADX)', livePrice: false);

  const Exchange(
    this.code,
    this.suffix,
    this.currency,
    this.label, {
    required this.livePrice,
  });
  final String code, suffix, currency, label;

  /// Pulse has a free price source for it. Otherwise the price is typed in.
  final bool livePrice;
}

class Listing {
  const Listing(this.base, this.exchange);

  /// Ticker without the exchange suffix, upper case.
  final String base;
  final Exchange exchange;

  String get symbol =>
      exchange == Exchange.us ? base : '$base.${exchange.suffix}';
  String get currency => exchange.currency;

  /// What the price service is asked for; null when there is no free source.
  String? get quoteTicker => switch (exchange) {
    Exchange.us => base.toLowerCase(),
    Exchange.nse => '${base.toLowerCase()}.ns',
    _ => null,
  };
}

final _suffixRe = RegExp(
  r'^(.+)\.(NS|NSE|BO|BSE|DFM|ADX)$',
  caseSensitive: false,
);

/// `reliance.ns`, `NSE:RELIANCE`, `EMAAR.DFM` or `VOO` -> a [Listing].
Listing listingOf(String raw) {
  var s = raw.trim().toUpperCase().replaceAll(r'$', '');
  final prefix = RegExp(r'^(NSE|BSE|DFM|ADX|NASDAQ|NYSE):(.+)$').firstMatch(s);
  if (prefix != null) {
    final ex = switch (prefix[1]!) {
      'NSE' => Exchange.nse,
      'BSE' => Exchange.bse,
      'DFM' => Exchange.dfm,
      'ADX' => Exchange.adx,
      _ => Exchange.us,
    };
    return Listing(prefix[2]!.trim(), ex);
  }
  final m = _suffixRe.firstMatch(s);
  if (m != null) {
    final ex = switch (m[2]!) {
      'NS' || 'NSE' => Exchange.nse,
      'BO' || 'BSE' => Exchange.bse,
      'DFM' => Exchange.dfm,
      _ => Exchange.adx,
    };
    return Listing(m[1]!, ex);
  }
  if (s.endsWith('.US')) s = s.substring(0, s.length - 3);
  return Listing(s, Exchange.us);
}

/// The canonical stored form of whatever the user typed.
String normaliseSymbol(String raw) => listingOf(raw).symbol;
