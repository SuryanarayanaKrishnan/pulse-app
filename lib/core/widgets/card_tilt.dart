import 'dart:async';
import 'dart:io' show Platform;

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Device tilt for the card specular highlight: a smoothed (x, y) in -1..1.
///
/// One shared accelerometer subscription, started when the first card face
/// listens and cancelled when the last one leaves. It does nothing under
/// tests (`FLUTTER_TEST`), on the web, or when the sensor is missing, and then
/// the value stays at its resting pose.
class CardTilt {
  CardTilt._();
  static final CardTilt instance = CardTilt._();

  /// Resting pose: light from the top left, as a card lying on a desk.
  static const rest = Offset(-0.35, -0.25);

  final ValueNotifier<Offset> value = ValueNotifier(rest);
  StreamSubscription<AccelerometerEvent>? _sub;
  int _users = 0;
  double _x = 0, _y = 0;

  static bool get _supported {
    if (kIsWeb) return false;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return false;
      return Platform.isAndroid || Platform.isIOS;
    } on Object {
      return false;
    }
  }

  void attach() {
    if (++_users != 1 || !_supported) return;
    try {
      _sub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
          .listen(_onEvent, onError: (Object _) {}, cancelOnError: false);
    } on Object {
      _sub = null;
    }
  }

  void detach() {
    if (_users > 0 && --_users == 0) {
      unawaited(_sub?.cancel());
      _sub = null;
    }
  }

  void _onEvent(AccelerometerEvent e) {
    // x: roll left/right; y: pitch, relative to a phone held about 35 degrees.
    final tx = (-e.x / 6).clamp(-1.0, 1.0);
    final ty = ((e.y - 6) / 6).clamp(-1.0, 1.0);
    _x += (tx - _x) * 0.14;
    _y += (ty - _y) * 0.14;
    final next = Offset(_x, _y);
    if ((next - value.value).distance > 0.006) value.value = next;
  }
}
