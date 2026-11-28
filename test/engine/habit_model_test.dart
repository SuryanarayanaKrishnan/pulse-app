import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/habit_model.dart';

import 'habit_sim.dart';

void main() {
  group('safety', () {
    test('nothing is applied from a single tap', () {
      final m = HabitModel()..confirm('careem', 1500, 8, 'transport');
      expect(m.predict('careem', 1500, 8), isNull);
      // ...but the chips already lead with it.
      expect(m.rank('careem', 1500, 8).first.category, 'transport');
    });

    test('one wrong tap cannot flip a settled habit', () {
      final m = HabitModel();
      for (var i = 0; i < 8; i++) {
        m.confirm('careem', 1500, 8, 'transport');
      }
      expect(m.predict('careem', 1500, 8)?.category, 'transport');
      m.confirm('careem', 1500, 8, 'dining'); // a stray tap
      expect(m.predict('careem', 1500, 8)?.category, 'transport');
    });

    test('a changed habit takes over within ten taps, six when fixed', () {
      final m = HabitModel();
      for (var i = 0; i < 8; i++) {
        m.confirm('careem', 1500, 8, 'transport');
      }
      var taps = 0;
      while (m.predict('careem', 1500, 8)?.category != 'dining' && taps < 30) {
        m.confirm('careem', 1500, 8, 'dining');
        taps++;
      }
      expect(taps, lessThanOrEqualTo(10));
      final fixed = HabitModel();
      for (var i = 0; i < 8; i++) {
        fixed.confirm('careem', 1500, 8, 'transport');
      }
      var fixes = 0;
      while (fixed.predict('careem', 1500, 8)?.category != 'dining' &&
          fixes < 30) {
        fixed.confirm('careem', 1500, 8, 'dining', weight: 2);
        fixes++;
      }
      expect(fixes, lessThanOrEqualTo(6));
    });

    test('habits are per size: small rides do not decide big baskets', () {
      final m = HabitModel();
      for (var i = 0; i < 6; i++) {
        m.confirm('careem', 1500, 8, 'transport');
        m.confirm('careem', 9000, 20, 'dining');
      }
      expect(m.predict('careem', 1500, 8)?.category, 'transport');
      expect(m.predict('careem', 9000, 20)?.category, 'dining');
      expect(m.predict('careem', 40000, 14), isNull);
    });

    test('apps do not leak into each other', () {
      final m = HabitModel();
      for (var i = 0; i < 6; i++) {
        m.confirm('careem', 1500, 8, 'transport');
      }
      expect(m.predict('noon', 1500, 8), isNull);
    });

    test('survives save and load, and a damaged file is ignored', () {
      final m = HabitModel();
      for (var i = 0; i < 4; i++) {
        m.confirm('careem', 1500, 8, 'transport');
      }
      final copy = HabitModel()..load(m.encode());
      expect(copy.predict('careem', 1500, 8)?.category, 'transport');
      copy.load('{not json');
      expect(copy.predict('careem', 1500, 8), isNull);
    });
  });

  test('stats count only numbers and survive save and load', () {
    final a = HabitStats()
      ..chipsShown = 3
      ..autoCorrected = 1;
    final b = HabitStats()..load(a.encode());
    expect(b.chipsShown, 3);
    expect(b.autoCorrected, 1);
    expect(a.encode(), isNot(contains('careem')));
    b.load('garbage');
    expect(b.chipsShown, 3);
  });

  group('simulated users (40 people, 240 payments each, bare bank names)', () {
    final r = simulate(const HabitConfig(), users: 40);
    test('learning beats the catalogue default and stays honest', () {
      // Without learning every payment shows chips and the first chip is
      // right about half the time.
      expect(r.all.baselineTop, lessThan(0.65));
      // Once settled, a clear majority is categorised silently...
      expect(r.late.chipRate, lessThan(0.5));
      // ...and rarely wrongly, even with 5% mistaken taps.
      expect(r.late.silentWrongRate, lessThan(0.04));
      expect(r.late.accuracy, greaterThan(0.95));
      // When chips do show, the first one is usually right.
      expect(r.late.topChip, greaterThan(0.7));
    });

    test('a changed habit recovers', () {
      expect(r.changed.accuracy, greaterThan(0.93));
    });

    test('very noisy taps degrade gently', () {
      final noisy = simulate(const HabitConfig(), users: 40, tapError: 0.2);
      expect(noisy.late.silentWrongRate, lessThan(0.05));
      expect(noisy.late.accuracy, greaterThan(0.88));
    });
  });
}
