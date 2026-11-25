import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/analytics/analytics.dart';
import 'redactor.dart';

enum LogKind { route, event, error, trace }

@immutable
class LogEntry {
  const LogEntry(this.time, this.kind, this.text);
  final DateTime time;
  final LogKind kind;

  /// Already redacted.
  final String text;

  String format() {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)} '
        '${kind.name.padRight(5)} $text';
  }
}

/// In-memory ring buffer of non-sensitive app events for bug reports.
///
/// It only ever takes route names, analytics event names and errors, and
/// every string is redacted on the way in, so nothing about money, merchants
/// or people is held. It lives in memory only and is gone when the app closes.
class BugLog {
  BugLog({this.capacity = 200, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static final BugLog instance = BugLog();

  final int capacity;
  final DateTime Function() _now;
  final _entries = <LogEntry>[];

  /// Name of the screen last shown (redacted), for the report header.
  String? currentRoute;

  List<LogEntry> get entries => List.unmodifiable(_entries);

  static const _maxLine = 200;
  static final _eventName = RegExp(r'^[a-z][a-z0-9_]{0,47}$');

  void _add(LogKind kind, String text) {
    var t = Redactor.redact(text.replaceAll('\n', ' '));
    if (t.length > _maxLine) t = '${t.substring(0, _maxLine)}...';
    _entries.add(LogEntry(_now(), kind, t));
    if (_entries.length > capacity) _entries.removeRange(0, _entries.length - capacity);
  }

  void route(String name) {
    final clean = Redactor.redact(name.split('?').first);
    currentRoute = clean;
    _add(LogKind.route, clean);
  }

  /// Analytics event names only. Anything that is not a plain snake_case name
  /// is ignored.
  void event(String name) {
    if (_eventName.hasMatch(name)) _add(LogKind.event, name);
  }

  /// The exception type and a redacted message, then the top stack frames.
  void error(Object error, [StackTrace? stack]) {
    _add(LogKind.error, '${error.runtimeType}: $error');
    if (stack == null) return;
    final frames = stack.toString().split('\n').where((l) => l.trim().isNotEmpty);
    for (final f in frames.take(12)) {
      _add(LogKind.trace, f.trim());
    }
  }

  /// The last [n] formatted lines.
  List<String> lines([int n = 200]) {
    final from = _entries.length > n ? _entries.length - n : 0;
    return [for (final e in _entries.skip(from)) e.format()];
  }

  void clear() {
    _entries.clear();
    currentRoute = null;
  }

  /// Chains onto the global error hooks so unhandled errors reach the log.
  /// Call once from `main`.
  void installErrorHooks() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      error(details.exception, details.stack);
      if (prev != null) prev(details);
    };
    final prevAsync = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (e, s) {
      error(e, s);
      return prevAsync?.call(e, s) ?? false;
    };
  }
}

final bugLogProvider = Provider<BugLog>((ref) => BugLog.instance);

/// Wraps the app's [Analytics] to note event and screen names (never
/// properties) in the [BugLog].
class LoggingAnalytics implements Analytics {
  LoggingAnalytics(this._inner, this._log);
  final Analytics _inner;
  final BugLog _log;

  @override
  Future<void> init() => _inner.init();
  @override
  void track(AnalyticsEvent event) {
    _log.event(event.name);
    _inner.track(event);
  }

  @override
  void screen(String name) {
    _log.route(name);
    _inner.screen(name);
  }

  @override
  void identify(String userId) => _inner.identify(userId);
  @override
  void reset() => _inner.reset();
}
