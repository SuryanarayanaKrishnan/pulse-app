import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/coach/coach.dart';
import 'package:pulse/features/coach/coach_pack.dart';

void main() {
  test('no pack uses the built-in steps', () {
    expect(coachStepsFor(CoachScreen.home, null), coachSteps[CoachScreen.home]);
  });

  test('a pack rewords steps for its screen only', () {
    final pack = {
      'screens': {
        'home': [
          {'id': 'safe', 'title': 'New title', 'body': 'New body'},
        ],
      },
    };
    final steps = coachStepsFor(CoachScreen.home, pack);
    expect(steps.single.title, 'New title');
    expect(coachStepsFor(CoachScreen.budget, pack), coachSteps[CoachScreen.budget]);
  });

  test('malformed pack steps fall back to built-in', () {
    final pack = {
      'screens': {
        'home': [
          {'id': 'safe', 'title': '', 'body': 'x'},
          'junk',
        ],
      },
    };
    expect(coachStepsFor(CoachScreen.home, pack), coachSteps[CoachScreen.home]);
  });

}
