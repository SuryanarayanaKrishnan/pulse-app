import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/local/database.dart';
import 'backup_controller.dart';

/// Tables whose changes are not worth a backup on their own: caches and
/// snapshots the app regenerates by itself.
const quietTables = {
  'price_cache',
  'valuation_snapshots',
  'app_settings',
  'net_worth_snapshots',
};

/// True on Wi-Fi or ethernet: the free approximation of "not metered" that
/// connectivity_plus offers.
Future<bool> onUnmeteredNetwork() async {
  try {
    final r = await Connectivity().checkConnectivity();
    return r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  } catch (_) {
    return false;
  }
}

/// Backs up shortly after meaningful changes: waits for [debounce] of quiet,
/// respects "Wi-Fi only", and spaces out retries after failures so a bad
/// connection never turns into a loop.
class BackupScheduler {
  BackupScheduler({
    required this.service,
    required this.db,
    this.debounce = const Duration(minutes: 2),
    this.retryBase = const Duration(minutes: 30),
    this.staleAfter = const Duration(hours: 24),
    Future<bool> Function()? isUnmetered,
    Stream<dynamic>? networkChanges,
    DateTime Function()? clock,
  }) : _unmetered = isUnmetered ?? onUnmeteredNetwork,
       // ignore: prefer_initializing_formals
       _networkChanges = networkChanges,
       _clock = clock ?? DateTime.now;

  final BackupController service;
  final PulseDatabase db;
  final Duration debounce;
  final Duration retryBase;
  final Duration staleAfter;
  final Future<bool> Function() _unmetered;
  final Stream<dynamic>? _networkChanges;
  final DateTime Function() _clock;

  StreamSubscription<Set<dynamic>>? _updates;
  StreamSubscription<dynamic>? _net;
  Timer? _timer;
  bool _disposed = false;

  void start() {
    _updates = db.tableUpdates().listen((u) {
      final meaningful = u.any((t) => !quietTables.contains(t.table));
      if (!meaningful) return;
      final svc = service;
      if (svc is BackupService) svc.markDirty();
      _arm(debounce);
    });
    try {
      _net = (_networkChanges ?? Connectivity().onConnectivityChanged).listen((
        _,
      ) {
        if (service.state.dirty) _arm(const Duration(seconds: 20));
      });
    } catch (_) {
      // No connectivity plugin (tests): changes and resume still trigger.
    }
  }

  /// Call when the app returns to the foreground.
  void onResumed() {
    final s = service.state;
    if (!s.cloud || !s.auto) return;
    final stale =
        s.lastSuccess == null ||
        _clock().difference(s.lastSuccess!) > staleAfter;
    if (s.dirty || stale) _arm(const Duration(seconds: 10));
  }

  void _arm(Duration d) {
    if (_disposed) return;
    final s = service.state;
    if (!s.cloud || !s.auto) return;
    _timer?.cancel();
    _timer = Timer(d, fire);
  }

  /// Runs a backup now if the rules allow it. Returns whether one ran.
  Future<bool> fire() async {
    if (_disposed) return false;
    final s = service.state;
    if (!s.cloud || !s.auto || s.running) return false;
    if (s.wifiOnly && !await _unmetered())
      return false; // retried when the network changes
    final stats = await service.backupNow(trigger: 'auto');
    if (stats == null && service.state.lastError != null) {
      final factor = service.state.failures.clamp(1, 12);
      _arm(retryBase * factor);
    }
    return stats != null;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _updates?.cancel();
    _net?.cancel();
  }
}
