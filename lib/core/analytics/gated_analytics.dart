import 'package:flutter/foundation.dart';

import 'analytics.dart';
import 'event_schema.dart';
import 'privacy_controller.dart';

/// The only analytics the rest of the app ever talks to. Wraps the real
/// backend ([_sink]) and lets through only what the person allowed and the
/// schema describes:
///
/// * sharing off (the default): everything is dropped;
/// * an event or property not in [AnalyticsSchema]: dropped;
/// * a value that is not one of the property's allowed values: dropped;
/// * the backend is told only the random anonymous id, never an account id.
class GatedAnalytics implements Analytics {
  GatedAnalytics(this._sink, this._privacy) {
    _privacy.addListener(_onPrivacyChanged);
  }

  final Analytics _sink;
  final PrivacyController _privacy;
  String? _identified;

  @override
  Future<void> init() => _sink.init();

  void _onPrivacyChanged() {
    // Sharing turned off, or the id was replaced: forget the old identity.
    if (_identified != null && _identified != _privacy.installId) {
      _sink.reset();
      _identified = null;
    }
  }

  bool _ready() {
    if (!_privacy.sharing) return false;
    final id = _privacy.installId;
    if (id == null) return false;
    if (_identified != id) {
      _sink.identify(id);
      _identified = id;
    }
    return true;
  }

  @override
  void track(AnalyticsEvent event) {
    final spec = AnalyticsSchema.specFor(event.name);
    if (spec == null) {
      assert(() {
        debugPrint('[analytics] dropped, not in schema: ${event.name}');
        return true;
      }());
      return;
    }
    // Milestones count once whether or not sharing is on.
    if (spec.oncePerInstall && !_privacy.firstTime(spec.name)) return;
    final props = AnalyticsSchema.clean(event.name, event.properties);
    if (props == null || !_ready()) return;
    _sink.track(AnalyticsEvent.unchecked(event.name, props));
  }

  @override
  void screen(String name) {
    if (!AnalyticsSchema.screens.contains(name) || !_ready()) return;
    _sink.screen(name);
  }

  /// Ignored on purpose: account ids never reach analytics.
  @override
  void identify(String userId) {}

  /// Same as "Reset anonymous id".
  @override
  void reset() => _privacy.resetId();
}
