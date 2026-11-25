import 'package:dio/dio.dart';

import '../core/engine/capture_parser.dart';
import '../core/engine/dates.dart';
import '../core/engine/investing.dart';
import '../core/engine/markets.dart';
import '../core/engine/prices.dart';
import '../core/engine/valuation.dart';
import 'fund_match.dart';
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
    this.currency = 'USD',
    this.status = 'live',
    this.updatedAt,
    this.source,
  });
  final String symbol;
  final double price;

  /// What [price] is in: USD for US tickers, INR for NSE.
  final String currency;
  final String status;
  final DateTime? updatedAt;
  final String? source;
}

/// Prices for the tickers a phone tracks, through the Pulse price service
/// (`GET /v1/prices/stocks`: free Stooq data for US tickers and NSE's own
/// daily file for `.NS`, cached server side). Dubai (DFM), Abu Dhabi (ADX) and
/// BSE tickers have no free source, so they are never asked for and keep the
/// price the user typed. Only ticker symbols leave the phone: no quantities,
/// costs or amounts.
class StockQuoteService {
  StockQuoteService(this.dio);
  final Dio? dio;

  bool get available => dio != null;

  Future<Map<String, StockQuote>> fetch(Iterable<String> symbols) async {
    final client = dio;
    final list = {
      for (final s in symbols)
        if (listingOf(s).quoteTicker != null) listingOf(s).quoteTicker!,
    }.toList();
    if (client == null || list.isEmpty) return const {};
    final res = await client.get<Object?>(
      '/v1/prices/stocks',
      queryParameters: {'tickers': list.join(',')},
    );
    return parseStockQuotes(res.data);
  }
}

/// Tolerant parse of the backend payload; keys are stored symbols
/// (`voo.us` -> `VOO`, `reliance.ns` -> `RELIANCE.NS`). Unknown tickers (null
/// price) are left out. Older servers send only `usd`.
Map<String, StockQuote> parseStockQuotes(Object? json) {
  final out = <String, StockQuote>{};
  final quotes = json is Map ? json['quotes'] : null;
  if (quotes is! List) return out;
  for (final q in quotes) {
    if (q is! Map) continue;
    final t = q['ticker'];
    final raw = q['price'] ?? q['usd'];
    final usd = switch (raw) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    final currency = q['currency'] is String
        ? (q['currency'] as String).toUpperCase()
        : 'USD';
    final status = q['status'] is String ? q['status'] as String : 'live';
    if (t is! String || usd == null || usd <= 0 || status == 'unavailable')
      continue;
    final sym = listingOf(t).symbol;
    out[sym] = StockQuote(
      symbol: sym,
      price: usd,
      currency: currency,
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
    this.fundsAdded = 0,
    this.fundsUpdated = 0,
    this.sipsAdded = 0,
    this.fundsUnmatched = 0,
  });
  final int goldAdded, holdingsAdded, holdingsUpdated, skipped;
  final int fundsAdded, fundsUpdated, sipsAdded;

  /// Funds saved by hand (no scheme found, so no live NAV).
  final int fundsUnmatched;
  int get saved =>
      goldAdded + holdingsAdded + holdingsUpdated + fundsAdded + fundsUpdated;
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

  /// Updates the last price of every holding that has a free source (US and
  /// NSE tickers). Returns how many changed; offline or source-down keeps the
  /// old price, and DFM/ADX/BSE holdings keep the price the user typed.
  Future<int> refreshPrices() async {
    if (!quotes.available) return 0;
    final all = await store.holdings();
    final live = [
      for (final h in all)
        if (listingOf(h.symbol).exchange.livePrice) h,
    ];
    if (live.isEmpty) return 0;
    try {
      final got = await quotes.fetch(live.map((h) => h.symbol));
      var n = 0;
      for (final h in live) {
        final q = got[listingOf(h.symbol).symbol];
        // A price in another currency than the holding is never mixed in.
        if (q == null || q.currency != h.currency) continue;
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
    final f = await _applyFunds(r.funds);
    return ApplyReport(
      goldAdded: gold,
      holdingsAdded: added,
      holdingsUpdated: updated,
      skipped: skipped + f.skipped,
      fundsAdded: f.added,
      fundsUpdated: f.updated,
      sipsAdded: f.sips,
      fundsUnmatched: f.unmatched,
    );
  }

  // ---- Indian mutual funds -----------------------------------------------------------

  /// The AMFI scheme for a fund name, or null (offline, or no close match).
  Future<FundScheme?> matchScheme(String name) async {
    if (!wealth.fundLookup.available) return null;
    for (final q in searchQueries(name)) {
      try {
        final hits = await wealth.searchFunds(q);
        final pick = pickScheme(name, hits);
        if (pick != null) return pick;
        if (hits.isNotEmpty) return null; // found something, but not this fund
      } on Object {
        return null;
      }
    }
    return null;
  }

  Future<({int added, int updated, int skipped, int sips, int unmatched})>
  _applyFunds(List<FundDraft> drafts) async {
    var added = 0, updated = 0, skipped = 0, sips = 0, unmatched = 0;
    final existing = (await wealth.fundViews()).map((v) => v.holding).toList();
    for (final d in drafts) {
      // A typed "about 1 lakh in ..." has no units yet: they come from the
      // amount and the scheme's NAV below.
      var units = d.unitsHeld;
      final typedAmount = d.current ?? d.invested;
      if ((units == null || units <= 0) && (typedAmount == null || typedAmount <= 0)) {
        skipped++;
        continue;
      }
      final scheme = await matchScheme(d.name);
      double? nav = d.navUsed;
      String navDate = _clock().toUtc().toIso8601String().substring(0, 10);
      var navSource = 'manual';
      DateTime? fetched;
      if (scheme != null) {
        try {
          final latest = await wealth.fundLookup.latest(scheme.code);
          if (latest != null) {
            nav = latest.nav;
            navDate = latest.navDate;
            navSource = 'market';
            fetched = _clock().toUtc();
          }
        } on Object {
          // Keep the NAV read from the screenshot.
        }
      } else {
        unmatched++;
      }
      if (nav == null || nav <= 0) {
        skipped++;
        continue;
      }
      if (units == null || units <= 0) units = typedAmount! / nav;
      final match = existing
          .where(
            (f) => scheme != null
                ? f.schemeCode == scheme.code
                : f.name.toLowerCase() == d.name.toLowerCase(),
          )
          .firstOrNull;
      final base = FundHolding(
        id: match?.id ?? newWealthId(),
        kind: scheme != null ? 'india_mf' : 'manual',
        schemeCode: scheme?.code,
        name: scheme?.name ?? d.name,
        currency: 'INR',
        units: units,
        avgCostNav: d.avgCostNav ?? match?.avgCostNav,
        nav: nav,
        navDate: navDate,
        navSource: navSource,
        navFetchedAt: fetched,
        sipAmountMinor: d.hasSip && d.sipDay != null
            ? d.sipAmountMinor
            : match?.sipAmountMinor,
        sipDay: d.hasSip && d.sipDay != null ? d.sipDay : match?.sipDay,
        createdAt: match?.createdAt ?? _clock().toUtc(),
      );
      final saved = await wealth.saveFund(base);
      if (match == null) {
        added++;
        existing.add(saved);
      } else {
        updated++;
      }
      if (d.hasSip && d.sipDay != null) {
        final made = await trackFundSip(
          saved,
          amountMinor: d.sipAmountMinor!,
          day: d.sipDay!,
        );
        if (made) sips++;
      }
    }
    return (
      added: added,
      updated: updated,
      skipped: skipped,
      sips: sips,
      unmatched: unmatched,
    );
  }

  /// "SIP 5000 a month into a scheme": finds the fund in the holdings or adds
  /// it with no units yet (the first confirmed instalment buys them), then
  /// tracks the SIP. Returns the holding.
  Future<FundHolding> startFundSip(
    FundScheme scheme, {
    required int amountMinor,
    required int day,
    RuleFrequency frequency = RuleFrequency.monthly,
  }) async {
    final funds = (await wealth.fundViews()).map((v) => v.holding);
    var fund = funds.where((f) => f.schemeCode == scheme.code).firstOrNull;
    if (fund == null) {
      double nav = 0;
      var navDate = today.toIso();
      var source = 'manual';
      DateTime? fetched;
      try {
        final latest = await wealth.fundLookup.latest(scheme.code);
        if (latest != null) {
          nav = latest.nav;
          navDate = latest.navDate;
          source = 'market';
          fetched = _clock().toUtc();
        }
      } on Object {
        // Offline: the NAV fills in on the next refresh.
      }
      fund = await wealth.saveFund(
        FundHolding(
          id: newWealthId(),
          kind: 'india_mf',
          schemeCode: scheme.code,
          name: scheme.name,
          currency: 'INR',
          units: 0,
          nav: nav,
          navDate: navDate,
          navSource: source,
          navFetchedAt: fetched,
          createdAt: _clock().toUtc(),
        ),
      );
    }
    await trackFundSip(fund, amountMinor: amountMinor, day: day, frequency: frequency);
    return fund;
  }

  /// Starts (or updates) the monthly SIP rule for a fund so each due date
  /// asks "did your SIP go through?". Mirrors the amount and day onto the
  /// holding so the Wealth "upcoming" list agrees. Returns true when a new
  /// rule was created.
  Future<bool> trackFundSip(
    FundHolding fund, {
    required int amountMinor,
    required int day,
    String currency = 'INR',
    RuleFrequency frequency = RuleFrequency.monthly,
  }) async {
    final symbol = fundRuleSymbol(fund.id);
    final rules = await store.rules();
    final old = rules.where((r) => r.symbol == symbol).firstOrNull;
    if (frequency == RuleFrequency.monthly) {
      await wealth.saveFund(
        fund.copyWith(sipAmountMinor: amountMinor, sipDay: day),
      );
    }
    if (old != null) {
      await store.saveRule(
        old.copyWith(amountMinor: amountMinor, day: day, frequency: frequency, active: true),
      );
      return false;
    }
    await store.saveRule(
      InvestRule(
        id: newWealthId(),
        symbol: symbol,
        name: fund.name,
        amountMinor: amountMinor,
        currency: currency,
        frequency: frequency,
        day: day,
        startDate: today,
      ),
    );
    return true;
  }

  // ---- rules -----------------------------------------------------------------------

  Future<InvestRule> saveRule(InvestRule r) async {
    final saved = await store.saveRule(r);
    await _mirrorSip(saved, remove: false);
    await rescheduleBuyReminders();
    return saved;
  }

  Future<void> deleteRule(String id) async {
    final old = (await store.rules()).where((r) => r.id == id).firstOrNull;
    await store.deleteRule(id);
    if (old != null) {
      await _mirrorSip(old, remove: true);
      for (final k in const ['ahead', 'day']) {
        await wealth.reminders.cancel(notificationIdFor('buy-$k:$id'));
      }
    }
  }

  /// Phone reminders for the next buy of every active rule: a heads-up the
  /// day before ("coming up") and one on the day asking whether it happened.
  /// Safe to call often; each call replaces the last. A paused or deleted
  /// rule has its reminders cancelled.
  Future<void> rescheduleBuyReminders() async {
    final now = _clock();
    final t = today;
    for (final r in await store.rules()) {
      final ahead = notificationIdFor('buy-ahead:${r.id}');
      final day = notificationIdFor('buy-day:${r.id}');
      await wealth.reminders.cancel(ahead);
      await wealth.reminders.cancel(day);
      final next = nextDue(r, t);
      if (next == null) continue;
      final amount =
          '${r.currency} ${(r.amountMinor / 100).toStringAsFixed(r.amountMinor % 100 == 0 ? 0 : 2)}';
      final what = r.isFund ? 'SIP into ${r.label}' : 'buy of ${r.symbol}';
      final aheadAt = reminderTime(next, 1, now);
      if (aheadAt != null) {
        await wealth.reminders.schedule(
          id: ahead,
          title: 'Coming up tomorrow',
          body: '$amount $what. Pulse will ask you to confirm it.',
          at: aheadAt,
        );
      }
      final dayAt = reminderTime(next, 0, now);
      if (dayAt != null) {
        await wealth.reminders.schedule(
          id: day,
          title: r.isFund ? 'Did your SIP go through?' : 'Time to buy ${r.symbol}',
          body: '$amount $what is due today. Open Pulse to confirm the price.',
          at: dayAt,
        );
      }
    }
  }

  /// A fund SIP rule and the fund's own SIP fields (shown in "upcoming")
  /// say the same thing.
  Future<void> _mirrorSip(InvestRule r, {required bool remove}) async {
    if (!r.isFund) return;
    final fund = (await wealth.fundViews())
        .map((v) => v.holding)
        .where((f) => f.id == r.fundId)
        .firstOrNull;
    if (fund == null) return;
    final on = !remove && r.active && r.frequency == RuleFrequency.monthly;
    await wealth.saveFund(
      on
          ? fund.copyWith(sipAmountMinor: r.amountMinor, sipDay: r.day)
          : fund.copyWith(clearSip: true),
    );
  }

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
    if (rule.isFund) {
      return _confirmFundBuy(occ, rule, price: price, amount: amount);
    }
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

  /// A SIP instalment: units = amount / NAV, added to the fund at a weighted
  /// average cost. NAV is the one typed, else today's from AMFI, else the last
  /// one on the holding.
  Future<bool> _confirmFundBuy(
    RuleOccurrence occ,
    InvestRule rule, {
    double? price,
    double? amount,
  }) async {
    final fund = (await wealth.fundViews())
        .map((v) => v.holding)
        .where((f) => f.id == rule.fundId)
        .firstOrNull;
    if (fund == null) return false;
    var nav = price;
    var navDate = fund.navDate;
    var navSource = fund.navSource;
    DateTime? fetched = fund.navFetchedAt;
    if (nav == null && fund.isIndian && fund.schemeCode != null) {
      try {
        final latest = await wealth.fundLookup.latest(fund.schemeCode!);
        if (latest != null) {
          nav = latest.nav;
          navDate = latest.navDate;
          navSource = 'market';
          fetched = _clock().toUtc();
        }
      } on Object {
        // Offline: fall back to the NAV on the holding.
      }
    }
    nav ??= fund.nav;
    if (nav <= 0) return false;
    var amt = amount ?? occ.amountMinor / 100;
    if (amount == null && rule.currency != fund.currency) {
      final b = await wealth.book();
      final from = b.fx(rule.currency), to = b.fx(fund.currency);
      if (from != null && to != null && to > 0) amt = amt * from / to;
    }
    final res = applyBuy(
      units: fund.units,
      avgCost: fund.avgCostNav,
      amount: amt,
      price: nav,
    );
    await wealth.saveFund(
      fund.copyWith(
        units: res.units,
        avgCostNav: res.avgCost > 0 ? res.avgCost : null,
        nav: nav,
        navDate: price != null ? _clock().toUtc().toIso8601String().substring(0, 10) : navDate,
        navSource: price != null ? 'manual' : navSource,
        navFetchedAt: fetched,
      ),
    );
    await store.saveOccurrence(
      RuleOccurrence(
        id: occ.id,
        ruleId: occ.ruleId,
        due: occ.due,
        amountMinor: occ.amountMinor,
        status: OccurrenceStatus.confirmed,
        price: nav,
        units: res.bought,
        decidedOn: today,
      ),
    );
    return true;
  }

  /// "Not yet, I will do it later": the buy stays waiting for confirmation
  /// and the phone nudges again tomorrow morning.
  Future<void> remindTomorrow(RuleOccurrence occ, InvestRule rule) async {
    final at = reminderTime(today.addDays(1), 0, _clock());
    if (at == null) return;
    await wealth.reminders.schedule(
      id: notificationIdFor('buy-later:${occ.id}'),
      title: rule.isFund
          ? 'Did your SIP go through?'
          : 'Still to buy ${rule.symbol}?',
      body: 'Open Pulse and confirm the price once it is done.',
      at: at,
    );
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
