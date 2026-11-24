import '../../core/analytics/analytics.dart';

/// The four moments of the first-launch tour, in order. [key] is what
/// analytics reports as `step`.
enum TourStep {
  safeToSpend('safe_to_spend'),
  rightCard('right_card'),
  autoCapture('auto_capture'),
  netWorth('net_worth');

  const TourStep(this.key);
  final String key;
}

enum TourStatus { running, skipped, completed }

/// The tour's state machine. Pure Dart, no widgets: the screen drives it and
/// persistence is the caller's job (see `TourProgressController`).
///
/// Analytics: `tour_started` once, `tour_step_viewed` the first time each
/// moment is shown, then exactly one of `tour_skipped` (with the moment it
/// was left on) or `tour_completed`.
class TourFlow {
  TourFlow(this._analytics);
  final Analytics _analytics;

  static const steps = TourStep.values;

  int _index = 0;
  TourStatus _status = TourStatus.running;
  bool _started = false;
  final _viewed = <int>{};

  int get index => _index;
  TourStep get step => steps[_index];
  TourStatus get status => _status;
  bool get isLast => _index == steps.length - 1;
  bool get finished => _status != TourStatus.running;

  /// Call once when the tour appears.
  void start() {
    if (_started) return;
    _started = true;
    _analytics.track(AnalyticsEvent.tourStarted);
    _view();
  }

  void _view() {
    if (_viewed.add(_index)) {
      _analytics.track(AnalyticsEvent.tourStepViewed(step.key));
    }
  }

  /// The user swiped (or the page settled) on moment [i].
  void goTo(int i) {
    if (finished || i < 0 || i >= steps.length || i == _index) return;
    _index = i;
    _view();
  }

  /// Tap anywhere. Moves on, or completes from the last moment. Returns true
  /// if the tour is now finished.
  bool advance() {
    if (finished) return true;
    if (isLast) {
      complete();
      return true;
    }
    goTo(_index + 1);
    return false;
  }

  void skip() {
    if (finished) return;
    _status = TourStatus.skipped;
    _analytics.track(AnalyticsEvent.tourSkipped(step.key));
  }

  void complete() {
    if (finished) return;
    _status = TourStatus.completed;
    _analytics.track(AnalyticsEvent.tourCompleted);
  }
}
