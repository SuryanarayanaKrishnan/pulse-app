import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/insights.dart';
import '../../data/providers.dart';
import 'tokens.dart';

/// How the palette is chosen: from cash flow, or pinned by the person.
enum MoodPreference { auto, sage, stone }

/// Headroom below which the app moves to Stone, and above which it returns
/// to Sage. The gap between the two is the hysteresis that stops the theme
/// flickering when the figure hovers near one line.
const double tightBelow = 0.15;
const double relaxedAbove = 0.25;

/// Share of this month's money that is still free to spend: what is left
/// after bills, card dues and goals, over everything those add up to plus
/// what is left. Null when there is nothing to judge (no budget or cash
/// figures yet).
double? headroom(SafeToSpend s) {
  if (!s.available.isFinite) return null;
  final promised = s.bills + s.cardDues + s.goals;
  final total = s.available + promised;
  if (total <= 0) return null;
  return s.available / total;
}

/// The next mood given the current one and fresh numbers. Pure, so it can be
/// tested without a widget tree.
PulseMood nextMood(PulseMood current, SafeToSpend s) {
  final h = headroom(s);
  if (h == null) return PulseMood.sage;
  if (current == PulseMood.sage) {
    return h < tightBelow ? PulseMood.stone : PulseMood.sage;
  }
  return h > relaxedAbove ? PulseMood.sage : PulseMood.stone;
}

class MoodPreferenceController extends Notifier<MoodPreference> {
  static const _key = 'mood_preference';

  @override
  MoodPreference build() {
    _load();
    return MoodPreference.auto;
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      final m = MoodPreference.values.where((e) => e.name == v).firstOrNull;
      if (m != null && ref.mounted) state = m;
    } catch (_) {
      // No storage (tests, private mode): stay on automatic.
    }
  }

  Future<void> set(MoodPreference pref) async {
    state = pref;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, pref.name);
    } catch (_) {}
  }
}

final moodPreferenceProvider =
    NotifierProvider<MoodPreferenceController, MoodPreference>(
      MoodPreferenceController.new,
    );

/// The palette in use: the pinned one, or Sage / Stone from safe-to-spend.
class MoodController extends Notifier<PulseMood> {
  @override
  PulseMood build() {
    final pref = ref.watch(moodPreferenceProvider);
    if (pref == MoodPreference.sage) return PulseMood.sage;
    if (pref == MoodPreference.stone) return PulseMood.stone;
    ref.listen(safeToSpendProvider, (_, next) {
      final v = next.value;
      if (v != null) state = nextMood(state, v);
    });
    final v = ref.read(safeToSpendProvider).value;
    return v == null ? PulseMood.sage : nextMood(PulseMood.sage, v);
  }
}

final moodProvider = NotifierProvider<MoodController, PulseMood>(
  MoodController.new,
);
