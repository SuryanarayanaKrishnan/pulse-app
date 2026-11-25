/// A starting budget in one step, from rules only (no network, no LLM).
///
/// Inputs are a monthly take-home, who lives in the household, housing and a
/// car; optionally what the user really spent per category in recent months.
/// Where there is history it wins. Where there is not, a UAE cost norm fills
/// in: shares of income by band, with per-person floors for groceries and
/// utilities. Whatever does not fit is trimmed from the discretionary lines
/// first, so the result always leaves the savings target untouched when it
/// can. The numbers are a starting point the user edits, not advice.
library;

import 'dart:math' as math;

enum Housing {
  rent('Rent'),
  owned('Own, with a mortgage'),
  free('Family or company housing');

  const Housing(this.label);
  final String label;
}

/// Where a suggested amount came from, shown beside it so it is never opaque.
enum SuggestBasis {
  norm('Typical for the UAE'),
  history('Your recent spending'),
  known('What you told us'),
  trimmed('Typical, trimmed to fit');

  const SuggestBasis(this.label);
  final String label;
}

class SuggestInput {
  const SuggestInput({
    required this.incomeMinor,
    this.adults = 1,
    this.children = 0,
    this.housing = Housing.rent,
    this.hasCar = false,
    this.sendsMoneyHome = false,
    this.savingsPct,
    this.history = const {},
    this.known = const {},
  });

  /// Monthly take-home in fils.
  final int incomeMinor;
  final int adults;
  final int children;
  final Housing housing;
  final bool hasCar;
  final bool sendsMoneyHome;

  /// Share of income to set aside (0..0.6). Null: 15%, or 10% with children.
  final double? savingsPct;

  /// Typical monthly spend per category id, in fils, from past statements.
  final Map<String, int> history;

  /// Amounts the user already knows (rent, a car loan), by category id.
  final Map<String, int> known;

  int get people => adults + children;
}

class SuggestedLine {
  const SuggestedLine(this.categoryId, this.amountMinor, this.basis, {required this.fixed});
  final String categoryId;
  final int amountMinor;
  final SuggestBasis basis;

  /// A bill that does not move month to month.
  final bool fixed;

  SuggestedLine withAmount(int minor, SuggestBasis b) => SuggestedLine(categoryId, minor, b, fixed: fixed);
}

class SuggestedBudget {
  const SuggestedBudget({required this.lines, required this.savingsMinor, required this.incomeMinor});
  final List<SuggestedLine> lines;
  final int savingsMinor;
  final int incomeMinor;

  int get spendMinor => lines.fold(0, (a, l) => a + l.amountMinor);
  int get leftoverMinor => incomeMinor - spendMinor - savingsMinor;
  SuggestedLine? line(String id) => lines.where((l) => l.categoryId == id).firstOrNull;
}

/// The income bands rent is sized on: lower earners spend a bigger share.
double rentShare(int incomeMinor) {
  final aed = incomeMinor / 100;
  if (aed < 8000) return 0.35;
  if (aed < 20000) return 0.30;
  if (aed < 40000) return 0.25;
  return 0.20;
}

int _roundNice(int minor) {
  final aed = (minor / 100).round();
  final step = aed >= 2000 ? 50 : (aed >= 300 ? 10 : 5);
  return (aed / step).round() * step * 100;
}

int _clamp(int v, int lo, int hi) => math.max(lo, math.min(hi, v));

SuggestedBudget suggestBudget(SuggestInput i) {
  final income = math.max(0, i.incomeMinor);
  final adults = math.max(1, i.adults);
  final kids = math.max(0, i.children);
  final people = adults + kids;
  final pct = (i.savingsPct ?? (kids > 0 ? 0.10 : 0.15)).clamp(0.0, 0.6);
  final savings = _roundNice((income * pct).round());

  int share(double p) => (income * p).round();

  // Norms, in fils. Fixed bills first, then the flexible lines.
  final norm = <String, (int, bool)>{
    if (i.housing == Housing.rent) 'rent': (share(rentShare(income)), true),
    if (i.housing == Housing.owned) 'home_loan': (share(rentShare(income)), true),
    'groceries': (_clamp(adults * 60000 + kids * 35000, 40000, share(0.18)), false),
    'utilities': (_clamp(25000 + people * 9000, 25000, 90000), false),
    'telecom': (_clamp(15000 + adults * 10000, 15000, 50000), true),
    'transport': (
      i.hasCar ? _clamp(share(0.055), 40000, 180000) : _clamp(adults * 25000, 15000, 60000),
      false,
    ),
    'dining': (_clamp(share(0.06), 20000, 250000), false),
    'health': (_clamp(share(0.025) + kids * 10000, 15000, 150000), false),
    'shopping': (_clamp(share(0.05), 20000, 250000), false),
    'entertainment': (_clamp(share(0.03), 10000, 150000), false),
    'travel': (_clamp(share(0.04), 0, 200000), false),
    if (kids > 0) 'education': (_clamp(kids * share(0.07), 0, kids * 300000), true),
    if (i.sendsMoneyHome) 'family': (share(0.05), false),
    'fees': (_clamp(share(0.005), 2000, 20000), false),
    'other': (_clamp(share(0.02), 10000, 100000), false),
  };

  final lines = <String, SuggestedLine>{};
  norm.forEach((id, v) {
    lines[id] = SuggestedLine(id, _roundNice(v.$1), SuggestBasis.norm, fixed: v.$2);
  });

  // History beats a norm; a user-stated amount beats both. Spending history
  // is nudged 5% up for flexible lines so the plan has a little room.
  i.history.forEach((id, minor) {
    if (minor <= 0 || id == 'salary' || id == 'savings') return;
    final fixed = lines[id]?.fixed ?? _fixedIds.contains(id);
    final v = fixed ? minor : (minor * 1.05).round();
    lines[id] = SuggestedLine(id, _roundNice(v), SuggestBasis.history, fixed: fixed);
  });
  i.known.forEach((id, minor) {
    if (minor <= 0) return;
    final fixed = lines[id]?.fixed ?? _fixedIds.contains(id);
    lines[id] = SuggestedLine(id, minor, SuggestBasis.known, fixed: fixed);
  });
  // A known mortgage or rent replaces the norm for the other kind.
  if (i.known.containsKey('rent') && i.housing != Housing.rent) lines.remove('rent');

  // Fit: spend plus savings must not exceed income. Trim discretionary lines
  // (only ones that came from a norm) in proportion, down to half at most.
  final room = income - savings;
  var spend = lines.values.fold<int>(0, (a, l) => a + l.amountMinor);
  if (income > 0 && spend > room) {
    final trimmable = lines.values
        .where((l) => !l.fixed && l.basis == SuggestBasis.norm && l.categoryId != 'groceries')
        .toList();
    final pool = trimmable.fold<int>(0, (a, l) => a + l.amountMinor);
    final over = spend - room;
    if (pool > 0) {
      final cut = math.min(over, pool ~/ 2);
      final f = 1 - cut / pool;
      for (final l in trimmable) {
        lines[l.categoryId] = l.withAmount(_roundNice((l.amountMinor * f).round()), SuggestBasis.trimmed);
      }
      spend = lines.values.fold<int>(0, (a, l) => a + l.amountMinor);
    }
  }
  final out = lines.values.where((l) => l.amountMinor > 0).toList()
    ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  return SuggestedBudget(lines: out, savingsMinor: income > 0 ? savings : 0, incomeMinor: income);
}

const _fixedIds = {'rent', 'home_loan', 'car_loan', 'telecom', 'fixed_expenses', 'education'};

/// A typical month per category from past spend: the median of the months
/// that had any, so one big month does not set the budget. [byMonth] is
/// category id → month key → fils.
Map<String, int> typicalMonthly(Map<String, Map<String, int>> byMonth, {int lastMonths = 6}) {
  final out = <String, int>{};
  byMonth.forEach((id, months) {
    final keys = months.keys.toList()..sort();
    final recent = keys.length > lastMonths ? keys.sublist(keys.length - lastMonths) : keys;
    final vals = [for (final k in recent) if ((months[k] ?? 0) > 0) months[k]!]..sort();
    if (vals.isEmpty) return;
    final mid = vals.length ~/ 2;
    out[id] = vals.length.isOdd ? vals[mid] : ((vals[mid - 1] + vals[mid]) / 2).round();
  });
  return out;
}
