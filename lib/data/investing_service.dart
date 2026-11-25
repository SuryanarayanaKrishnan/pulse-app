import 'package:dio/dio.dart';

import '../core/engine/capture_parser.dart';
import '../core/engine/dates.dart';
import '../core/engine/investing.dart';
import '../core/engine/prices.dart';
import '../core/engine/valuation.dart';
import 'local/investing_store.dart';
import 'local/wealth_store.dart' show newWealthId;
import 'models.dart';
import 'stock_assets.dart';
import 'wealth_models.dart';
import 'wealth_service.dart';

/// The last close of one ticker.
class StockQuote {
  const StockQuote({
    required this.symbol,
    required this.price,
    this.status = 'live',
    this.updatedAt,
    this.source,
  });
  final String symbol;
  final double price;
  final String status;
  final DateTime? updatedAt;
  final String? source;
}

/// Prices for the tickers a phone tracks, through the Pulse price service
/// (`GET /v1/prices/stocks`, free Stooq data cached server side). Only the
/// ticker symbols leave the phone: no quantities, costs or amounts.
class StockQuoteService {
  StockQuoteService(this.dio);
  final Dio? dio;

  bool get available => dio != null;

  Future<Map<String, StockQuote>> fetch(Iterable<String> symbols) async {
    final client = dio;
    final list = {for (final s in symbols) s.toUpperCase()}.toList();
    if (client == null || list.isEmpty) return const {};
    final res = await client.get<Object?>(
      '/v1/prices/stocks',
      queryParameters: {'tickers': list.join(',')},
    );
    return parseStockQuotes(res.data);
  }
}

/// Tolerant parse of the backend payload; keys are upper-case bare tickers
/// (`voo.us` -> `VOO`). Unknown tickers (null price) are left out.
Map<String, StockQuote> parseStockQuotes(Object? json) {
  final out = <String, StockQuote>{};
  final quotes = json is Map ? json['quotes'] : null;
  if (quotes is! List) return out;
  for (final q in quotes) {
    if (q is! Map) continue;
    final t = q['ticker'];
    final usd = switch (q['usd']) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    final status = q['status'] is String ? q['status'] as String : 'live';
    if (t is! String || usd == null || usd <= 0 || status == 'unavailable')
      continue;
    final sym = t.toUpperCase().replaceAll(RegExp(r'\.US$'), '');
    out[sym] = StockQuote(
      symbol: sym,
      price: usd,
      status: status,
      updatedAt: q['last_updated'] is String
          ? DateTime.tryParse(q['last_updated'] as String)?.toUtc()
          : null,
      source: q['source'] as String?,
    );
  }
  return out;
}

class StockView {
  const StockView(this.holding, this.value, {this.priceStale = false});
  final StockHolding holding;
  final FundValue value;

  /// The price is older than a day or was never fetched.
  final bool priceStale;
  bool get hasPrice => holding.lastPrice != null;
}

class RuleView {
  const RuleView({
    required this.rule,
    required this.next,
    required this.adherence,
    required this.pending,
  });
  final InvestRule rule;
  final CalDate? next;
  final Adherence adherence;
  final List<RuleOccurrence> pending;
}

/// What happened when a scan was saved.
class ApplyReport {
  const ApplyReport({
    this.goldAdded = 0,
    this.holdingsAdded = 0,
    this.holdingsUpdated = 0,
    this.skipped = 0,
  });
  final int goldAdded, holdingsAdded, holdingsUpdated, skipped;
  int get saved => goldAdded + holdingsAdded + holdingsUpdated;
}

/// Stocks, ETFs, gold from scans, and recurring investing rules, all on the
/// phone. Prices come from [StockQuoteService] (tickers only) and the cached
/// FX/gold book; without a network the last price stays and is labelled stale.
class InvestingService {
  InvestingService({
    required this.store,
    required this.wealth,
    required this.quotes,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final InvestingStore store;
  final WealthService wealth;
  final StockQuoteService quotes;
  final DateTime Function() _clock;

  CalDate get today {
    final n = _clock();
    return CalDate(n.year, n.month, n.day);
  }

  // ---- holdings -----------------------------------------------------------------

  FundValue valueOf(StockHolding h, PriceBook b) => valueStock(h, b);

  Future<List<StockView>> holdingViews() async {
    final b = await wealth.book();
    final now = _clock();
    return [
      for (final h in await store.holdings())
        StockView(
          h,
          valueOf(h, b),
          priceStale:
              h.priceAt == null || now.difference(h.priceAt!).inHours > 24,
        ),
    ];
  }

  Future<StockHolding> saveHolding(StockHolding h) => store.saveHolding(h);
  Future<void> deleteHolding(String id) => store.deleteHolding(id);

  /// Updates the last price of every USD holding from the price service.
  /// Returns how many changed; offline or source-down keeps the old price.
  Future<int> refreshPrices() async {
    if (!quotes.available) return 0;
    final all = await store.holdings();
    final usd = [
      for (final h in all)
        if (h.currency == 'USD') h,
    ];
    if (usd.isEmpty) return 0;
    try {
      final got = await quotes.fetch(usd.map((h) => h.symbol));
      var n = 0;
      for (final h in usd) {
        final q = got[h.symbol];
        if (q == null) continue;
        await store.saveHolding(
          h.copyWith(
            lastPrice: q.price,
            priceAt: _clock().toUtc(),
            priceSource: q.source ?? 'market',
          ),
        );
        n++;
      }
      return n;
    } on Object {
      return 0;
    }
  }

  // ---- saving a scan ---------------------------------------------------------------

  /// Saves reviewed drafts. Gold goes to jewellery (valued from the gold
  /// price); a position replaces an existing one with the same ticker, since a
  /// screenshot is a snapshot of what is held now.
  Future<ApplyReport> applyCapture(
    CaptureResult r, {
    String source = 'screenshot',

    /// Temporary image paths (the scanned bill), kept as the gold piece's photo.
    List<String> photoSources = const [],
  }) async {
    var gold = 0, added = 0, updated = 0, skipped = 0;
    final g = r.gold;
    if (g != null) {
      if (g.usable) {
        await wealth.saveJewellery(
          JewelleryItem(
            id: newWealthId(),
            name: g.name,
            weightGrams: g.weightGrams!,
            karat: g.karat ?? 22,
            purchasePriceMinor: g.amountMinor,
            purchaseDate: g.date,
            notes: g.note,
            approximate: g.approximate || g.karat == null,
            createdAt: _clock().toUtc(),
          ),
          newPhotoSources: photoSources,
        );
        gold++;
      } else {
        skipped++;
      }
    }
    final existing = await store.holdings();
    for (final d in r.holdings) {
      final units = d.units;
      if (units == null || units <= 0) {
        skipped++;
        continue;
      }
      final price = d.price ?? (d.value != null ? d.value! / units : null);
      final now = _clock().toUtc();
      final match = existing.where((h) => h.symbol == d.symbol).firstOrNull;
      if (match != null) {
        await store.saveHolding(
          match.copyWith(
            name: d.name,
            quantity: units,
            avgCost: d.avgCost,
            lastPrice: price,
            priceAt: price == null ? null : now,
            priceSource: price == null ? null : 'screenshot',
            approximate: d.approximate,
            source: source,
            note: d.note,
          ),
        );
        updated++;
      } else {
        await store.saveHolding(
          StockHolding(
            id: newWealthId(),
            symbol: d.symbol,
            name: d.name,
            currency: d.currency,
            quantity: units,
            avgCost: d.avgCost,
            lastPrice: price,
            priceAt: price == null ? null : now,
            priceSource: price == null ? null : 'screenshot',
            approximate: d.approximate,
            source: source,
            note: d.note,
            createdAt: now,
          ),
        );
        added++;
      }
    }
    if (added + updated > 0) await refreshPrices();
    return ApplyReport(
      goldAdded: gold,
      holdingsAdded: added,
      holdingsUpdated: updated,
      skipped: skipped,
    );
  }

  // ---- rules -----------------------------------------------------------------------

  Future<InvestRule> saveRule(InvestRule r) => store.saveRule(r);
  Future<void> deleteRule(String id) => store.deleteRule(id);

  InvestRule newRule(RuleDraft d, {String? name}) => InvestRule(
    id: newWealthId(),
    symbol: d.symbol,
    name: name,
    amountMinor: d.amountMinor,
    currency: d.currency,
    frequency: d.frequency,
    day: d.day,
    startDate: today,
  );

  static String occurrenceId(String ruleId, CalDate due) =>
      '$ruleId:${due.toIso()}';

  /// Records a pending "did you buy?" for every planned buy that is due and
  /// not yet decided. Idempotent: ids are derived from rule and date.
  Future<void> syncOccurrences() async {
    final t = today;
    for (final r in await store.rules()) {
      final recorded = {
        for (final o in await store.occurrences(ruleId: r.id)) o.due,
      };
      for (final d in dueButUnrecorded(r, recorded, t)) {
        await store.saveOccurrence(
          RuleOccurrence(
            id: occurrenceId(r.id, d),
            ruleId: r.id,
            due: d,
            amountMinor: r.amountMinor,
          ),
        );
      }
    }
  }

  Future<List<RuleView>> ruleViews() async {
    await syncOccurrences();
    final t = today;
    return [
      for (final r in await store.rules())
        await () async {
          final occ = await store.occurrences(ruleId: r.id);
          return RuleView(
            rule: r,
            next: nextDue(r, t),
            adherence: adherenceOf(occ),
            pending: [
              for (final o in occ)
                if (o.status == OccurrenceStatus.pending) o,
            ],
          );
        }(),
    ];
  }

  /// Every buy waiting for a yes or no, oldest first.
  Future<List<({InvestRule rule, RuleOccurrence occurrence})>>
  pendingBuys() async {
    final out = <({InvestRule rule, RuleOccurrence occurrence})>[];
    for (final v in await ruleViews()) {
      for (final o in v.pending) {
        out.add((rule: v.rule, occurrence: o));
      }
    }
    out.sort((a, b) => a.occurrence.due.compareTo(b.occurrence.due));
    return out;
  }

  /// Marks a planned buy as done at [price] per unit (default: the holding's
  /// last price) and adds the units to the holding at a weighted cost.
  /// Returns false when there is no price to work with.
  Future<bool> confirmBuy(
    String occurrenceId, {
    double? price,
    double? amount,
  }) async {
    final occ = (await store.occurrences())
        .where((o) => o.id == occurrenceId)
        .firstOrNull;
    if (occ == null) return false;
    final rule = (await store.rules())
        .where((r) => r.id == occ.ruleId)
        .firstOrNull;
    if (rule == null) return false;
    final holdings = await store.holdings();
    final held = holdings.where((h) => h.symbol == rule.symbol).firstOrNull;
    final p = price ?? held?.lastPrice;
    if (p == null || p <= 0) return false;

    final b = await wealth.book();
    final ccy = held?.currency ?? rule.currency;
    var amt = amount ?? occ.amountMinor / 100;
    if (amount == null && rule.currency != ccy) {
      final from = b.fx(rule.currency), to = b.fx(ccy);
      if (from != null && to != null && to > 0) amt = amt * from / to;
    }
    final res = applyBuy(
      units: held?.quantity ?? 0,
      avgCost: held?.avgCost,
      amount: amt,
      price: p,
    );
    final now = _clock().toUtc();
    if (held != null) {
      await store.saveHolding(
        held.copyWith(
          quantity: res.units,
          avgCost: res.avgCost > 0 ? res.avgCost : null,
          clearAvg: res.avgCost <= 0,
          lastPrice: price ?? held.lastPrice,
          priceAt: price != null ? now : held.priceAt,
        ),
      );
    } else {
      await store.saveHolding(
        StockHolding(
          id: newWealthId(),
          symbol: rule.symbol,
          name: rule.name,
          currency: ccy,
          quantity: res.units,
          avgCost: res.avgCost,
          lastPrice: p,
          priceAt: now,
          priceSource: 'rule',
          source: 'rule',
          createdAt: now,
        ),
      );
    }
    await store.saveOccurrence(
      RuleOccurrence(
        id: occ.id,
        ruleId: occ.ruleId,
        due: occ.due,
        amountMinor: occ.amountMinor,
        status: OccurrenceStatus.confirmed,
        price: p,
        units: res.bought,
        decidedOn: today,
      ),
    );
    return true;
  }

  Future<void> skipBuy(String occurrenceId) async {
    final occ = (await store.occurrences())
        .where((o) => o.id == occurrenceId)
        .firstOrNull;
    if (occ == null) return;
    await store.saveOccurrence(
      RuleOccurrence(
        id: occ.id,
        ruleId: occ.ruleId,
        due: occ.due,
        amountMinor: occ.amountMinor,
        status: OccurrenceStatus.skipped,
        decidedOn: today,
      ),
    );
  }

  // ---- net worth ---------------------------------------------------------------------

  Future<List<Asset>> assets(PriceBook b) async => stockAssets(await store.holdings(), b);
}
