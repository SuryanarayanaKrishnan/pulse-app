import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/kv_store.dart';

/// The five tabs that each get one first-visit tip.
enum TipTab {
  home('home', '/home'),
  budget('budget', '/budget'),
  cards('cards', '/cards'),
  splits('splits', '/splits'),
  wealth('wealth', '/wealth');

  const TipTab(this.key, this.path);
  final String key;
  final String path;
}

/// What the user has already seen. Lives in the same local settings storage
/// as backup and capture flags (`shared_preferences` through [KvStore]), not
/// in the encrypted ledger.
@immutable
class TourProgress {
  const TourProgress({
    this.loaded = false,
    this.storageFailed = false,
    this.tourSeen = false,
    this.tips = const {},
  });
  final bool loaded;

  /// Storage could not be read. Fail quiet: show nothing rather than nag.
  final bool storageFailed;
  final bool tourSeen;
  final Set<TipTab> tips;

  bool get shouldShowTour => loaded && !tourSeen && !storageFailed;
  bool tipSeen(TipTab t) => storageFailed || tips.contains(t);

  TourProgress copyWith({bool? tourSeen, Set<TipTab>? tips}) => TourProgress(
    loaded: loaded,
    storageFailed: storageFailed,
    tourSeen: tourSeen ?? this.tourSeen,
    tips: tips ?? this.tips,
  );
}

final tourKvProvider = Provider<KvStore>((ref) => SharedPrefsKvStore());

class TourProgressController extends Notifier<TourProgress> {
  static const tourKey = 'tour.seen';
  static String tipKey(TipTab t) => 'tips.seen.${t.key}';

  @override
  TourProgress build() {
    _ready = _load();
    return const TourProgress();
  }

  late Future<void> _ready;

  /// Completes once the stored state has been read.
  Future<void> get ready => _ready;

  KvStore get _kv => ref.read(tourKvProvider);

  Future<void> _load() async {
    try {
      final kv = _kv;
      final seen = await kv.read(tourKey) == '1';
      final tips = <TipTab>{};
      for (final t in TipTab.values) {
        if (await kv.read(tipKey(t)) == '1') tips.add(t);
      }
      if (!ref.mounted) return;
      state = TourProgress(loaded: true, tourSeen: seen, tips: tips);
    } catch (_) {
      // No storage (tests, blocked site data): stay out of the way.
      if (ref.mounted) {
        state = const TourProgress(loaded: true, storageFailed: true);
      }
    }
  }

  Future<void> markTourSeen() async {
    state = state.copyWith(tourSeen: true);
    try {
      await _kv.write(tourKey, '1');
    } catch (_) {}
  }

  Future<void> markTipSeen(TipTab t) async {
    if (state.tips.contains(t)) return;
    state = state.copyWith(tips: {...state.tips, t});
    try {
      await _kv.write(tipKey(t), '1');
    } catch (_) {}
  }

  /// Settings > Reset tips: every tab tip shows once more.
  Future<void> resetTips() async {
    state = state.copyWith(tips: const {});
    try {
      for (final t in TipTab.values) {
        await _kv.remove(tipKey(t));
      }
    } catch (_) {}
  }
}

final tourProgressProvider =
    NotifierProvider<TourProgressController, TourProgress>(
      TourProgressController.new,
    );
