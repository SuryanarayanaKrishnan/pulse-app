import 'package:flutter/services.dart';

/// Thin wrapper so haptics can be tuned in one place.
class Haptics {
  const Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.heavyImpact();
}
