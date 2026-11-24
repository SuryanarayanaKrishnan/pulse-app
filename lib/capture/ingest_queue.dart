import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/engine/types.dart';
import '../data/api/api_exception.dart';
import '../data/api/ingest_api.dart';
import '../data/local/ingest_pipeline.dart';
import 'kv_store.dart';

/// One captured item waiting to be uploaded.
@immutable
class PendingIngest {
  const PendingIngest({
    required this.id,
    required this.channel,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.nextAttemptAt,
    this.lastError,
  });

  /// Stable client id (also sent as `external_id`, so server dedupe makes
  /// re-delivery safe).
  final String id;
  final IngestChannel channel;
  final Map<String, Object?> payload;
  final DateTime createdAt;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;

  PendingIngest failed(DateTime now, String error, Duration backoff) =>
      PendingIngest(
        id: id,
        channel: channel,
        payload: payload,
        createdAt: createdAt,
        attempts: attempts + 1,
        nextAttemptAt: now.add(backoff),
        lastError: error,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'channel': channel.wire,
    'payload': payload,
    'created_at': createdAt.toUtc().toIso8601String(),
    'attempts': attempts,
    if (nextAttemptAt != null)
      'next_attempt_at': nextAttemptAt!.toUtc().toIso8601String(),
    if (lastError != null) 'last_error': lastError,
  };

  factory PendingIngest.fromJson(Map<String, Object?> j) => PendingIngest(
    id: j['id']! as String,
    channel: IngestChannel.fromWire(j['channel']! as String),
    payload: Map<String, Object?>.from(j['payload']! as Map),
    createdAt: DateTime.parse(j['created_at']! as String),
    attempts: (j['attempts'] as num?)?.toInt() ?? 0,
    nextAttemptAt: j['next_attempt_at'] == null
        ? null
        : DateTime.parse(j['next_attempt_at']! as String),
    lastError: j['last_error'] as String?,
  );
}

/// Result of one upload attempt.
enum SendOutcome {
  /// Accepted (including server-side duplicates).
  sent,

  /// Transient failure (offline, timeout, 5xx, 429). Keep and back off.
  retry,

  /// Will never succeed (4xx validation). Drop.
  permanent,

  /// 401. Keep everything and wait for a fresh session.
  unauthorized,
}

typedef IngestSender = Future<SendOutcome> Function(PendingIngest item);

/// Builds an [IngestSender] over the real API.
IngestSender apiIngestSender(IngestApi api) => (item) async {
  try {
    await api.send(item.channel, item.payload);
    return SendOutcome.sent;
  } on ApiException catch (e) {
    if (e.isUnauthorized) return SendOutcome.unauthorized;
    return e.isRetryable ? SendOutcome.retry : SendOutcome.permanent;
  }
};

/// Builds an [IngestSender] over the on-device pipeline. A message that is
/// not a transaction, a duplicate or waiting for an account all count as
/// handled; only an unexpected failure is retried.
IngestSender localIngestSender(IngestPipeline pipeline) => (item) async {
  try {
    await pipeline.ingest(
      IngestInput.fromPayload(switch (item.channel) {
        IngestChannel.sms => TxnSource.sms,
        IngestChannel.notification => TxnSource.notification,
        IngestChannel.appleShortcut => TxnSource.appleShortcut,
      }, item.payload),
    );
    return SendOutcome.sent;
  } on Object catch (e) {
    debugPrint('Local ingest failed for ${item.id}: $e');
    return SendOutcome.retry;
  }
};

class FlushResult {
  const FlushResult({
    this.sent = 0,
    this.dropped = 0,
    this.remaining = 0,
    this.unauthorized = false,
  });
  final int sent;
  final int dropped;
  final int remaining;
  final bool unauthorized;
  @override
  String toString() =>
      'FlushResult(sent: $sent, dropped: $dropped, remaining: $remaining, unauthorized: $unauthorized)';
}

/// Persistent FIFO of captured transactions with retry and backoff.
///
/// * Survives restarts ([KvStore] persists every mutation).
/// * Deduplicates by [PendingIngest.id].
/// * [flush] stops at the first transient failure (probably offline) and
///   skips items still backing off.
/// * Items are dropped after [maxAttempts] failures, [maxAge], or when the
///   queue exceeds [maxItems] (oldest first).
class IngestQueue {
  IngestQueue({
    required this._store,
    required this._sender,
    DateTime Function()? clock,
    this.maxItems = 500,
    this.maxAttempts = 10,
    this.maxAge = const Duration(days: 14),
    this.storageKey = 'ingest_queue.v1',
  }) : _clock = clock ?? DateTime.now;

  final KvStore _store;
  final IngestSender _sender;
  final DateTime Function() _clock;
  final int maxItems;
  final int maxAttempts;
  final Duration maxAge;
  final String storageKey;

  final _pending = ValueNotifier<int>(0);

  /// Number of items waiting (for UI badges).
  ValueListenable<int> get pendingCount => _pending;

  List<PendingIngest>? _items;
  Future<void> _writes = Future.value();
  Future<FlushResult>? _flushing;

  Future<List<PendingIngest>> _load() async {
    final cached = _items;
    if (cached != null) return cached;
    final raw = await _store.read(storageKey);
    var list = <PendingIngest>[];
    if (raw != null) {
      try {
        list = [
          for (final e in jsonDecode(raw) as List)
            PendingIngest.fromJson(Map<String, Object?>.from(e as Map)),
        ];
      } catch (_) {
        list = []; // Corrupt store: start clean rather than crash the app.
      }
    }
    // Another caller may have loaded while we awaited.
    _items ??= list;
    _pending.value = _items!.length;
    return _items!;
  }

  Future<void> _persist() {
    final items = _items!;
    _pending.value = items.length;
    final json = jsonEncode([for (final i in items) i.toJson()]);
    return _writes = _writes.then((_) => _store.write(storageKey, json));
  }

  Future<List<PendingIngest>> items() async => List.of(await _load());

  /// Adds [item]. Returns false if an item with the same id is already queued.
  Future<bool> enqueue(PendingIngest item) async {
    final items = await _load();
    if (items.any((i) => i.id == item.id)) return false;
    items.add(item);
    while (items.length > maxItems) {
      items.removeAt(0);
    }
    await _persist();
    return true;
  }

  /// Attempts to upload everything that is due. Concurrent calls share one run.
  Future<FlushResult> flush({bool force = false}) =>
      _flushing ??= _flush(force).whenComplete(() => _flushing = null);

  Future<FlushResult> _flush(bool force) async {
    final items = await _load();
    var sent = 0;
    var dropped = 0;
    var unauthorized = false;
    final now = _clock();

    for (final item in List.of(items)) {
      if (now.difference(item.createdAt) > maxAge) {
        items.removeWhere((i) => i.id == item.id);
        dropped++;
        continue;
      }
      final due = item.nextAttemptAt;
      if (!force && due != null && due.isAfter(now)) continue;

      final outcome = await _sender(item);
      switch (outcome) {
        case SendOutcome.sent:
          items.removeWhere((i) => i.id == item.id);
          sent++;
        case SendOutcome.permanent:
          items.removeWhere((i) => i.id == item.id);
          dropped++;
        case SendOutcome.unauthorized:
          unauthorized = true;
        case SendOutcome.retry:
          final next = item.failed(
            _clock(),
            'retry',
            backoffFor(item.attempts + 1),
          );
          final idx = items.indexWhere((i) => i.id == item.id);
          if (next.attempts >= maxAttempts) {
            if (idx >= 0) items.removeAt(idx);
            dropped++;
          } else if (idx >= 0) {
            items[idx] = next;
          }
      }
      await _persist();
      if (unauthorized || outcome == SendOutcome.retry) break;
    }
    await _persist();
    return FlushResult(
      sent: sent,
      dropped: dropped,
      remaining: items.length,
      unauthorized: unauthorized,
    );
  }

  /// 30s, 1m, 2m, 4m ... capped at one hour.
  static Duration backoffFor(int attempts) {
    final seconds = 30 * (1 << (attempts - 1).clamp(0, 12));
    return Duration(seconds: seconds.clamp(30, 3600));
  }
}
