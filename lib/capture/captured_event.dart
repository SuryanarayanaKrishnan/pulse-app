import 'package:flutter/foundation.dart';

import '../data/api/dto.dart';
import '../data/api/ingest_api.dart';
import 'apple_shortcut.dart';
import 'ingest_queue.dart';

/// A raw SMS or notification handed over by the Android layer.
@immutable
class CapturedEvent {
  const CapturedEvent({
    required this.id,
    required this.kind,
    required this.body,
    required this.timestamp,
    this.sender,
    this.title,
    this.app,
    this.shortcut,
  });

  /// An item the iOS App Intent left in the native inbox: its fields are
  /// already structured, so no parsing is needed.
  factory CapturedEvent.fromShortcut(String id, ShortcutTransaction tx) =>
      CapturedEvent(
        id: id,
        kind: 'apple_shortcut',
        body: '',
        timestamp: tx.timestamp,
        shortcut: tx,
      );

  /// Set for [kind] `apple_shortcut`.
  final ShortcutTransaction? shortcut;

  /// Stable id computed natively (hash of sender/app + text + day) so the live
  /// receiver and the inbox backfill produce the same id for the same message.
  final String id;

  /// `sms` or `notification`.
  final String kind;
  final String body;
  final DateTime timestamp;
  final String? sender;
  final String? title;

  /// Android package name for notifications.
  final String? app;

  factory CapturedEvent.fromMap(Map<Object?, Object?> m) => CapturedEvent(
    id: m['id']! as String,
    kind: m['kind']! as String,
    body: (m['body'] as String?) ?? '',
    sender: m['sender'] as String?,
    title: m['title'] as String?,
    app: m['app'] as String?,
    timestamp: DateTime.fromMillisecondsSinceEpoch((m['ts'] as num).toInt()),
  );

  PendingIngest toPending(DateTime now) {
    final tx = shortcut;
    if (tx != null) return tx.toPending(now);
    final isSms = kind == 'sms';
    final dto = IngestRequestDto(
      rawText: body,
      sender: isSms ? sender : null,
      title: isSms ? null : title,
      appName: isSms ? null : app,
      receivedAt: timestamp,
      externalId: id,
    );
    return PendingIngest(
      id: id,
      channel: isSms ? IngestChannel.sms : IngestChannel.notification,
      payload: dto.toJson(),
      createdAt: now,
    );
  }
}
