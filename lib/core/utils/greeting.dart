/// A greeting for the time of day. Uses only the clock: no names, no data.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Up late';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  if (h < 22) return 'Good evening';
  return 'Good night';
}
