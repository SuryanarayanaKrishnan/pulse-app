import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/habit_model.dart';

import 'habit_eval_test.dart' show row;
import 'habit_sim.dart';

void main() {
  test(
    'candidates, several seeds and noisy taps (printed)',
    skip: Platform.environment['HABIT_GRID'] == null
        ? 'set HABIT_GRID=1 to rerun'
        : false,
    () {
      final cands = {
        'A bands[30,100] tw.6 d1.0 at.6 min2': const HabitConfig(
          bandEdgesAed: [30, 100],
          decay: 1.0,
        ),
        'B bands[30,100] tw.6 d.95 at.6 min2': const HabitConfig(
          bandEdgesAed: [30, 100],
          decay: 0.95,
        ),
        'C bands[30,100] tw.6 d.9 at.6 min2': const HabitConfig(
          bandEdgesAed: [30, 100],
          decay: 0.9,
        ),
        'D bands[30,100] tw.6 d.95 at.7 min2': const HabitConfig(
          bandEdgesAed: [30, 100],
          decay: 0.95,
          applyAt: 0.7,
        ),
        'E bands[30,100] tw.6 d.95 at.7 min3': const HabitConfig(
          bandEdgesAed: [30, 100],
          decay: 0.95,
          applyAt: 0.7,
          minVotes: 3,
        ),
        'F bands[25,60,150] tw.6 d.95 at.6 min2': const HabitConfig(
          bandEdgesAed: [25, 60, 150],
          decay: 0.95,
        ),
      };
      for (final tapErr in [0.05, 0.2]) {
        // ignore: avoid_print
        print('--- user tap error ${(tapErr * 100).round()}%');
        for (final e in cands.entries) {
          final rs = [
            for (final s in [1, 2, 3])
              simulate(e.value, users: 40, seed: s, tapError: tapErr),
          ];
          double avg(double Function(SimResult) f) =>
              rs.map(f).reduce((a, b) => a + b) / rs.length;
          // ignore: avoid_print
          print(
            '${e.key.padRight(40)} steady chips ${(avg((r) => r.late.chipRate) * 100).toStringAsFixed(0)}%  silent-wrong ${(avg((r) => r.late.silentWrongRate) * 100).toStringAsFixed(1)}%  accuracy ${(avg((r) => r.late.accuracy) * 100).toStringAsFixed(1)}%  after-change ${(avg((r) => r.changed.accuracy) * 100).toStringAsFixed(1)}%  chips-after-change ${(avg((r) => r.changed.chipRate) * 100).toStringAsFixed(0)}%',
          );
        }
      }
      final r = simulate(const HabitConfig(), users: 40);
      // ignore: avoid_print
      print(
        'no learning: chips 100%, first chip right ${(r.all.baselineTop * 100).toStringAsFixed(0)}% (catalogue default order)',
      );
      // ignore: avoid_print
      print(row('default config', r));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
