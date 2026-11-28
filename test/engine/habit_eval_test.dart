import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/habit_model.dart';

import 'habit_sim.dart';

String row(String name, SimResult r) =>
    '${name.padRight(34)} early chips ${(r.early.chipRate * 100).toStringAsFixed(0).padLeft(3)}%'
    '  steady chips ${(r.late.chipRate * 100).toStringAsFixed(0).padLeft(3)}%'
    '  steady silent-wrong ${(r.late.silentWrongRate * 100).toStringAsFixed(1).padLeft(4)}%'
    '  steady accuracy ${(r.late.accuracy * 100).toStringAsFixed(1)}%'
    '  after-change accuracy ${(r.changed.accuracy * 100).toStringAsFixed(1)}%'
    '  top-chip hit ${(r.late.topChip * 100).toStringAsFixed(0)}%';

double cost(SimResult r) =>
    r.all.chipRate * 1.0 + r.all.silentWrongRate * 6 + (1 - r.all.accuracy) * 6;

void main() {
  test(
    'tuning grid (printed)',
    skip: Platform.environment['HABIT_GRID'] == null
        ? 'set HABIT_GRID=1 to rerun the grid'
        : false,
    () {
      final results = <(String, double, SimResult)>[];
      for (final bands in [
        [40.0, 150.0],
        [30.0, 100.0],
        [25.0, 60.0, 150.0],
        [50.0],
      ]) {
        for (final tw in [0.0, 0.6, 1.0]) {
          for (final decay in [1.0, 0.9, 0.85, 0.75]) {
            for (final at in [0.5, 0.6, 0.7, 0.8]) {
              for (final mv in [1.0, 2.0, 3.0]) {
                final cfg = HabitConfig(
                  bandEdgesAed: bands,
                  timeWeight: tw,
                  decay: decay,
                  applyAt: at,
                  minVotes: mv,
                );
                final r = simulate(cfg, users: 25);
                results.add((
                  'bands $bands tw $tw decay $decay at $at min $mv',
                  cost(r),
                  r,
                ));
              }
            }
          }
        }
      }
      results.sort((a, b) => a.$2.compareTo(b.$2));
      // ignore: avoid_print
      print('BEST 8 of ${results.length}');
      for (final r in results.take(8)) {
        // ignore: avoid_print
        print('${r.$2.toStringAsFixed(3)} ${row(r.$1, r.$3)}');
      }
      // ignore: avoid_print
      print('WORST 3');
      for (final r in results.reversed.take(3)) {
        // ignore: avoid_print
        print('${r.$2.toStringAsFixed(3)} ${row(r.$1, r.$3)}');
      }
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
