import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/local/database.dart';

/// What a screenshot capture just logged.
@immutable
class CaptureNotice {
  const CaptureNotice({
    required this.txId,
    required this.amountMinor,
    required this.currency,
    required this.merchant,
    this.last4,
  });
  final String txId;
  final int amountMinor;
  final String currency;
  final String merchant;
  final String? last4;

  String get title =>
      'Logged $currency ${(amountMinor / 100).toStringAsFixed(2)}';
  String get body => last4 == null ? merchant : '$merchant · card $last4';
}

enum CaptureAction { undo, edit }

class CaptureReply {
  const CaptureReply(this.action, this.txId);
  final CaptureAction action;
  final String txId;
}

/// Light confirmation after a screenshot capture. The transaction is already
/// saved, so ignoring the banner accepts it; Undo and Edit are optional.
abstract class CaptureConfirmer {
  Future<void> show(CaptureNotice notice);
  Stream<CaptureReply> get replies;
}

class NoopCaptureConfirmer implements CaptureConfirmer {
  const NoopCaptureConfirmer();
  @override
  Future<void> show(CaptureNotice notice) async {}
  @override
  Stream<CaptureReply> get replies => const Stream.empty();
}

class RecordingCaptureConfirmer implements CaptureConfirmer {
  final shown = <CaptureNotice>[];
  @override
  Future<void> show(CaptureNotice notice) async => shown.add(notice);
  @override
  Stream<CaptureReply> get replies => const Stream.empty();
}

/// Soft-deletes a transaction that a capture created. Only capture-created
/// rows can be undone this way.
Future<bool> undoCapturedTransaction(PulseDatabase db, String txId) async {
  final n =
      await (db.update(db.transactions)..where(
            (t) =>
                t.id.equals(txId) &
                t.deletedAt.isNull() &
                t.source.equals('apple_shortcut'),
          ))
          .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));
  return n > 0;
}

const _undoId = 'pulse_capture_undo';
const _editId = 'pulse_capture_edit';

class LocalNotificationCaptureConfirmer implements CaptureConfirmer {
  LocalNotificationCaptureConfirmer([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  final _replies = StreamController<CaptureReply>.broadcast();
  bool _ready = false;

  @override
  Stream<CaptureReply> get replies => _replies.stream;

  Future<void> _init() async {
    if (_ready || kIsWeb) return;
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'pulse_capture',
              actions: [
                DarwinNotificationAction.plain(
                  _undoId,
                  'Undo',
                  options: {DarwinNotificationActionOption.foreground},
                ),
                DarwinNotificationAction.plain(
                  _editId,
                  'Edit',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final id = r.payload;
        if (id == null) return;
        _replies.add(
          CaptureReply(
            r.actionId == _undoId ? CaptureAction.undo : CaptureAction.edit,
            id,
          ),
        );
      },
    );
    _ready = true;
  }

  @override
  Future<void> show(CaptureNotice n) async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.show(
        id: n.txId.hashCode & 0x7fffffff,
        title: n.title,
        body: n.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'pulse_capture',
            'Captured payments',
            channelDescription: 'Confirms a payment Pulse just logged',
            importance: Importance.low,
            timeoutAfter: 15000,
            actions: const [
              AndroidNotificationAction(
                _undoId,
                'Undo',
                showsUserInterface: true,
              ),
              AndroidNotificationAction(
                _editId,
                'Edit',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: 'pulse_capture',
            interruptionLevel: InterruptionLevel.passive,
          ),
        ),
        payload: n.txId,
      );
    } on Object catch (e) {
      debugPrint('Capture confirmation failed: $e');
    }
  }
}
