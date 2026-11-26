import 'capture_service.dart';

/// The four iPhone capture paths. All four are part of setup: none is optional.
enum CaptureSource {
  /// Wallet automation running "Record Payment" on every tap-to-pay.
  wallet,

  /// Message automation running "Record Bank SMS" on every bank text.
  bankSms,

  /// Screenshot (Back Tap, Action Button, share sheet) read with "Capture to
  /// Pulse".
  screenshot,

  /// "App is closed" automation on a shopping app that asks, then captures the
  /// latest screenshot.
  nudge;

  /// Storage key of the first arrival. The wallet key is the pre-existing one
  /// so earlier installs keep their "it works" state.
  String get firstSeenKey => this == wallet
      ? CaptureService.shortcutSeenKey
      : 'capture.first_seen.$name';

  /// How long "Test it" waits before showing the failure hint. A text arrives
  /// within seconds, so it gets the shortest wait.
  Duration get testTimeout => this == bankSms
      ? const Duration(seconds: 30)
      : const Duration(seconds: 90);

  String get lastSeenKey => 'capture.last_seen.$name';
}

/// Outcome of a "Test it" run for one path.
enum TestState { idle, waiting, passed, failed }

/// Pure decision for the "Test it" panel so it can be unit tested.
///
/// A test passes only when an event of that source arrived after [startedAt]
/// (an older event proves nothing about the shortcut working right now). It
/// fails when [timeout] passes without one.
TestState evaluateTest({
  required DateTime? startedAt,
  required DateTime? lastSeen,
  required DateTime now,
  Duration timeout = const Duration(seconds: 90),
}) {
  if (startedAt == null) return TestState.idle;
  if (lastSeen != null && !lastSeen.isBefore(startedAt)) {
    return TestState.passed;
  }
  return now.difference(startedAt) >= timeout
      ? TestState.failed
      : TestState.waiting;
}
