/// How one person uses a super-app, learned from their own taps. Pure Dart,
/// free, on-device: a handful of decayed vote counters, no model file.
///
/// A payment is described by two cheap signals, how big it is ([HabitConfig.bandEdgesAed])
/// and when it happened ([daypart]). Each signal keeps its own votes per
/// category. A new confirmation first fades what the signal already holds
/// ([HabitConfig.decay]), so a changed habit takes over within a few taps,
/// then adds one vote.
///
/// Safety against a wrong tap: a prediction is only applied silently when it
/// has real evidence ([HabitConfig.minVotes] agreeing votes) *and* enough of
/// the weighted vote ([HabitConfig.applyAt]). One stray tap on a well-trodden
/// habit cannot flip it, and one tap on a new merchant is never applied on its
/// own: it only reorders the chips.
library;

import 'dart:convert';

class HabitConfig {
  const HabitConfig({
    this.bandEdgesAed = const [30, 100],
    this.daypartEdgesHour = const [5, 11, 15, 19],
    this.decay = 0.95,
    this.applyAt = 0.6,
    this.minVotes = 2.0,
    this.amountWeight = 1.0,
    this.timeWeight = 0.6,
  });

  /// Amount band boundaries in AED: edges [30, 100] make three bands.
  final List<double> bandEdgesAed;

  /// Hours (Dubai time) where a new daypart starts. Hours before the first
  /// edge belong to the last daypart (late night).
  final List<int> daypartEdgesHour;

  /// What existing votes in a signal are multiplied by on each new tap.
  final double decay;

  /// Weighted share of the vote the winner needs to be applied silently.
  final double applyAt;

  /// Agreeing evidence needed before anything is applied silently.
  final double minVotes;
  final double amountWeight, timeWeight;
}

/// What the model says about one payment.
class HabitGuess {
  const HabitGuess(this.category, this.confidence, this.evidence);
  final String category;
  final double confidence;
  final double evidence;
}

class HabitModel {
  HabitModel({this.config = const HabitConfig()});

  final HabitConfig config;

  /// signal key -> category -> decayed votes.
  final Map<String, Map<String, double>> _votes = {};

  int amountBandOf(int amountMinor) {
    final aed = amountMinor / 100;
    var b = 0;
    for (final e in config.bandEdgesAed) {
      if (aed >= e) b++;
    }
    return b;
  }

  int daypartOf(int hour) {
    var d = config.daypartEdgesHour.length - 1;
    for (var i = 0; i < config.daypartEdgesHour.length; i++) {
      if (hour >= config.daypartEdgesHour[i]) d = i;
    }
    return d;
  }

  List<(String, double)> _signals(String app, int amountMinor, int hour) => [
    ('$app#a${amountBandOf(amountMinor)}', config.amountWeight),
    ('$app#t${daypartOf(hour)}', config.timeWeight),
  ];

  /// The person confirmed [category] for this payment.
  void confirm(
    String app,
    int amountMinor,
    int hour,
    String category, {
    double weight = 1.0,
  }) {
    for (final (key, _) in _signals(app, amountMinor, hour)) {
      final m = _votes.putIfAbsent(key, () => {});
      for (final c in m.keys.toList()) {
        m[c] = m[c]! * config.decay;
        if (m[c]! < 0.05) m.remove(c);
      }
      m[category] = (m[category] ?? 0) + weight;
    }
  }

  /// All categories ranked, best first, with their weighted share.
  List<HabitGuess> rank(String app, int amountMinor, int hour) {
    final score = <String, double>{};
    final ev = <String, double>{};
    var denom = 0.0;
    for (final (key, w) in _signals(app, amountMinor, hour)) {
      final m = _votes[key] ?? const <String, double>{};
      final total = m.values.fold(0.0, (a, b) => a + b);
      denom += w * (total + 1);
      for (final e in m.entries) {
        score[e.key] = (score[e.key] ?? 0) + w * e.value;
        ev[e.key] = (ev[e.key] ?? 0) + e.value;
      }
    }
    final out = [
      for (final e in score.entries)
        HabitGuess(e.key, denom == 0 ? 0 : e.value / denom, ev[e.key]!),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return out;
  }

  /// The category to apply without asking, or null when the chips should
  /// show instead.
  HabitGuess? predict(String app, int amountMinor, int hour) {
    final r = rank(app, amountMinor, hour);
    if (r.isEmpty) return null;
    final top = r.first;
    if (top.confidence < config.applyAt || top.evidence < config.minVotes) {
      return null;
    }
    return top;
  }

  String encode() => jsonEncode({
    for (final e in _votes.entries)
      e.key: {for (final v in e.value.entries) v.key: v.value},
  });

  void load(String? raw) {
    _votes.clear();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return;
      for (final e in j.entries) {
        final v = e.value;
        if (v is! Map) continue;
        _votes['${e.key}'] = {
          for (final x in v.entries)
            if (x.value is num) '${x.key}': (x.value as num).toDouble(),
        };
      }
    } on Object {
      _votes.clear();
    }
  }

  void clear() => _votes.clear();
}

/// The hour of day in Dubai (UTC+4, no daylight saving) of an instant.
int dubaiHour(DateTime when) => when.toUtc().add(const Duration(hours: 4)).hour;

/// On-device counters for retuning later. Only counts, never merchants,
/// amounts or text; they never leave the phone.
class HabitStats {
  int chipsShown = 0, chipTaps = 0, topChipTaps = 0;
  int autoApplied = 0, autoCorrected = 0;

  Map<String, int> toJson() => {
    'chipsShown': chipsShown,
    'chipTaps': chipTaps,
    'topChipTaps': topChipTaps,
    'autoApplied': autoApplied,
    'autoCorrected': autoCorrected,
  };

  void load(String? raw) {
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return;
      int g(String k) => (j[k] is int) ? j[k] as int : 0;
      chipsShown = g('chipsShown');
      chipTaps = g('chipTaps');
      topChipTaps = g('topChipTaps');
      autoApplied = g('autoApplied');
      autoCorrected = g('autoCorrected');
    } on Object {
      // ignore
    }
  }

  String encode() => jsonEncode(toJson());
}
