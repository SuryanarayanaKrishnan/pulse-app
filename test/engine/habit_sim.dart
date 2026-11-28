import 'dart:math';

import 'package:pulse/core/engine/habit_model.dart';

/// One kind of purchase inside a super-app.
class Service {
  const Service(this.cat, this.minAed, this.maxAed, this.hours);
  final String cat;
  final double minAed, maxAed;

  /// Hour windows (start, endExclusive) it happens in.
  final List<(int, int)> hours;
}

const _meals = [(12, 15), (19, 24)];
const _day = [(9, 24)];
const _commute = [(7, 10), (17, 24)];

const services = <String, List<Service>>{
  'noon': [
    Service('shopping', 50, 1500, _day),
    Service('groceries', 25, 180, _day),
    Service('dining', 25, 110, _meals),
  ],
  'careem': [
    Service('transport', 12, 60, _commute),
    Service('dining', 30, 120, _meals),
    Service('groceries', 30, 200, _day),
  ],
  'amazon': [
    Service('shopping', 30, 900, _day),
    Service('groceries', 60, 300, _day),
  ],
  'smiles': [
    Service('dining', 10, 80, _meals),
    Service('shopping', 30, 300, _day),
  ],
  'talabat': [
    Service('dining', 30, 130, _meals),
    Service('groceries', 40, 250, _day),
  ],
};

/// Mix of services per person, as weights in service order.
const personas = <String, List<List<double>>>{
  'noon': [
    [.7, .2, .1],
    [.2, .7, .1],
    [.4, .35, .25],
  ],
  'careem': [
    [.8, .15, .05],
    [.2, .7, .1],
    [.45, .4, .15],
  ],
  'amazon': [
    [.85, .15],
    [.5, .5],
  ],
  'smiles': [
    [.8, .2],
    [.4, .6],
  ],
  'talabat': [
    [.85, .15],
    [.5, .5],
  ],
};

class Metrics {
  int n = 0,
      chips = 0,
      auto = 0,
      autoRight = 0,
      silentWrong = 0,
      finalRight = 0;
  int topChipHit = 0, baselineTopHit = 0;
  double get chipRate => n == 0 ? 0 : chips / n;
  double get silentWrongRate => n == 0 ? 0 : silentWrong / n;
  double get accuracy => n == 0 ? 0 : finalRight / n;
  double get topChip => chips == 0 ? 0 : topChipHit / chips;
  double get baselineTop => n == 0 ? 0 : baselineTopHit / n;
}

class SimResult {
  final all = Metrics(),
      early = Metrics(),
      late = Metrics(),
      changed = Metrics();
}

int _pick(Random r, List<double> w) {
  var x = r.nextDouble() * w.fold(0.0, (a, b) => a + b);
  for (var i = 0; i < w.length; i++) {
    x -= w[i];
    if (x <= 0) return i;
  }
  return w.length - 1;
}

/// Runs [users] simulated people for [txns] payments each. At payment
/// [changeAt] each person's mix flips to a different persona (a new habit).
SimResult simulate(
  HabitConfig cfg, {
  int users = 40,
  int txns = 240,
  int changeAt = 160,
  double tapError = 0.05,
  double noticeRate = 0.5,
  int seed = 7,
}) {
  final res = SimResult();
  final rnd = Random(seed);
  final apps = services.keys.toList();
  for (var u = 0; u < users; u++) {
    final model = HabitModel(config: cfg);
    final mine = (List.of(apps)..shuffle(rnd)).take(3).toList();
    final mixes = {
      for (final a in mine)
        a: [
          personas[a]![rnd.nextInt(personas[a]!.length)],
          personas[a]![rnd.nextInt(personas[a]!.length)],
        ],
    };
    for (var t = 0; t < txns; t++) {
      final app = mine[rnd.nextInt(mine.length)];
      final mix = mixes[app]![t >= changeAt ? 1 : 0];
      final svc = services[app]![_pick(rnd, mix)];
      final aed =
          svc.minAed *
          pow(svc.maxAed / svc.minAed, rnd.nextDouble() * rnd.nextDouble());
      final win = svc.hours[rnd.nextInt(svc.hours.length)];
      final hour = win.$1 + rnd.nextInt(win.$2 - win.$1);
      final minor = (aed * 100).round();
      final cands = services[app]!.map((s) => s.cat).toSet().toList();
      final truth = svc.cat;

      final pred = model.predict(app, minor, hour);
      var finalCat = truth;
      String? tapped;
      if (pred != null) {
        if (pred.category == truth) {
          model.confirm(app, minor, hour, truth, weight: 0.3);
        } else if (rnd.nextDouble() < noticeRate) {
          model.confirm(app, minor, hour, truth, weight: 2);
        } else {
          model.confirm(app, minor, hour, pred.category, weight: 0.3);
          finalCat = pred.category;
        }
      } else {
        tapped = rnd.nextDouble() < tapError
            ? cands[rnd.nextInt(cands.length)]
            : truth;
        finalCat = tapped;
        model.confirm(app, minor, hour, tapped);
      }
      final ranked = [for (final g in model.rank(app, minor, hour)) g.category];
      void record(Metrics m) {
        m.n++;
        if (pred != null) {
          m.auto++;
          if (pred.category == truth) m.autoRight++;
          if (finalCat != truth) m.silentWrong++;
        } else {
          m.chips++;
          final first = ranked.isNotEmpty ? ranked.first : cands.first;
          if (first == truth) m.topChipHit++;
        }
        if (finalCat == truth) m.finalRight++;
        if (cands.first == truth) m.baselineTopHit++;
      }

      record(res.all);
      if (t < 30) record(res.early);
      if (t >= 100 && t < changeAt) record(res.late);
      if (t >= changeAt && t < changeAt + 40) record(res.changed);
    }
  }
  return res;
}
