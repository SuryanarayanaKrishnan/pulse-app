/// Turns the text a phone read off a screenshot (OCR) or a sentence the user
/// typed into draft holdings. Pure Dart, no I/O: the ML Kit call lives in
/// `data/local/ocr_service.dart`, so everything here is unit-tested on plain
/// strings.
///
/// Nothing is certain from OCR, so every draft says what it could not read
/// ([GoldDraft.missing], [HoldingDraft.missing]) and carries an
/// `approximate` flag the user can see and change before anything is saved.
library;

import 'dates.dart';

enum CaptureKind { goldBill, portfolio, unknown }

/// A gold purchase read from a bill, or typed by hand.
class GoldDraft {
  const GoldDraft({
    this.name = 'Gold',
    this.weightGrams,
    this.karat,
    this.amountMinor,
    this.date,
    this.approximate = false,
    this.note,
  });

  final String name;
  final double? weightGrams;
  final int? karat;

  /// What was paid, AED fils.
  final int? amountMinor;
  final CalDate? date;
  final bool approximate;

  /// Why it is approximate, for the review screen.
  final String? note;

  /// What the review screen still has to ask for.
  List<String> get missing => [
    if (weightGrams == null) 'weight',
    if (karat == null) 'karat',
  ];

  bool get usable => weightGrams != null && weightGrams! > 0;
}

/// One stock, ETF or fund line read from a portfolio screenshot, or typed.
class HoldingDraft {
  const HoldingDraft({
    required this.symbol,
    this.name,
    this.quantity,
    this.avgCost,
    this.price,
    this.value,
    this.currency = 'USD',
    this.approximate = false,
    this.note,
  });

  /// Upper-case ticker, e.g. `VOO`.
  final String symbol;
  final String? name;
  final double? quantity, avgCost, price, value;
  final String currency;
  final bool approximate;
  final String? note;

  /// Units, from the quantity or from value / price when only those were seen.
  double? get units {
    if (quantity != null) return quantity;
    if (value != null && price != null && price! > 0) return value! / price!;
    return null;
  }

  List<String> get missing => [if (units == null) 'quantity'];

  HoldingDraft copyWith({
    String? symbol,
    double? quantity,
    double? avgCost,
    bool? approximate,
    String? note,
  }) => HoldingDraft(
    symbol: symbol ?? this.symbol,
    name: name,
    quantity: quantity ?? this.quantity,
    avgCost: avgCost ?? this.avgCost,
    price: price,
    value: value,
    currency: currency,
    approximate: approximate ?? this.approximate,
    note: note ?? this.note,
  );
}

class CaptureResult {
  const CaptureResult(this.kind, {this.gold, this.holdings = const []});
  final CaptureKind kind;
  final GoldDraft? gold;
  final List<HoldingDraft> holdings;

  bool get isEmpty => gold == null && holdings.isEmpty;
}

// ---- numbers ---------------------------------------------------------------

final _numRe = RegExp(r'\d[\d,]*(?:\.\d+)?');

/// 1,234.50 -> 1234.5. OCR sometimes reads a decimal comma ("12,5"): a comma
/// followed by one or two digits at the end is a decimal, otherwise grouping.
double? parseLooseNumber(String s) {
  var t = s.trim();
  if (t.isEmpty) return null;
  if (RegExp(r'^\d+,\d{1,2}$').hasMatch(t)) t = t.replaceFirst(',', '.');
  t = t.replaceAll(',', '');
  return double.tryParse(t);
}

/// Every number in [s], in order.
List<double> numbersIn(String s) => [
  for (final m in _numRe.allMatches(s)) ?parseLooseNumber(m[0]!),
];

int _toMinor(double v) => (v * 100).round();

// ---- gold -------------------------------------------------------------------

const _goldWords = [
  'gold',
  'jewel',
  'ring',
  'chain',
  'bar',
  'coin',
  'necklace',
  'bangle',
  'bracelet',
  'earring',
  'pendant',
  'ornament',
  'karat',
  'carat',
  'jewellery',
  'jewelry',
  '916',
  '999',
];

final _weightRe = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:g|gm|gms|gr|grm|grms|gram|grams)\b',
  caseSensitive: false,
);
final _karatRe = RegExp(
  r'\b(24|22|21|18)\s*(?:k|kt|ct|karat|carat)\b',
  caseSensitive: false,
);
final _finenessRe = RegExp(r'\b(999(?:\.9)?|916|875|750)\b');

int? _karatFromFineness(String f) => switch (f) {
  '999' || '999.9' => 24,
  '916' => 22,
  '875' => 21,
  '750' => 18,
  _ => null,
};

const _goldItems = {
  'bar': 'Gold bar',
  'coin': 'Gold coin',
  'chain': 'Gold chain',
  'ring': 'Gold ring',
  'necklace': 'Gold necklace',
  'bangle': 'Gold bangles',
  'bracelet': 'Gold bracelet',
  'earring': 'Gold earrings',
  'pendant': 'Gold pendant',
};

/// Reads weight, karat, amount, date and item from a gold bill / invoice.
GoldDraft parseGoldBill(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final lower = text.toLowerCase();

  // Weight: a labelled net weight beats a labelled weight beats the first one.
  double? weight;
  int rank = 0;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final ws = [
      for (final m in _weightRe.allMatches(l)) ?parseLooseNumber(m[1]!),
    ].where((v) => v > 0 && v <= 20000).toList();
    if (ws.isEmpty) continue;
    // "Gross Wt  Net Wt" over "21.40 gm  20.35 gm": net is never the larger.
    final v = ws.reduce((a, b) => a < b ? a : b);
    final ll = l.toLowerCase();
    final head = i > 0 ? lines[i - 1].toLowerCase() : '';
    final r = (ll.contains('net') || (ws.length > 1 && head.contains('net')))
        ? 3
        : (ll.contains('weight') || ll.contains('wt'))
        ? (ll.contains('gross') ? 1 : 2)
        : 1;
    if (r > rank) {
      rank = r;
      weight = v;
    }
  }

  int? karat;
  final km = _karatRe.firstMatch(text);
  if (km != null) {
    karat = int.parse(km[1]!);
  } else {
    final fm = _finenessRe.firstMatch(text);
    if (fm != null) karat = _karatFromFineness(fm[1]!);
  }

  // Amount: the largest figure on a "total / amount / net / payable" line;
  // else the largest AED figure anywhere.
  int? amount;
  double best = 0;
  final labelled = RegExp(
    r'total|amount|net\s*pay|payable|grand|price|paid',
    caseSensitive: false,
  );
  for (final l in lines) {
    if (!labelled.hasMatch(l)) continue;
    if (RegExp(r'weight|\bwt\b|vat|tax', caseSensitive: false).hasMatch(l) &&
        !l.toLowerCase().contains('total'))
      continue;
    for (final v in numbersIn(l)) {
      if (v > best && v >= 10) {
        best = v;
      }
    }
  }
  if (best == 0) {
    for (final m in RegExp(
      r'(?:aed|dhs?\.?|د\.إ)[ \t]*([\d,]+(?:\.\d+)?)|([\d,]+(?:\.\d+)?)[ \t]*(?:aed|dhs?\b)',
      caseSensitive: false,
    ).allMatches(text)) {
      final v = parseLooseNumber(m[1] ?? m[2] ?? '');
      if (v != null && v > best) best = v;
    }
  }
  if (best > 0) amount = _toMinor(best);

  CalDate? date;
  for (final m in RegExp(dateRe).allMatches(text)) {
    final d = parseDate(m[0]!);
    if (d != null && d.year >= 1990 && d.year <= DateTime.now().year + 1) {
      date = d;
      break;
    }
  }

  var name = 'Gold';
  for (final e in _goldItems.entries) {
    if (RegExp('\\b${e.key}s?\\b', caseSensitive: false).hasMatch(lower)) {
      name = e.value;
      break;
    }
  }

  return GoldDraft(
    name: name,
    weightGrams: weight,
    karat: karat,
    amountMinor: amount,
    date: date,
  );
}

// ---- portfolio --------------------------------------------------------------

/// All-caps words that are not tickers.
const _notTickers = {
  'USD',
  'AED',
  'INR',
  'EUR',
  'GBP',
  'ETF',
  'ETFS',
  'NAV',
  'ALL',
  'TOTAL',
  'DAY',
  'GAIN',
  'LOSS',
  'P&L',
  'PNL',
  'BUY',
  'SELL',
  'QTY',
  'AVG',
  'COST',
  'PRICE',
  'VALUE',
  'CASH',
  'NET',
  'THE',
  'AND',
  'FOR',
  'NEW',
  'TODAY',
  'MARKET',
  'LAST',
  'SHARES',
  'SHARE',
  'UNITS',
  'HOLDINGS',
  'STOCKS',
  'STOCK',
  'FUND',
  'FUNDS',
  'RETURN',
  'RETURNS',
  'OPEN',
  'CLOSE',
  'ORDERS',
  'ORDER',
  'WATCHLIST',
  'PORTFOLIO',
  'OVERVIEW',
  'INVESTED',
  'CURRENT',
  'ACCOUNT',
  'BALANCE',
  'MORE',
  'EDIT',
  'DONE',
  'VIEW',
  'SEE',
  'TRADE',
  'NYSE',
  'NASDAQ',
  'LSE',
  'DFM',
  'ADX',
  'PM',
  'AM',
  'USA',
  'UAE',
  'IRA',
  'ROTH',
  'PDF',
};

/// Names people write instead of the ticker.
const _knownNames = {
  'vanguard s&p 500': 'VOO',
  's&p 500 etf': 'VOO',
  'vanguard total stock': 'VTI',
  'vanguard total world': 'VT',
  'spdr s&p 500': 'SPY',
  'invesco qqq': 'QQQ',
  'apple': 'AAPL',
  'microsoft': 'MSFT',
  'alphabet': 'GOOGL',
  'amazon': 'AMZN',
  'tesla': 'TSLA',
  'nvidia': 'NVDA',
  'meta platforms': 'META',
  'schwab us dividend': 'SCHD',
};

final _tickerRe = RegExp(
  r'(?<![A-Za-z0-9$])\$?([A-Z]{1,5}(?:[.\-][A-Z])?)(?![A-Za-z0-9])',
);
final _qtyRe = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(?:shares?|units?|qty|sh\b|x\b)',
  caseSensitive: false,
);
final _qtyLabelRe = RegExp(
  r'(?:qty|quantity|shares|units)\s*[:\-]?\s*(\d+(?:[.,]\d+)?)',
  caseSensitive: false,
);

/// Number following one of [labels] on the same line (or the next number).
double? _labelled(String block, RegExp label) {
  final m = label.firstMatch(block);
  if (m == null) return null;
  final rest = block.substring(m.end);
  final n = _numRe.firstMatch(rest);
  return n == null ? null : parseLooseNumber(n[0]!);
}

final _avgRe = RegExp(
  r'avg\.?(?:\s*(?:cost|price|buy))?|average\s*(?:cost|price|buy)?|cost\s*basis|bought\s*(?:at|@)',
  caseSensitive: false,
);
final _priceRe = RegExp(
  r'(?:last|market|current|mkt)\s*price|\bprice\b|\bltp\b|\bnav\b',
  caseSensitive: false,
);
final _valueRe = RegExp(
  r'(?:market|current|total)?\s*value|equity|worth',
  caseSensitive: false,
);

/// Reads positions out of a brokerage or fund-app screenshot. A "block" is a
/// ticker line plus the lines under it up to the next ticker.
List<HoldingDraft> parsePortfolio(String text) {
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final starts = <int>[];
  final symbols = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final s = _tickerIn(lines[i]);
    if (s != null) {
      starts.add(i);
      symbols.add(s);
    }
  }
  final out = <HoldingDraft>[];
  final seen = <String>{};
  for (var k = 0; k < starts.length; k++) {
    final end = k + 1 < starts.length ? starts[k + 1] : lines.length;
    final block = lines.sublist(starts[k], end).join('\n');
    final sym = symbols[k];
    final h = _holdingFromBlock(sym, block);
    if (h != null && seen.add(sym)) out.add(h);
  }
  return out;
}

String? _tickerIn(String line) {
  final lower = line.toLowerCase();
  for (final e in _knownNames.entries) {
    if (lower.contains(e.key)) return e.value;
  }
  for (final m in _tickerRe.allMatches(line)) {
    final t = m[1]!;
    if (_notTickers.contains(t)) continue;
    if (t.length == 1 && !line.startsWith(t)) continue;
    // A ticker line is mostly the ticker (and maybe a name): skip sentences.
    if (line.split(RegExp(r'\s+')).length > 9) continue;
    return t;
  }
  return null;
}

HoldingDraft? _holdingFromBlock(String sym, String block) {
  final qty = _firstNum(_qtyLabelRe, block) ?? _firstNum(_qtyRe, block);
  final avg = _labelled(block, _avgRe);
  final price = _labelled(block, _priceRe);
  final value = _labelled(block, _valueRe);
  final hasMoney =
      block.contains(r'$') || RegExp(r'\d+\.\d{2}').hasMatch(block);
  if (qty == null &&
      value == null &&
      !(hasMoney && numbersIn(block).length >= 2))
    return null;
  final firstLine = block.split('\n').first;
  final name = firstLine
      .replaceAll(RegExp('\\\$?$sym'), '')
      .replaceAll(RegExp(r'[\d.,$%+\-]+'), '')
      .trim();
  var currency = 'USD';
  if (RegExp(r'\bAED\b|\bDhs?\b', caseSensitive: false).hasMatch(block))
    currency = 'AED';
  if (block.contains('₹') || RegExp(r'\bINR\b').hasMatch(block))
    currency = 'INR';
  return HoldingDraft(
    symbol: sym,
    name: name.length >= 3 ? name : null,
    quantity: qty,
    avgCost: avg,
    price: price,
    value: value,
    currency: currency,
  );
}

double? _firstNum(RegExp re, String s) {
  final m = re.firstMatch(s);
  return m == null ? null : parseLooseNumber(m[1]!);
}

// ---- what is this screenshot? --------------------------------------------------

CaptureKind classify(String text) {
  final lower = text.toLowerCase();
  final goldHits = _goldWords.where(lower.contains).length;
  final hasWeight = _weightRe.hasMatch(text);
  if ((goldHits >= 2 && hasWeight) || (lower.contains('gold') && hasWeight))
    return CaptureKind.goldBill;
  if (parsePortfolio(text).isNotEmpty) return CaptureKind.portfolio;
  if (goldHits >= 1 && hasWeight) return CaptureKind.goldBill;
  return CaptureKind.unknown;
}

/// One call for the scan screen.
CaptureResult parseCapture(String text) {
  switch (classify(text)) {
    case CaptureKind.goldBill:
      return CaptureResult(CaptureKind.goldBill, gold: parseGoldBill(text));
    case CaptureKind.portfolio:
      return CaptureResult(
        CaptureKind.portfolio,
        holdings: parsePortfolio(text),
      );
    case CaptureKind.unknown:
      return const CaptureResult(CaptureKind.unknown);
  }
}

// ---- "about 20g 22k gold bought 2023" -------------------------------------------

final _yearRe = RegExp(r'\b(19[89]\d|20[0-4]\d)\b');

/// Free text typed instead of a screenshot. Everything it returns is
/// approximate and says so; missing details stay null for the user to fill or
/// leave out.
CaptureResult parseApproximate(String text, {CalDate? today}) {
  final t = text.trim();
  if (t.isEmpty) return const CaptureResult(CaptureKind.unknown);
  final lower = t.toLowerCase();
  final isGold = _goldWords.any(
    (w) => w.length > 3
        ? lower.contains(w)
        : RegExp('\\b${w}s?\\b').hasMatch(lower),
  );
  final year = _yearRe.firstMatch(t);
  final CalDate? when = year == null
      ? null
      : CalDate(int.parse(year[1]!), 7, 1);

  if (isGold) {
    final wm = _weightRe.firstMatch(t);
    final weight = wm == null ? null : parseLooseNumber(wm[1]!);
    final km = _karatRe.firstMatch(t);
    final fm = _finenessRe.firstMatch(t);
    final karat = km != null
        ? int.parse(km[1]!)
        : (fm != null ? _karatFromFineness(fm[1]!) : null);
    // "for 5000 aed" / "paid AED 5,000"
    int? amount;
    final am = RegExp(
      r'(?:for|paid|cost|at)\s*(?:aed|dhs?)?\s*([\d,]+(?:\.\d+)?)\s*(?:aed|dhs?)?',
      caseSensitive: false,
    ).firstMatch(t);
    if (am != null &&
        !RegExp(
          r'^\s*(?:g|gm|gram)',
          caseSensitive: false,
        ).hasMatch(t.substring(am.end))) {
      final v = parseLooseNumber(am[1]!);
      if (v != null && v >= 100) amount = _toMinor(v);
    }
    var name = 'Gold';
    for (final e in _goldItems.entries) {
      if (RegExp('\\b${e.key}s?\\b', caseSensitive: false).hasMatch(lower)) {
        name = e.value;
        break;
      }
    }
    final notes = [
      if (karat == null) 'karat assumed 22K',
      if (when != null) 'bought around ${when.year}',
    ];
    return CaptureResult(
      CaptureKind.goldBill,
      gold: GoldDraft(
        name: name,
        weightGrams: weight,
        karat: karat ?? 22,
        amountMinor: amount,
        date: when,
        approximate: true,
        note: notes.isEmpty ? 'approximate' : notes.join(' · '),
      ),
    );
  }

  // "50 shares of VOO bought 2022 avg 400"  /  "VOO 12.5 units"
  final qm = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:shares?|units?|x)?\s*(?:of\s+)?(\$?[A-Za-z]{1,5}(?:[.\-][A-Za-z])?)\b',
  ).firstMatch(t);
  String? sym;
  double? qty;
  for (final e in _knownNames.entries) {
    if (lower.contains(e.key)) sym = e.value;
  }
  final tm = RegExp(r'(?:\bof\s+|\b)\$?([A-Z]{1,5})\b')
      .allMatches(t)
      .map((m) => m[1]!)
      .where((s) => !_notTickers.contains(s));
  sym ??= tm.isEmpty ? null : tm.first;
  if (sym == null && qm != null) {
    final cand = qm[2]!.toUpperCase();
    if (!_notTickers.contains(cand) && cand.length >= 2) sym = cand;
  }
  if (sym == null) return const CaptureResult(CaptureKind.unknown);
  final qtyM =
      RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(?:shares?|units?)',
        caseSensitive: false,
      ).firstMatch(t) ??
      RegExp(
        '(\\d+(?:[.,]\\d+)?)\\s*(?:of\\s+)?\\\$?$sym',
        caseSensitive: false,
      ).firstMatch(t) ??
      RegExp(
        '$sym\\s*[x:]?\\s*(\\d+(?:[.,]\\d+)?)',
        caseSensitive: false,
      ).firstMatch(t);
  if (qtyM != null) qty = parseLooseNumber(qtyM[1]!);
  final avgM = RegExp(
    r'(?:avg\.?|average|@|at)\s*(?:cost|price)?\s*\$?\s*(\d+(?:\.\d+)?)',
    caseSensitive: false,
  ).firstMatch(t);
  final avg = avgM == null ? null : double.tryParse(avgM[1]!);
  final notes = [
    if (qty == null) 'quantity unknown',
    if (when != null) 'bought around ${when.year}',
  ];
  return CaptureResult(
    CaptureKind.portfolio,
    holdings: [
      HoldingDraft(
        symbol: sym,
        quantity: qty,
        avgCost: avg,
        approximate: true,
        note: notes.isEmpty ? 'approximate' : notes.join(' · '),
      ),
    ],
  );
}
