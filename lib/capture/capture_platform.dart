import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'capture_config.dart';
import 'apple_shortcut.dart';
import 'captured_event.dart';
import 'screenshot_text.dart';

/// Runtime state of the Android capture permissions.
@immutable
class CaptureStatus {
  const CaptureStatus({
    this.supported = false,
    this.smsReceive = false,
    this.smsRead = false,
    this.notificationAccess = false,
    this.smsPermanentlyDenied = false,
  });

  /// False on iOS, web and desktop.
  final bool supported;

  /// RECEIVE_SMS: live capture of new bank SMS.
  final bool smsReceive;

  /// READ_SMS: one-time inbox backfill.
  final bool smsRead;

  /// Notification-listener access (granted in system settings).
  final bool notificationAccess;

  /// Denied with "don't ask again": only system settings can fix it.
  final bool smsPermanentlyDenied;

  bool get smsGranted => smsReceive && smsRead;
  bool get anyCapture => smsReceive || notificationAccess;

  static const unsupported = CaptureStatus();

  factory CaptureStatus.fromMap(Map<Object?, Object?> m) => CaptureStatus(
    supported: true,
    smsReceive: (m['smsReceive'] as bool?) ?? false,
    smsRead: (m['smsRead'] as bool?) ?? false,
    notificationAccess: (m['notificationAccess'] as bool?) ?? false,
    smsPermanentlyDenied: (m['smsPermanentlyDenied'] as bool?) ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is CaptureStatus &&
      other.supported == supported &&
      other.smsReceive == smsReceive &&
      other.smsRead == smsRead &&
      other.notificationAccess == notificationAccess &&
      other.smsPermanentlyDenied == smsPermanentlyDenied;

  @override
  int get hashCode => Object.hash(
    supported,
    smsReceive,
    smsRead,
    notificationAccess,
    smsPermanentlyDenied,
  );
}

/// Bridge to the Android capture layer (Kotlin).
///
/// Native code stores every matching SMS/notification in a durable native
/// buffer first; Dart pulls with [peekPending] and confirms with [ackPending]
/// once the item is in the Dart-side queue. That makes delivery at-least-once
/// even when the app process was dead when the message arrived.
abstract class CapturePlatform {
  bool get supported;

  /// Fires whenever new items are in the native buffer.
  Stream<void> get onPending;

  Future<CaptureStatus> status();

  /// Shows the system dialog for RECEIVE_SMS + READ_SMS.
  Future<CaptureStatus> requestSmsPermissions();

  /// Opens the system "Notification access" screen.
  Future<void> openNotificationAccessSettings();

  /// Opens this app's system settings page.
  Future<void> openAppSettings();

  Future<void> configure(CaptureConfig config);

  /// Reads the SMS inbox for the last [days] days into the native buffer.
  /// Returns the number of matching messages found.
  Future<int> backfillSms({required int days});

  Future<List<CapturedEvent>> peekPending();
  Future<void> ackPending(List<String> ids);
}

class UnsupportedCapturePlatform implements CapturePlatform {
  const UnsupportedCapturePlatform();
  @override
  bool get supported => false;
  @override
  Stream<void> get onPending => const Stream.empty();
  @override
  Future<CaptureStatus> status() async => CaptureStatus.unsupported;
  @override
  Future<CaptureStatus> requestSmsPermissions() async =>
      CaptureStatus.unsupported;
  @override
  Future<void> openNotificationAccessSettings() async {}
  @override
  Future<void> openAppSettings() async {}
  @override
  Future<void> configure(CaptureConfig config) async {}
  @override
  Future<int> backfillSms({required int days}) async => 0;
  @override
  Future<List<CapturedEvent>> peekPending() async => const [];
  @override
  Future<void> ackPending(List<String> ids) async {}
}

/// Talks to `CapturePlugin.kt` over `MethodChannel('pulse/ingest')` and
/// `EventChannel('pulse/ingest/events')`.
class MethodChannelCapturePlatform implements CapturePlatform {
  MethodChannelCapturePlatform({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('pulse/ingest'),
      _events = events ?? const EventChannel('pulse/ingest/events');

  final MethodChannel _methods;
  final EventChannel _events;

  static bool get isAvailable => !kIsWeb && Platform.isAndroid;

  @override
  bool get supported => true;

  @override
  Stream<void> get onPending =>
      _events.receiveBroadcastStream().map((_) {}).handleError((Object _) {});

  Future<CaptureStatus> _status(String method, [Object? args]) async {
    final m = await _methods.invokeMapMethod<Object?, Object?>(method, args);
    return CaptureStatus.fromMap(m ?? const {});
  }

  @override
  Future<CaptureStatus> status() => _status('getStatus');

  @override
  Future<CaptureStatus> requestSmsPermissions() =>
      _status('requestSmsPermissions');

  @override
  Future<void> openNotificationAccessSettings() =>
      _methods.invokeMethod<void>('openNotificationAccessSettings');

  @override
  Future<void> openAppSettings() =>
      _methods.invokeMethod<void>('openAppSettings');

  @override
  Future<void> configure(CaptureConfig config) =>
      _methods.invokeMethod<void>('configure', config.toMap());

  @override
  Future<int> backfillSms({required int days}) async =>
      (await _methods.invokeMethod<int>('backfillSms', {'days': days})) ?? 0;

  @override
  Future<List<CapturedEvent>> peekPending() async {
    final raw = await _methods.invokeListMethod<Object?>('peekPending');
    return [
      for (final e in raw ?? const <Object?>[])
        CapturedEvent.fromMap(e! as Map<Object?, Object?>),
    ];
  }

  @override
  Future<void> ackPending(List<String> ids) =>
      _methods.invokeMethod<void>('ackPending', {'ids': ids});
}

/// iOS: reads what the "Record Payment" App Intent (a Shortcuts Wallet
/// automation) left in the app's native inbox, see `ios/Runner/ShortcutCapture.swift`.
///
/// iOS cannot read SMS or notifications, so there are no permissions to ask
/// for: [status] reports "unsupported" and the inbox is drained on launch and
/// whenever the app returns to the foreground.
class AppleInboxCapturePlatform extends UnsupportedCapturePlatform {
  AppleInboxCapturePlatform({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel('pulse/shortcut_inbox');

  final MethodChannel _methods;

  static bool get isAvailable => !kIsWeb && Platform.isIOS;

  @override
  bool get supported => true;

  @override
  Future<List<CapturedEvent>> peekPending() async {
    final raw = await _methods.invokeListMethod<Object?>('peekPending');
    final out = <CapturedEvent>[];
    final garbage = <String>[];
    for (final e in raw ?? const <Object?>[]) {
      final m = Map<Object?, Object?>.from(e! as Map);
      final id = '${m['id']}';
      if (m['kind'] == 'ocr') {
        // Text read from a screenshot on this phone. Unparseable text is dropped.
        final tx = parseScreenshotText(
          '${m['body'] ?? ''}',
          now: DateTime.fromMillisecondsSinceEpoch(
            ((m['ts'] as num?) ?? 0).toInt() * 1000,
          ),
          nudge: m['src'] == 'nudge',
        );
        if (tx == null) {
          garbage.add(id);
        } else {
          out.add(CapturedEvent.fromShortcut(id, tx));
        }
        continue;
      }
      if (m['kind'] == 'sms') {
        final body = '${m['body'] ?? ''}'.trim();
        if (body.isEmpty) {
          garbage.add(id);
        } else {
          out.add(
            CapturedEvent(
              id: id,
              kind: 'sms',
              body: body,
              sender: m['sender'] as String?,
              timestamp: DateTime.fromMillisecondsSinceEpoch(
                ((m['ts'] as num?) ?? 0).toInt() * 1000,
              ),
            ),
          );
        }
        continue;
      }
      final tx = ShortcutTransaction.tryParse(
        Uri(
          scheme: 'pulse',
          host: 'ingest',
          queryParameters: {
            for (final k in const [
              'amount',
              'merchant',
              'card',
              'currency',
              'ts',
              'direction',
            ])
              if (m[k] != null) k: '${m[k]}',
          },
        ),
      );
      if (tx == null) {
        garbage.add(id);
      } else {
        out.add(CapturedEvent.fromShortcut(id, tx));
      }
    }
    // An item without a usable amount can never succeed: drop it now.
    if (garbage.isNotEmpty) await ackPending(garbage);
    return out;
  }

  @override
  Future<void> ackPending(List<String> ids) =>
      _methods.invokeMethod<void>('ackPending', {'ids': ids});
}
