import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../data/api/dto.dart';
import '../data/api/ingest_api.dart';
import 'ingest_queue.dart';
import 'kv_store.dart';

/// A transaction handed over by the iOS Shortcuts "Transaction" automation via
/// `pulse://ingest?amount=..&merchant=..&card=..[&currency=..&ts=..&direction=..]`.
@immutable
class ShortcutTransaction {
  const ShortcutTransaction({
    required this.amountMinor,
    required this.merchant,
    required this.currency,
    required this.timestamp,
    this.card,
    this.last4,
    this.direction = 'debit',
    this.viaScreenshot = false,
  });

  final int amountMinor;
  final String merchant;
  final String currency;
  final DateTime timestamp;
  final String? card;
  final String? last4;
  final String direction;

  /// Read from a screenshot: the app shows a light Undo/Edit confirmation.
  final bool viaScreenshot;

  ShortcutTransaction asScreenshot() => ShortcutTransaction(
    amountMinor: amountMinor,
    merchant: merchant,
    currency: currency,
    timestamp: timestamp,
    card: card,
    last4: last4,
    direction: direction,
    viaScreenshot: true,
  );

  /// Parses a deep link. Returns null when it is not an ingest link or has no
  /// usable positive amount.
  static ShortcutTransaction? tryParse(Uri uri, {DateTime? now}) {
    final isIngest =
        uri.host == 'ingest' || (uri.host.isEmpty && uri.path == '/ingest');
    if (!isIngest) return null;
    final q = uri.queryParameters;
    final parsed = parseAmount(q['amount'] ?? '');
    if (parsed == null) return null;
    final card = q['card']?.trim();
    final merchant = q['merchant']?.trim();
    final dir = (q['direction'] ?? '').toLowerCase();
    return ShortcutTransaction(
      amountMinor: toMinor(parsed.$1),
      merchant: (merchant == null || merchant.isEmpty) ? 'Apple Pay' : merchant,
      currency: (q['currency']?.toUpperCase() ?? parsed.$2 ?? 'AED'),
      timestamp: _parseTs(q['ts']) ?? now ?? DateTime.now(),
      card: (card == null || card.isEmpty) ? null : card,
      last4: card == null ? null : last4Of(card),
      direction: dir == 'credit' ? 'credit' : 'debit',
    );
  }

  /// Parses Shortcuts amount text such as `45.50`, `AED 1,234.50`, `45,50`.
  /// Returns (value, currency?) or null if no positive number is found.
  static (double, String?)? parseAmount(String raw) {
    final currency = RegExp(r'[A-Za-z]{3}').firstMatch(raw)?.group(0);
    var n = raw.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (n.isEmpty) return null;
    if (n.contains(',') && n.contains('.')) {
      // Whichever separator comes last is the decimal point.
      n = n.lastIndexOf(',') > n.lastIndexOf('.')
          ? n.replaceAll('.', '').replaceAll(',', '.')
          : n.replaceAll(',', '');
    } else if (n.contains(',')) {
      n = RegExp(r',\d{1,2}$').hasMatch(n)
          ? n.replaceAll(',', '.')
          : n.replaceAll(',', '');
    }
    final v = double.tryParse(n);
    if (v == null || v <= 0) return null;
    return (v, currency?.toUpperCase());
  }

  /// Trailing four digits of a card label like `Emirates NBD •••• 4821`.
  static String? last4Of(String card) =>
      RegExp(r'(\d{4})\D*$').firstMatch(card)?.group(1);

  static DateTime? _parseTs(String? ts) {
    if (ts == null || ts.isEmpty) return null;
    final secs = int.tryParse(ts);
    if (secs != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        secs > 100000000000 ? secs : secs * 1000,
      );
    }
    return DateTime.tryParse(ts);
  }

  /// Stable per-transaction id so a re-opened link does not double-count.
  String get externalId {
    final minute = timestamp.toUtc().millisecondsSinceEpoch ~/ 60000;
    final basis =
        '$merchant|$amountMinor|$currency|${last4 ?? card ?? ''}|$minute';
    return 'shortcut:${sha1.convert(utf8.encode(basis)).toString().substring(0, 24)}';
  }

  PendingIngest toPending(DateTime now) {
    final amount = (amountMinor / 100).toStringAsFixed(2);
    final dto = IngestRequestDto(
      rawText:
          '${viaScreenshot ? 'Screenshot' : 'Apple Pay'} $merchant $currency $amount${card == null ? '' : ' $card'}',
      institution: null,
      receivedAt: timestamp,
      externalId: externalId,
      fields: IngestFieldsDto(
        amountMinor: amountMinor,
        currency: currency,
        direction: direction,
        merchant: merchant,
        last4: last4,
        postedAt: timestamp,
      ),
    );
    return PendingIngest(
      id: externalId,
      channel: IngestChannel.appleShortcut,
      payload: dto.toJson(),
      createdAt: now,
    );
  }
}

/// Per-install ingest token shown in the guided setup screen.
///
/// NOTE: the backend currently authenticates ingest with the user's Supabase
/// JWT only and has no ingest-token endpoint, so this token is generated and
/// stored locally and is not yet accepted server-side. The `pulse://` Open-URL
/// flow (which posts through the signed-in app) does not need it.
class IngestTokenStore {
  IngestTokenStore(this._kv, {Random? random})
    : _random = random ?? Random.secure();
  final KvStore _kv;
  final Random _random;
  static const _key = 'ingest_token';

  Future<String> token() async {
    final existing = await _kv.read(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final t = 'pls_${base64Url.encode(bytes).replaceAll('=', '')}';
    await _kv.write(_key, t);
    return t;
  }

  Future<String> rotate() async {
    await _kv.remove(_key);
    return token();
  }
}
