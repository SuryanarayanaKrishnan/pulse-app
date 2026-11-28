import 'coach_copy.dart';
import 'coach_progress.dart';

/// The walkthrough steps for [screen]: the `walkthrough` content pack when it
/// has a usable list for that screen, otherwise the built-in text.
///
/// A step's [CoachStep.id] must name a target that exists on the screen; a
/// pack step with an unknown id is simply skipped by the host, so a pack can
/// reword, reorder or drop steps but never break a screen.
List<CoachStep> coachStepsFor(CoachScreen screen, Map<String, Object?>? pack) {
  final builtIn = coachSteps[screen] ?? const <CoachStep>[];
  final screens = pack?['screens'];
  if (screens is! Map) return builtIn;
  final raw = screens[screen.key];
  if (raw is! List) return builtIn;
  final out = <CoachStep>[];
  for (final r in raw) {
    if (r is! Map) continue;
    final id = r['id'], title = r['title'], body = r['body'];
    if (id is String && title is String && body is String && title.isNotEmpty && body.isNotEmpty) {
      out.add(CoachStep(id, title, body));
    }
  }
  return out.isEmpty ? builtIn : out;
}
