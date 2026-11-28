import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/mood.dart';
import 'package:pulse/core/theme/tokens.dart';
import 'package:pulse/data/insights.dart';

SafeToSpend _s(double available, {double promised = 1000}) => SafeToSpend(
  today: available / 10,
  available: available,
  bills: promised,
  cardDues: 0,
  goals: 0,
  daysLeft: 10,
);

void main() {
  test('comfortable cash flow stays on Sage', () {
    expect(nextMood(PulseMood.sage, _s(1000)), PulseMood.sage);
  });

  test('tight cash flow moves to Stone', () {
    expect(nextMood(PulseMood.sage, _s(100)), PulseMood.stone); // 9%
    expect(nextMood(PulseMood.sage, _s(0)), PulseMood.stone);
  });

  test('hysteresis: the band between the lines holds the current mood', () {
    final mid = _s(250); // 20% headroom
    expect(nextMood(PulseMood.sage, mid), PulseMood.sage);
    expect(nextMood(PulseMood.stone, mid), PulseMood.stone);
    expect(nextMood(PulseMood.stone, _s(500)), PulseMood.sage); // 33%
  });

  test('nothing to judge stays on Sage', () {
    expect(headroom(_s(0, promised: 0)), isNull);
    expect(
      nextMood(
        PulseMood.stone,
        const SafeToSpend(
          today: 0,
          available: double.infinity,
          bills: 0,
          cardDues: 0,
          goals: 0,
          daysLeft: 1,
        ),
      ),
      PulseMood.sage,
    );
  });

  test('every palette keeps text and accents readable', () {
    double lum(Color c) => c.computeLuminance();
    double contrast(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
    }

    for (final m in PulseMood.values) {
      for (final dark in [true, false]) {
        final c = PulseColors.of(m, dark: dark);
        expect(contrast(c.textPrimary, c.bg), greaterThan(12));
        expect(contrast(c.textSecondary, c.bg), greaterThan(4.5));
        expect(contrast(c.accent, c.bg), greaterThan(4.5));
        expect(contrast(c.onAccent, c.accent), greaterThan(4.5));
        for (final t in PulseTab.values) {
          expect(contrast(c.tabAccent(t), c.bg), greaterThan(4.5));
        }
      }
    }
  });
}
