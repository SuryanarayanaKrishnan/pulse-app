import 'dart:async';

import 'package:flutter/foundation.dart';

import '../backup/backup_keystore.dart';
import '../capture/kv_store.dart';
import '../core/analytics/analytics.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_scheduler.dart';
import '../core/sync/sync_transport.dart';

/// What the Sync screen and the Settings row show.
@immutable
class SyncStatus {
  const SyncStatus({
    this.available = false,
    this.enabled = false,
    this.running = false,
    this.lastSuccess,
    this.lastError,
    this.lastSent = 0,
    this.lastReceived = 0,
  });

  /// False when this build cannot sync (demo data, web, not signed in to a
  /// server) or the backup key does not exist yet.
  final bool available;
  final bool enabled;
  final bool running;
  final DateTime? lastSuccess;

  /// A calm sentence; null when the last run was fine.
  final String? lastError;
  final int lastSent;
  final int lastReceived;

  SyncStatus copyWith({
    bool? available,
    bool? enabled,
    bool? running,
    DateTime? lastSuccess,
    Object? lastError = _keep,
    int? lastSent,
    int? lastReceived,
  }) => SyncStatus(
    available: available ?? this.available,
    enabled: enabled ?? this.enabled,
    running: running ?? this.running,
    lastSuccess: lastSuccess ?? this.lastSuccess,
    lastError: identical(lastError, _keep) ? this.lastError : lastError as String?,
    lastSent: lastSent ?? this.lastSent,
    lastReceived: lastReceived ?? this.lastReceived,
  );

  static const _keep = Object();
}

/// Maps any failure to a short analytics reason (no content) and a calm
/// sentence for the user.
({String reason, String message}) classifySyncError(Object e) {
  if (e is SyncException) {
    return switch (e.reason) {
      'signed_out' => (reason: 'signed_out', message: 'Sign in to sync your devices.'),
      'too_new' => (reason: 'too_new', message: 'Another device runs a newer version of Pulse. Update this one to keep syncing.'),
      'integrity' => (reason: 'integrity', message: 'Some synced data could not be verified, so it was not applied.'),
      _ => (reason: 'other', message: "Couldn't sync just now. Your data is safe on this phone."),
    };
  }
  if (e is SyncUnavailable) {
    return (reason: 'signed_out', message: 'Sign in to sync your devices.');
  }
  final t = e.runtimeType.toString();
  if (t.contains('Socket') || t.contains('Timeout') || t.contains('ClientException') || t.contains('Handshake')) {
    return (reason: 'offline', message: "You're offline. Changes sync when you're back.");
  }
  return (reason: 'other', message: "Couldn't sync just now. Your data is safe on this phone.");
}

String _bucket(int n) => n == 0 ? 'none' : (n <= 50 ? 'few' : 'many');

/// Owns the engine, the scheduler and the on/off switch. Sync uses the
/// backup data key (from the keystore), so it can only be on once encrypted
/// backup has been set up or restored on this phone.
class SyncService {
  SyncService({
    required this.kv,
    required this.keys,
    required this.transport,
    required this.engineFor,
    required this.analytics,
    this.scheduler,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _scheduler =
        scheduler ??
        SyncScheduler(run: _run);
  }

  final KvStore kv;
  final BackupKeyStore keys;
  final SyncTransport? transport;

  /// Builds the engine for a data key.
  final SyncEngine Function(List<int> dataKey) engineFor;
  final Analytics analytics;
  final SyncScheduler? scheduler;
  final DateTime Function() _clock;
  late final SyncScheduler _scheduler;

  static const enabledKey = 'sync.enabled';
  static const lastSuccessKey = 'sync.last_success';

  final _controller = StreamController<SyncStatus>.broadcast();
  SyncStatus _status = const SyncStatus();
  SyncEngine? _engine;
  bool _disposed = false;

  SyncStatus get status => _status;
  Stream<SyncStatus> get changes => _controller.stream;

  void _set(SyncStatus s) {
    _status = s;
    if (!_disposed) _controller.add(s);
  }

  Future<void> load() async {
    final enabled = (await kv.read(enabledKey)) == '1';
    final last = DateTime.tryParse(await kv.read(lastSuccessKey) ?? '');
    final hasKey = await keys.load() != null;
    _scheduler.enabled = enabled;
    _set(
      SyncStatus(
        available: transport != null && hasKey,
        enabled: enabled,
        lastSuccess: last,
      ),
    );
  }

  /// Re-checks whether a backup key exists (it is created when backup is
  /// set up or restored).
  Future<void> refreshAvailability() async {
    final hasKey = await keys.load() != null;
    final avail = transport != null && hasKey;
    if (avail != _status.available) _set(_status.copyWith(available: avail));
  }

  Future<void> setEnabled(bool on) async {
    await kv.write(enabledKey, on ? '1' : '0');
    _scheduler.enabled = on;
    _set(_status.copyWith(enabled: on, lastError: null));
    if (on) unawaited(_scheduler.syncNow());
  }

  void onLocalWrite() {
    if (_status.enabled) _scheduler.onLocalWrite();
  }

  void onResumed() {
    if (_status.enabled) _scheduler.onResume();
  }

  /// Settings > "Sync now". Works even when automatic sync is off.
  Future<bool> syncNow() async {
    await refreshAvailability();
    return _scheduler.syncNow();
  }

  Future<bool> _run(String trigger) async {
    final started = _clock();
    if (_status.running) return false;
    analytics.track(AnalyticsEvent.syncStarted(trigger: trigger));
    _set(_status.copyWith(running: true));
    try {
      final key = await keys.load();
      if (key == null || transport == null) {
        throw const SyncException('signed_out', 'no key');
      }
      final engine = _engine ??= engineFor(key);
      final r = await engine.sync();
      final now = _clock();
      unawaited(kv.write(lastSuccessKey, now.toUtc().toIso8601String()));
      _set(
        _status.copyWith(
          running: false,
          lastSuccess: now,
          lastError: null,
          lastSent: r.pushedChanges,
          lastReceived: r.appliedChanges,
        ),
      );
      analytics.track(
        AnalyticsEvent.syncCompleted(
          trigger: trigger,
          changesBucket: _bucket(r.pushedChanges + r.appliedChanges),
          seconds: now.difference(started).inSeconds,
        ),
      );
      return true;
    } catch (e) {
      final c = classifySyncError(e);
      final reason = e is SyncException && e.message == 'no key' ? 'keys_missing' : c.reason;
      _set(
        _status.copyWith(
          running: false,
          lastError: e is SyncException && e.message == 'no key'
              ? 'Turn on encrypted backup first: sync uses the same recovery key.'
              : c.message,
        ),
      );
      analytics.track(AnalyticsEvent.syncFailed(trigger: trigger, reason: reason));
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _scheduler.dispose();
    _controller.close();
  }
}
