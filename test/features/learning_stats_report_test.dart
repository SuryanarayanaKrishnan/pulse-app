import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/habit_model.dart';
import 'package:pulse/features/settings/learning_stats_row.dart';

void main() {
  test('the report has counts and rates, and no merchant or amount text', () {
    final s = HabitStats()
      ..chipsShown = 10
      ..chipTaps = 8
      ..topChipTaps = 6
      ..autoApplied = 20
      ..autoCorrected = 1;
    final r = learningStatsReport(s);
    expect(r, contains('"chipsShown": 10'));
    expect(r, contains('"chipTapRatePct": 80.0'));
    expect(r, contains('"firstChipRightPct": 75.0'));
    expect(r, contains('"silentCorrectedPct": 5.0'));
    expect(r.toLowerCase(), isNot(contains('careem')));
  });

  test('an empty report does not divide by zero', () {
    expect(
      learningStatsReport(HabitStats()),
      contains('"chipTapRatePct": 0.0'),
    );
  });
}
