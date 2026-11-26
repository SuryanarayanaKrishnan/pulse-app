/// Live (end-of-day) quotes kept on the phone: the latest price, the one
/// before it for the day change, and when each was observed. Pure Dart.
///
/// Nothing here guesses: a price that is missing, not positive, older than
/// what is already stored or implausibly far from it is refused, and the UI
/// keeps showing the last good number with its date.
library;

import 'dart:convert';

class LiveQuote {
  const LiveQuote({
    required this.price,
    required this.date,
    this.prevPrice,
    this.prevDate,
    required this.fetchedAt,
    this.source = 'market',
  });

  final double price;

  /// The trading / NAV date of [price], `yyyy-MM-dd`.
  final String date;
  final double? prevPrice;
  final String? prevDate;

  /// When the phone last confirmed this price.
  final DateTime fetchedAt;
  final String source;

  /// Change since the previous close/NAV; null without a genuinely earlier one.
  double? get dayChange {
    final p = prevPrice, pd = prevDate;
    if (p == null || pd == null || pd.compareTo(date) >= 0) return null;
    return price - p;
  }

  double? get dayChangePct {
    final c = dayChange, p = prevPrice;
    return c == null || p == null || p <= 0 ? null : c / p * 100;
  }

  Map<String, Object?> toJson() => {
    'p': price,
    'd': date,
    if (prevPrice != null) 'pp': prevPrice,
    if (prevDate != null) 'pd': prevDate,
    'f': fetchedAt.toUtc().toIso8601String(),
    's': source,
  };

  static LiveQuote? fromJson(Object? j) {
    if (j is! Map) return null;
    final p = j['p'], d = j['d'], f = j['f'];
    if (p is! num || d is! String || f is! String) return null;
    final at = DateTime.tryParse(f);
    if (at == null || p <= 0) return null;
    return LiveQuote(
      price: p.toDouble(),
      date: d,
      prevPrice: (j['pp'] as num?)?.toDouble(),
      prevDate: j['pd'] as String?,
      fetchedAt: at.toUtc(),
      source: j['s'] is String ? j['s'] as String : 'market',
    );
  }
}

String encodeQuotes(Map<String, LiveQuote> m) =>
    jsonEncode({for (final e in m.entries) e.key: e.value.toJson()});

Map<String, LiveQuote> decodeQuotes(String? s) {
  if (s == null || s.isEmpty) return {};
  try {
    final j = jsonDecode(s);
    if (j is! Map) return {};
    final out = <String, LiveQuote>{};
    for (final e in j.entries) {
      final q = LiveQuote.fromJson(e.value);
      if (q != null) out['${e.key}'] = q;
    }
    return out;
  } on FormatException {
    return {};
  }
}

enum MergeResult { updated, unchanged, rejected }

/// One-day moves beyond this are treated as a bad data point, not a price.
const maxPlausibleMove = 0.4;

/// Folds a freshly read price into [current]. Returns the new quote and what
/// happened. [seedPrev] (optional) is the last value the phone already had,
/// used as the previous close when nothing is cached yet.
({LiveQuote? quote, MergeResult result}) mergeQuote(
  LiveQuote? current, {
  required double price,
  required String date,
  required DateTime now,
  String source = 'market',
  double? seedPrev,
  String? seedPrevDate,
}) {
  if (!price.isFinite ||
      price <= 0 ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date)) {
    return (quote: current, result: MergeResult.rejected);
  }
  final base =
      current?.price ??
      (seedPrevDate != null && seedPrevDate.compareTo(date) < 0
          ? seedPrev
          : null);
  if (base != null && (price - base).abs() / base > maxPlausibleMove) {
    return (quote: current, result: MergeResult.rejected);
  }
  if (current == null) {
    final usable =
        seedPrev != null &&
        seedPrev > 0 &&
        seedPrevDate != null &&
        seedPrevDate.compareTo(date) < 0;
    return (
      quote: LiveQuote(
        price: price,
        date: date,
        prevPrice: usable ? seedPrev : null,
        prevDate: usable ? seedPrevDate : null,
        fetchedAt: now.toUtc(),
        source: source,
      ),
      result: MergeResult.updated,
    );
  }
  final cmp = date.compareTo(current.date);
  if (cmp < 0)
    return (
      quote: current,
      result: MergeResult.rejected,
    ); // never go back in time
  if (cmp == 0) {
    return (
      quote: LiveQuote(
        price: price,
        date: date,
        prevPrice: current.prevPrice,
        prevDate: current.prevDate,
        fetchedAt: now.toUtc(),
        source: source,
      ),
      result: price == current.price
          ? MergeResult.unchanged
          : MergeResult.updated,
    );
  }
  return (
    quote: LiveQuote(
      price: price,
      date: date,
      prevPrice: current.price,
      prevDate: current.date,
      fetchedAt: now.toUtc(),
      source: source,
    ),
    result: MergeResult.updated,
  );
}

enum Freshness { fresh, delayed, stale, none }

/// How current [date] is on [today] (both `yyyy-MM-dd`): weekends and a
/// holiday or two are normal, so up to [freshDays] is "fresh".
Freshness freshnessOf(
  String? date,
  DateTime today, {
  int freshDays = 4,
  int staleDays = 10,
}) {
  final d = date == null ? null : DateTime.tryParse(date);
  if (d == null) return Freshness.none;
  final age = DateTime.utc(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime.utc(d.year, d.month, d.day)).inDays;
  if (age <= freshDays) return Freshness.fresh;
  return age <= staleDays ? Freshness.delayed : Freshness.stale;
}

const _mon = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String shortDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  return d == null ? '' : '${d.day} ${_mon[d.month - 1]}';
}

/// "NAV 25 Nov" / "Last close 25 Nov · delayed" / "Stale: last close 3 Nov".
String asOfLabel(String? date, DateTime today, {required bool fund}) {
  if (date == null) return fund ? 'NAV date unknown' : 'No price yet';
  final what = fund ? 'NAV' : 'Last close';
  return switch (freshnessOf(date, today)) {
    Freshness.fresh =>
      fund ? 'NAV ${shortDate(date)}' : '$what ${shortDate(date)} · delayed',
    Freshness.delayed => 'Older $what ${shortDate(date)}',
    Freshness.stale => 'Stale: $what ${shortDate(date)}',
    Freshness.none => '',
  };
}
