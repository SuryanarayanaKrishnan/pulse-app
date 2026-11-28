import 'package:dio/dio.dart';

import '../../core/engine/prices.dart';
import '../wealth_models.dart';
import 'wealth_store.dart';

/// Gold and FX prices for local revaluation.
///
/// * With a backend (`API_BASE_URL`) it fetches the shared snapshot
///   (`GET /v1/prices/snapshot`) and caches every quote in the local database
///   with its fetch time. The request carries no personal data.
/// * Without one, or offline, it serves the cache; with no cache either, the
///   bundled last-known demo values, which the UI labels as such.
class PriceService {
  PriceService({
    required this.store,
    this.dio,
    DateTime Function()? clock,
    this.ttl = const Duration(minutes: 15),
  }) : _clock = clock ?? DateTime.now;

  final WealthStore store;
  final Dio? dio;
  final Duration ttl;
  final DateTime Function() _clock;

  /// Set when the last [refresh] failed, for a quiet "showing saved prices".
  Object? lastError;

  bool get canFetch => dio != null;

  /// The best book available right now, never null and never throwing:
  /// cached quotes over the bundled fallback.
  Future<PriceBook> current() async {
    final cached = PriceBook(
      await store.priceQuotes(),
      origin: PriceOrigin.cached,
    );
    return mergeBooks(cached, bundledPriceBook());
  }

  /// Fetches a fresh snapshot when one is due (or [force]), stores it and
  /// returns the resulting book. Network and parse failures keep the cache.
  Future<PriceBook> refresh({bool force = false}) async {
    final client = dio;
    if (client == null) return current();
    if (!force) {
      final book = PriceBook(await store.priceQuotes());
      final at = book.quote('XAU_AED_G_24K')?.fetchedAt;
      if (at != null && _clock().difference(at) < ttl) return current();
    }
    try {
      final res = await client.get<Object?>('/v1/prices/snapshot');
      final quotes = parseSnapshot(res.data, fetchedAt: _clock().toUtc());
      if (quotes.isEmpty) throw const FormatException('empty price snapshot');
      await store.savePriceQuotes(quotes);
      lastError = null;
      final merged = mergeBooks(
        PriceBook(await store.priceQuotes(), origin: PriceOrigin.fetched),
        bundledPriceBook(),
      );
      return merged;
    } on Object catch (e) {
      lastError = e;
      return current();
    }
  }
}

/// Mutual fund lookups through the backend: scheme search and latest NAV
/// (mfapi.in, free, no key). Only the search text or scheme code is sent.
class FundLookup {
  FundLookup(this.dio);
  final Dio? dio;

  bool get available => dio != null;

  Future<List<FundScheme>> search(String query) async {
    final client = dio;
    if (client == null) return const [];
    final res = await client.get<Object?>(
      '/v1/funds/search',
      queryParameters: {'q': query.trim()},
    );
    final data = res.data;
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map && e['scheme_code'] != null && e['name'] is String)
          FundScheme('${e['scheme_code']}', e['name'] as String),
    ];
  }

  Future<FundNav?> latest(String schemeCode) async {
    final client = dio;
    if (client == null) return null;
    final res = await client.get<Object?>(
      '/v1/funds/schemes/${Uri.encodeComponent(schemeCode)}/latest',
    );
    final d = res.data;
    if (d is! Map) return null;
    final nav = switch (d['nav']) {
      num n => n.toDouble(),
      String s => double.tryParse(s),
      _ => null,
    };
    if (nav == null || nav <= 0) return null;
    return FundNav(
      code: schemeCode,
      name: d['name'] as String?,
      navDate: '${d['nav_date'] ?? ''}',
      nav: nav,
    );
  }
}
