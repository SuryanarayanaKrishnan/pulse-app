/// Financial health score (pure): four components scored 0-100, combined by
/// weight. Components without data are left out and the rest renormalised;
/// with less than half the weight available there is no overall score (we say
/// so rather than guess). Port of `app/services/health.py`.
library;

import 'dart:math' as math;

import 'types.dart';

const healthWeights = {
  'savings_rate': 30,
  'credit_utilisation': 25,
  'on_time_payments': 25,
  'emergency_runway': 20,
};
const _labels = {
  'savings_rate': 'saving',
  'credit_utilisation': 'credit use',
  'on_time_payments': 'paying cards on time',
  'emergency_runway': 'emergency cushion',
};
const minCoverage = 0.5;
const targetSavingsRate = 0.20;
const targetRunwayMonths = 6.0;
const _utilisationCurve = [
  (0.0, 100.0),
  (10.0, 100.0),
  (30.0, 70.0),
  (50.0, 30.0),
  (80.0, 0.0),
];

class Component {
  const Component(this.key, this.weight, this.score, this.value, this.detail);
  final String key;
  final int weight;
  final int? score;
  final double? value;
  final String detail;
}

int _clamp(double x) => roundHalfEven(math.max(0.0, math.min(100.0, x)));

Component savingsComponent(double? rate) {
  const w = 30;
  if (rate == null) {
    return const Component(
      'savings_rate',
      w,
      null,
      null,
      'No income recorded in recent months',
    );
  }
  return Component(
    'savings_rate',
    w,
    _clamp(rate / targetSavingsRate * 100),
    roundTo(rate, 4),
    'You kept ${fmtFixed(rate * 100, 0)}% of income over 3 months (target ${fmtFixed(targetSavingsRate * 100, 0)}%)',
  );
}

Component utilisationComponent(int? owedMinor, int? limitMinor) {
  const w = 25;
  if (limitMinor == null || limitMinor == 0 || owedMinor == null) {
    return const Component(
      'credit_utilisation',
      w,
      null,
      null,
      'No credit-card limit and balance known',
    );
  }
  final pct = math.max(0, owedMinor) / limitMinor * 100;
  var score = _utilisationCurve.last.$2;
  for (var i = 0; i < _utilisationCurve.length - 1; i++) {
    final (x0, y0) = _utilisationCurve[i];
    final (x1, y1) = _utilisationCurve[i + 1];
    if (pct <= x1) {
      score = y0 + (y1 - y0) * (pct - x0) / (x1 - x0);
      break;
    }
  }
  return Component(
    'credit_utilisation',
    w,
    _clamp(score),
    roundTo(pct, 1),
    'Cards are ${fmtFixed(pct, 0)}% used overall',
  );
}

Component onTimeComponent(int paidOnTime, int total) {
  const w = 25;
  if (total == 0) {
    return const Component(
      'on_time_payments',
      w,
      null,
      null,
      'No past card statements to judge',
    );
  }
  return Component(
    'on_time_payments',
    w,
    _clamp(paidOnTime / total * 100),
    roundTo(paidOnTime / total, 4),
    '$paidOnTime of $total recent card statements had at least the minimum paid by the due date',
  );
}

Component runwayComponent(int? liquidMinor, int? monthlySpendMinor) {
  const w = 20;
  if (liquidMinor == null ||
      monthlySpendMinor == null ||
      monthlySpendMinor == 0) {
    return const Component(
      'emergency_runway',
      w,
      null,
      null,
      'Need a known balance and some spending history',
    );
  }
  final months = math.max(0, liquidMinor) / monthlySpendMinor;
  return Component(
    'emergency_runway',
    w,
    _clamp(months / targetRunwayMonths * 100),
    roundTo(months, 1),
    'Your cash covers about ${fmtFixed(months, 1)} months of spending (target ${fmtFixed(targetRunwayMonths, 0)})',
  );
}

String band(int score) => score >= 80
    ? 'strong'
    : score >= 60
    ? 'good'
    : score >= 40
    ? 'fair'
    : 'needs_attention';

class Health {
  const Health(
    this.score,
    this.band,
    this.coverage,
    this.components,
    this.summary,
  );
  final int? score;
  final String? band;
  final double coverage;
  final List<Component> components;
  final String summary;
}

Health computeHealth(List<Component> components) {
  final total = components.fold<int>(0, (a, c) => a + c.weight);
  final avail = components.where((c) => c.score != null).toList();
  final weight = avail.fold<int>(0, (a, c) => a + c.weight);
  final coverage = total == 0 ? 0.0 : roundTo(weight / total, 2);
  if (avail.isEmpty || coverage < minCoverage) {
    return Health(
      null,
      null,
      coverage,
      components,
      'Not enough data yet for a score: add balances and statements.',
    );
  }
  final score = roundHalfEven(
    avail.fold<double>(0, (a, c) => a + c.score! * c.weight) / weight,
  );
  // max/min by (score, weight) / (score, -weight): the first of equals wins.
  var best = avail.first, worst = avail.first;
  for (final c in avail.skip(1)) {
    if (c.score! > best.score! ||
        (c.score == best.score && c.weight > best.weight))
      best = c;
    if (c.score! < worst.score! ||
        (c.score == worst.score && c.weight > worst.weight))
      worst = c;
  }
  final b = band(score);
  final label = b.replaceAll('_', ' ');
  final summary = best.key == worst.key
      ? 'Health score $score ($label), based on ${_labels[best.key]} only.'
      : 'Health score $score ($label): strongest on ${_labels[best.key]}, most room to improve on ${_labels[worst.key]}.';
  return Health(score, b, coverage, components, summary);
}
