import 'dart:async';

/// Decides when to run a sync. Pure timing logic: [run] does the work and
/// reports whether it succeeded.
///
/// * local writes: wait for [debounce] of quiet (bursts become one sync);
/// * app resume: run soon, unless one finished within [resumeCooldown];
/// * manual: run now, bypassing debounce and backoff;
/// * failures: back off [retryBase] x 2^(n-1), capped at [retryMax]; only
///   automatic triggers are delayed, a manual run always goes;
/// * one run at a time; a trigger that arrives meanwhile schedules one more.
class SyncScheduler {
  SyncScheduler({
    required this.run,
    this.debounce = const Duration(seconds: 20),
    this.resumeDelay = const Duration(seconds: 2),
    this.resumeCooldown = const Duration(minutes: 1),
    this.retryBase = const Duration(minutes: 1),
    this.retryMax = const Duration(minutes: 30),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Runs one sync for [trigger] (`manual` | `auto` | `resume`).
  final Future<bool> Function(String trigger) run;
  final Duration debounce;
  final Duration resumeDelay;
  final Duration resumeCooldown;
  final Duration retryBase;
  final Duration retryMax;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _running = false;
  bool _again = false;
  bool _disposed = false;
  bool enabled = true;
  int failures = 0;
  DateTime? _lastFinished;
  DateTime? _blockedUntil;

  bool get running => _running;

  Duration get _backoff {
    if (failures == 0) return Duration.zero;
    final f = (failures - 1).clamp(0, 10);
    final d = retryBase * (1 << f);
    return d > retryMax ? retryMax : d;
  }

  void onLocalWrite() => _arm(debounce, 'auto');

  void onResume() {
    final last = _lastFinished;
    if (failures == 0 && last != null && _clock().difference(last) < resumeCooldown) {
      return;
    }
    _arm(resumeDelay, 'resume');
  }

  void _arm(Duration d, String trigger) {
    if (_disposed || !enabled) return;
    final blocked = _blockedUntil;
    if (blocked != null) {
      final wait = blocked.difference(_clock());
      if (wait > d) d = wait;
    }
    _timer?.cancel();
    _timer = Timer(d, () => unawaited(_go(trigger)));
  }

  /// "Sync now". Returns false when it failed or was skipped.
  Future<bool> syncNow() => _go('manual');

  Future<bool> _go(String trigger) async {
    if (_disposed) return false;
    if (_running) {
      _again = true;
      return false;
    }
    if (trigger != 'manual' && !enabled) return false;
    _timer?.cancel();
    _running = true;
    var ok = false;
    try {
      ok = await run(trigger);
    } catch (_) {
      ok = false;
    }
    _running = false;
    _lastFinished = _clock();
    if (ok) {
      failures = 0;
      _blockedUntil = null;
    } else {
      failures++;
      _blockedUntil = _clock().add(_backoff);
    }
    if (_again && !_disposed) {
      _again = false;
      _arm(ok ? debounce : _backoff, 'auto');
    } else if (!ok && trigger != 'manual') {
      _arm(_backoff, 'auto');
    }
    return ok;
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
