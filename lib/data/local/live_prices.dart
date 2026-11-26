import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../capture/kv_store.dart';
import '../../core/engine/amfi.dart';
import '../../core/engine/live_quote.dart';
import '../../core/engine/markets.dart';
import '../investing_service.dart';
import 'investing_store.dart';
import 'wealth_store.dart';

/// Where AMFI publishes the day's NAVs for every scheme: a public text file.
const amfiNavAllUrl = 'https://portal.amfiindia.com/spages/NAVAll.txt';

/// Small text blob cache (the AMFI file, about 2 MB).
abstract class TextCache {
  Future<String?> read(String name);
  Future<void> write(String name, String text);
}

class MemoryTextCache implements TextCache {
  final data = <String, String>{};
  @override
  Future<String?> read(String name) async => data[name];
  @override
  Future<void> write(String name, String text) async => data[name] = text;
}

/// In the OS cache directory (which the system may clear). It only saves a
/// download; nothing the user entered is kept there.
class FileTextCache implements TextCache {
  Future<File> _file(String name) async =>
      File(p.join((await getApplicationCacheDirectory()).path, name));

  @override
  Future<String?> read(String name) async {
    try {
      final f = await _file(name);
      return f.existsSync() ? await f.readAsString() : null;
    } on Object {
      return null;
    }
  }

  @override
  Future<void> write(String name, String text) async {
    try {
      await (await _file(name)).writeAsString(text, flush: true);
    } on Object {
      // A cache that cannot be written is only a missed optimisation.
    }
  }
}

/// What [AmfiService.book] knows: the parsed file and how fresh it is.
class AmfiResult {
  const AmfiResult(this.book, {this.fromCache = false, this.error});
  final AmfiBook? book;
  final bool fromCache;
  final Object? error;
}

/// AMFI's daily NAV file, fetched straight from AMFI by the phone (no
/// account, no key, no data about the user sent: a plain GET). Cached on disk
/// and re-downloaded at most every [ttl]; when AMFI is unreachable the last
/// copy is used, marked as cached.
class AmfiService {
  AmfiService({
    required this.dio,
    required this.cache,
    required this.kv,
    DateTime Function()? clock,
    this.ttl = const Duration(hours: 6),
    this.url = amfiNavAllUrl,
    this.minSchemes = 100,
  }) : _clock = clock ?? DateTime.now;

  final Dio? dio;
  final TextCache cache;
  final KvStore kv;
  final Duration ttl;
  final String url;
  final int minSchemes;
  final DateTime Function() _clock;

  static const _file = 'amfi_navall.txt';
  static const _stamp = 'amfi.fetchedAt';

  Future<AmfiResult> book({bool force = false}) async {
    final stamp = DateTime.tryParse(await kv.read(_stamp) ?? '');
    final cached = await cache.read(_file);
    final due =
        force ||
        cached == null ||
        stamp == null ||
        _clock().difference(stamp) >= ttl;
    if (!due)
      return AmfiResult(
        parseAmfiNavAll(cached, fetchedAt: stamp),
        fromCache: true,
      );
    Object? err;
    final client = dio;
    if (client != null) {
      try {
        final res = await client.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 60),
          ),
        );
        final now = _clock().toUtc();
        final fresh = parseAmfiNavAll(res.data ?? '', fetchedAt: now);
        // A block page or truncated body must never replace a good file.
        if (fresh.schemes.length < minSchemes) {
          throw const FormatException('AMFI file looked incomplete');
        }
        await cache.write(_file, res.data!);
        await kv.write(_stamp, now.toIso8601String());
        return AmfiResult(fresh);
      } on Object catch (e) {
        err = e;
      }
    }
    if (cached != null) {
      final b = parseAmfiNavAll(cached, fetchedAt: stamp);
      if (!b.isEmpty) return AmfiResult(b, fromCache: true, error: err);
    }
    return AmfiResult(null, error: err);
  }
}

/// Last close for US tickers from Stooq's free daily CSV, read on the phone.
/// Only the ticker leaves the device. Data is end-of-day (delayed), which the
/// UI says. NSE/BSE/DFM/ADX have no free on-device source here.
class StooqService {
  StooqService(this.dio, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final Dio? dio;
  final DateTime Function() _clock;

  bool get available => dio != null;

  /// `{symbol: (date, close, previousClose?)}` for the symbols that answered.
  Future<
    Map<
      String,
      ({String date, double close, double? prevClose, String? prevDate})
    >
  >
  lastCloses(Iterable<String> symbols) async {
    final client = dio;
    final out =
        <
          String,
          ({String date, double close, double? prevClose, String? prevDate})
        >{};
    if (client == null) return out;
    final now = _clock().toUtc();
    String ymd(DateTime d) =>
        '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
    for (final s in symbols) {
      final l = listingOf(s);
      if (l.exchange != Exchange.us) continue;
      try {
        final res = await client.get<String>(
          'https://stooq.com/q/d/l/',
          queryParameters: {
            's': '${l.base.toLowerCase()}.us',
            'i': 'd',
            'd1': ymd(now.subtract(const Duration(days: 14))),
            'd2': ymd(now),
          },
          options: Options(
            responseType: ResponseType.plain,
            receiveTimeout: const Duration(seconds: 20),
          ),
        );
        final rows = parseStooqCsv(res.data ?? '');
        if (rows.isEmpty) continue;
        final prev = rows.length > 1 ? rows[rows.length - 2] : null;
        out[l.symbol] = (
          date: rows.last.date,
          close: rows.last.close,
          prevClose: prev?.close,
          prevDate: prev?.date,
        );
      } on Object {
        // One ticker failing must not stop the rest.
      }
    }
    return out;
  }
}

/// `Date,Open,High,Low,Close,Volume` rows, oldest first; junk is skipped.
List<({String date, double close})> parseStooqCsv(String csv) {
  final out = <({String date, double close})>[];
  for (final line in csv.split('\n')) {
    final f = line.trim().split(',');
    if (f.length < 5 || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(f[0]))
      continue;
    final c = double.tryParse(f[4]);
    if (c == null || c <= 0) continue;
    out.add((date: f[0], close: c));
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

class LiveRefreshReport {
  const LiveRefreshReport({
    this.fundsUpdated = 0,
    this.stocksUpdated = 0,
    this.rejected = 0,
    this.skipped = false,
    this.errors = const [],
  });
  final int fundsUpdated, stocksUpdated, rejected;

  /// Throttled: nothing was fetched.
  final bool skipped;
  final List<String> errors;
  bool get anyUpdated => fundsUpdated + stocksUpdated > 0;
}

/// Keeps the Wealth numbers current: AMFI NAVs for Indian funds, end-of-day
/// closes for stocks, each stored with its own date and the previous one (for
/// the day change). Refreshes are throttled so opening the app repeatedly
/// costs no battery or data. Failures keep the last good value.
class LivePriceService {
  LivePriceService({
    required this.wealth,
    required this.investing,
    required this.amfi,
    required this.stooq,
    required this.kv,
    this.backendStocks,
    DateTime Function()? clock,
    this.minInterval = const Duration(hours: 3),
  }) : _clock = clock ?? DateTime.now;

  final WealthStore wealth;
  final InvestingStore investing;
  final AmfiService amfi;
  final StooqService stooq;
  final KvStore kv;

  /// The app's backend price endpoint, tried first for stocks when set.
  final StockQuoteService? backendStocks;
  final Duration minInterval;
  final DateTime Function() _clock;

  static const _quotesKey = 'live.quotes';
  static const _ranKey = 'live.lastRun';

  Future<Map<String, LiveQuote>> quotes() async =>
      decodeQuotes(await kv.read(_quotesKey));

  static String fundKey(String code) => 'fund:$code';
  static String stockKey(String symbol) => 'stock:${listingOf(symbol).symbol}';

  /// Never throws: a failure is reported and the stored values stay.
  Future<LiveRefreshReport> refresh({bool force = false}) async {
    try {
      return await _refresh(force: force);
    } on Object catch (e) {
      return LiveRefreshReport(errors: ['Refresh failed: ${e.runtimeType}']);
    }
  }

  Future<LiveRefreshReport> _refresh({required bool force}) async {
    final now = _clock();
    if (!force) {
      final last = DateTime.tryParse(await kv.read(_ranKey) ?? '');
      if (last != null && now.difference(last) < minInterval)
        return const LiveRefreshReport(skipped: true);
    }
    await kv.write(_ranKey, now.toUtc().toIso8601String());
    final book = await quotes();
    var rejected = 0, funds = 0, stocks = 0;
    final errors = <String>[];

    // ---- funds: AMFI ----
    final held = [
      for (final f in await wealth.funds())
        if (f.isIndian && f.schemeCode != null) f,
    ];
    if (held.isNotEmpty) {
      final r = await amfi.book(force: force);
      final ab = r.book;
      if (ab == null) {
        errors.add('AMFI NAVs unavailable');
      } else {
        for (final f in held) {
          final s = ab.byCode(f.schemeCode!);
          if (s == null) continue;
          final key = fundKey(s.code);
          final seed = f.navDate != null && f.nav > 0 ? f.nav : null;
          final m = mergeQuote(
            book[key],
            price: s.nav,
            date: s.date,
            now: now,
            source: 'AMFI',
            seedPrev: seed,
            seedPrevDate: f.navDate,
          );
          if (m.result == MergeResult.rejected) {
            if (book[key] == null || s.date.compareTo(book[key]!.date) >= 0)
              rejected++;
            continue;
          }
          book[key] = m.quote!;
          // The holding keeps the newest NAV so every screen and net worth agree.
          if ((f.navDate ?? '').compareTo(s.date) <= 0 &&
              (f.nav != s.nav || f.navDate != s.date)) {
            await wealth.saveFund(
              f.copyWith(
                nav: s.nav,
                navDate: s.date,
                navSource: 'market',
                navFetchedAt: now.toUtc(),
              ),
            );
            funds++;
          }
        }
      }
    }

    // ---- stocks ----
    final all = await investing.holdings();
    final live = [
      for (final h in all)
        if (listingOf(h.symbol).exchange.livePrice) h,
    ];
    if (live.isNotEmpty) {
      final found =
          <
            String,
            ({double price, String date, double? prev, String? prevDate})
          >{};
      final backend = backendStocks;
      if (backend != null && backend.available) {
        try {
          final got = await backend.fetch(live.map((h) => h.symbol));
          for (final e in got.entries) {
            final at = e.value.updatedAt ?? now;
            found[e.key] = (
              price: e.value.price,
              date: _ymd(at.toUtc()),
              prev: null,
              prevDate: null,
            );
          }
        } on Object catch (e) {
          errors.add('Price service: ${e.runtimeType}');
        }
      }
      final missing = [
        for (final h in live)
          if (!found.containsKey(listingOf(h.symbol).symbol)) h.symbol,
      ];
      if (missing.isNotEmpty && stooq.available) {
        final got = await stooq.lastCloses(missing);
        for (final e in got.entries) {
          found[e.key] = (
            price: e.value.close,
            date: e.value.date,
            prev: e.value.prevClose,
            prevDate: e.value.prevDate,
          );
        }
      }
      for (final h in live) {
        final sym = listingOf(h.symbol).symbol;
        final f = found[sym];
        if (f == null) continue;
        final key = stockKey(sym);
        final cur = listingOf(h.symbol).currency;
        if (cur != h.currency) continue; // never mix currencies
        final m = mergeQuote(
          book[key],
          price: f.price,
          date: f.date,
          now: now,
          source: 'last close',
          seedPrev: f.prev,
          seedPrevDate: f.prevDate,
        );
        if (m.result == MergeResult.rejected) {
          rejected++;
          continue;
        }
        book[key] = m.quote!;
        if (h.lastPrice != f.price) {
          await investing.saveHolding(
            h.copyWith(
              lastPrice: f.price,
              priceAt: now.toUtc(),
              priceSource: 'last close ${f.date}',
            ),
          );
          stocks++;
        }
      }
    }
    await kv.write(_quotesKey, encodeQuotes(book));
    return LiveRefreshReport(
      fundsUpdated: funds,
      stocksUpdated: stocks,
      rejected: rejected,
      errors: errors,
    );
  }

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
