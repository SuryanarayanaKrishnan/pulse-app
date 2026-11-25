import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tour/tour_progress.dart';

/// Screens that have a first-visit walkthrough.
enum CoachScreen {
  home('home'),
  budget('budget'),
  cards('cards'),
  splits('splits'),
  wealth('wealth'),
  categories('categories'),
  vault('vault'),
  capture('capture'),
  plus('plus');

  const CoachScreen(this.key);
  final String key;
}

@immutable
class CoachProgress {
  const CoachProgress({
    this.loaded = false,
    this.storageFailed = false,
    this.seen = const {},
  });
  final bool loaded;

  /// Storage could not be read: stay quiet rather than nag.
  final bool storageFailed;
  final Set<CoachScreen> seen;

  bool isSeen(CoachScreen s) => storageFailed || seen.contains(s);
}

class CoachProgressController extends Notifier<CoachProgress> {
  static String keyOf(CoachScreen s) => 'coach.seen.${s.key}';

  @override
  CoachProgress build() {
    _load();
    return const CoachProgress();
  }

  Future<void> _load() async {
    try {
      final kv = ref.read(tourKvProvider);
      final seen = <CoachScreen>{};
      for (final s in CoachScreen.values) {
        if (await kv.read(keyOf(s)) == '1') seen.add(s);
      }
      if (!ref.mounted) return;
      state = CoachProgress(loaded: true, seen: seen);
    } catch (_) {
      if (ref.mounted) {
        state = const CoachProgress(loaded: true, storageFailed: true);
      }
    }
  }

  Future<void> markSeen(CoachScreen s) async {
    if (state.seen.contains(s)) return;
    state = CoachProgress(
      loaded: state.loaded,
      storageFailed: state.storageFailed,
      seen: {...state.seen, s},
    );
    try {
      await ref.read(tourKvProvider).write(keyOf(s), '1');
    } catch (_) {}
  }

  /// Settings > Replay walkthroughs: every screen shows its walkthrough again.
  Future<void> resetAll() async {
    state = CoachProgress(
      loaded: state.loaded,
      storageFailed: state.storageFailed,
    );
    try {
      for (final s in CoachScreen.values) {
        await ref.read(tourKvProvider).remove(keyOf(s));
      }
    } catch (_) {}
  }
}

final coachProgressProvider =
    NotifierProvider<CoachProgressController, CoachProgress>(
      CoachProgressController.new,
    );
