import 'package:flutter/foundation.dart' show visibleForTesting;

/// The app's notion of "now" for what the person sees (greeting, month, days
/// left). Always the system clock in production; screenshot tests pin it so a
/// picture does not change with the time of day or the calendar.
class AppClock {
  const AppClock._();

  @visibleForTesting
  static DateTime Function() source = DateTime.now;

  static DateTime now() => source();
}
