import 'package:flutter/services.dart';

/// Haptics, tuned in one place and used sparingly:
///  * [tap]: a selection changed (tab, segment, chip).
///  * [light]: a toggle flipped.
///  * [medium]: a deliberate commit (save, create, pay).
///  * [success]: something finished that the user was waiting on.
class Haptics {
  const Haptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void light() => HapticFeedback.lightImpact();
  static void medium() => HapticFeedback.mediumImpact();
  static void success() => HapticFeedback.mediumImpact();
}
