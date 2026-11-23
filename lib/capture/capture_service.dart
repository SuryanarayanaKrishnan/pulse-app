import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/analytics/analytics.dart';
import 'capture_config.dart';
import 'capture_platform.dart';
import 'ingest_queue.dart';
import 'kv_store.dart';

/// Orchestrates automatic capture: permission flows, draining the native
/// buffer into the persistent [IngestQueue], one-time SMS backfill and uploads.
class CaptureService {
  CaptureService({
    required this.platform,
    required this.queue,
    required this.kv,
    required this.analytics,
    this.config = const CaptureConfig(),
    this.flushInterval = const Duration(minutes: 10),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CapturePlatform platform;
  final IngestQueue queue;
  final KvStore kv;
  final Analytics analytics;
  final CaptureConfig config;
  final Duration flushInterval;
  final DateTime Function() _clock;

  static const backfillFlagKey = 'capture.sms_backfill_done';

  StreamSubscription<void>? _sub;
  Timer? _timer;
  bool _started = false;
  bool _draining = false;
  bool _drainAgain = false;

  /// Starts listening. Safe to call repeatedly; no-op where capture is
  /// unsupported (iOS, web, tests).
  Future<void> start() async {
    if (_started || !platform.supported) return;
    _started = true;
    try {
      await platform.configure(config);
      _sub = platform.onPending.listen((_) => unawaited(drain()));
      _timer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
      await drain();
      await backfillIfNeeded();
    } catch (e, s) {
      debugPrint('Capture start failed: $e\n$s');
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _sub?.cancel();
    _started = false;
  }

  /// Call when the app returns to the foreground.
  Future<void> onResumed() async {
    if (!_started) return;
    await drain();
  }

  // ---- queue ---------------------------------------------------------------

  /// Moves everything from the native buffer into the persistent queue, then
  /// uploads. Coalesces overlapping calls.
  Future<void> drain() async {
    if (!platform.supported) return;
    if (_draining) {
      _drainAgain = true;
      return;
    }
    _draining = true;
    try {
      do {
        _drainAgain = false;
        final events = await platform.peekPending();
        if (events.isNotEmpty) {
          final now = _clock();
          for (final e in events) {
            await queue.enqueue(e.toPending(now));
          }
          // Only after the items are durably queued.
          await platform.ackPending([for (final e in events) e.id]);
        }
      } while (_drainAgain);
    } catch (e, s) {
      debugPrint('Capture drain failed: $e\n$s');
    } finally {
      _draining = false;
    }
    await flush();
  }

  Future<FlushResult> flush({bool force = false}) async {
    try {
      return await queue.flush(force: force);
    } catch (e) {
      debugPrint('Capture flush failed: $e');
      return FlushResult(remaining: queue.pendingCount.value);
    }
  }

  // ---- permissions -----------------------------------------------------------

  Future<CaptureStatus> status() async {
    if (!platform.supported) return CaptureStatus.unsupported;
    return platform.status();
  }

  /// Asks for RECEIVE_SMS and READ_SMS, reports analytics, and runs the
  /// one-time backfill when reading is allowed.
  Future<CaptureStatus> requestSmsPermissions() async {
    final before = await status();
    final after = await platform.requestSmsPermissions();
    if (!before.smsReceive) _track('sms_receive', after.smsReceive);
    if (!before.smsRead) _track('sms_read', after.smsRead);
    if (after.smsRead) await backfillIfNeeded();
    return after;
  }

  Future<void> openNotificationAccessSettings() =>
      platform.openNotificationAccessSettings();

  Future<void> openAppSettings() => platform.openAppSettings();

  /// Call after the user comes back from the notification-access screen;
  /// records whether they granted it.
  Future<CaptureStatus> onReturnedFromNotificationSettings(
    CaptureStatus before,
  ) async {
    final after = await status();
    if (!before.notificationAccess) {
      _track('notification_access', after.notificationAccess);
    }
    if (after.notificationAccess) unawaited(drain());
    return after;
  }

  void _track(String permission, bool granted) => analytics.track(
    granted
        ? AnalyticsEvent.permissionGranted(permission)
        : AnalyticsEvent.permissionDenied(permission),
  );

  // ---- backfill --------------------------------------------------------------

  /// Reads the last [CaptureConfig.backfillDays] days of bank SMS once.
  /// Returns how many messages were found (0 if skipped).
  Future<int> backfillIfNeeded() async {
    if (!platform.supported) return 0;
    if (await kv.read(backfillFlagKey) != null) return 0;
    final s = await platform.status();
    if (!s.smsRead) return 0;
    final found = await platform.backfillSms(days: config.backfillDays);
    await kv.write(backfillFlagKey, _clock().toUtc().toIso8601String());
    await drain();
    return found;
  }
}
