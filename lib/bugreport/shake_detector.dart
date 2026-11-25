import 'dart:async';
import 'dart:math' as math;

typedef Accel = ({double x, double y, double z});

/// Pure shake logic: feed it samples, it says when a shake happened.
///
/// A shake is [spikes] jolts above [thresholdG] (gravity included, so a phone
/// at rest reads about 1 g) inside [window]. After one, nothing fires again
/// for [cooldown]. Jolts closer than [minGap] count as one.
class ShakeDetector {
  ShakeDetector({
    this.thresholdG = 2.6,
    this.spikes = 3,
    this.window = const Duration(milliseconds: 900),
    this.minGap = const Duration(milliseconds: 90),
    this.cooldown = const Duration(seconds: 3),
  });

  final double thresholdG;
  final int spikes;
  final Duration window;
  final Duration minGap;
  final Duration cooldown;

  static const _g = 9.80665;
  final _hits = <DateTime>[];
  DateTime? _lastFired;

  /// Force of [a] in g (m/s squared divided by 9.80665).
  static double force(Accel a) =>
      math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) / _g;

  /// Returns true when this sample completes a shake.
  bool add(Accel a, DateTime at) {
    if (_lastFired != null && at.difference(_lastFired!) < cooldown) return false;
    if (force(a) < thresholdG) return false;
    if (_hits.isNotEmpty && at.difference(_hits.last) < minGap) return false;
    _hits.add(at);
    _hits.removeWhere((t) => at.difference(t) > window);
    if (_hits.length < spikes) return false;
    _hits.clear();
    _lastFired = at;
    return true;
  }

  void reset() {
    _hits.clear();
    _lastFired = null;
  }
}

/// Listens to a sensor stream and calls [onShake]. Start it only while the
/// app is in the foreground; [stop] releases the sensor.
class ShakeListener {
  ShakeListener({
    required this.source,
    required this.onShake,
    ShakeDetector? detector,
    DateTime Function()? now,
  }) : detector = detector ?? ShakeDetector(),
       _now = now ?? DateTime.now;

  final Stream<Accel> Function() source;
  final void Function() onShake;
  final ShakeDetector detector;
  final DateTime Function() _now;
  StreamSubscription<Accel>? _sub;

  bool get running => _sub != null;

  void start() {
    if (_sub != null) return;
    detector.reset();
    // A phone or test without the sensor plugin reports the failure from
    // inside the plugin, asynchronously. Shake-to-report is a convenience
    // (Settings has a button too), so that must never become an app error.
    runZonedGuarded(() {
      _sub = source().listen((a) {
        if (detector.add(a, _now())) onShake();
      }, onError: (Object _) {}, cancelOnError: false);
    }, (Object _, StackTrace _) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
