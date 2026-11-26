import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../capture/providers.dart' show kvStoreProvider;
import 'card_combos.dart';

/// A combo is "high value" when its estimated yearly saving is at least this
/// many dirhams. Only a figure the catalog worked out counts.
const highValueSavingAed = 500.0;

bool isHighValue(CardCombo c) =>
    c.hasSaving && !c.isWarning && c.annualSavingAed! >= highValueSavingAed;

/// Up to [max] combos for the "Best moves" strip: positive combos with a
/// savings figure first (biggest first, as [parseCombos] sorts them), then
/// free combos without a figure so the strip is never a single card. Warnings
/// and caveats stay in the full list.
List<CardCombo> pickBestMoves(List<CardCombo> all, {int max = 3}) {
  final withFigure = [
    for (final c in all)
      if (c.hasSaving && !c.isWarning) c,
  ];
  final others = [
    for (final c in all)
      if (!c.hasSaving && !c.isWarning && !c.isPlus) c,
  ];
  return [...withFigure, ...others].take(max).toList();
}

const seenCombosKey = 'combos.seen';

/// Which combos the person has already looked at, kept on this phone.
class SeenCombosController extends Notifier<({bool loaded, Set<String> ids})> {
  @override
  ({bool loaded, Set<String> ids}) build() {
    _load();
    return (loaded: false, ids: const {});
  }

  Future<void> _load() async {
    var ids = <String>{};
    try {
      final raw = await ref.read(kvStoreProvider).read(seenCombosKey);
      if (raw != null)
        ids = {for (final x in jsonDecode(raw) as List) x as String};
    } catch (_) {}
    if (ref.mounted) state = (loaded: true, ids: {...ids, ...state.ids});
  }

  /// Everything in [ids] counts as seen from now on.
  Future<void> markSeen(Iterable<String> ids) async {
    final next = {...state.ids, ...ids};
    if (next.length == state.ids.length && state.loaded) return;
    state = (loaded: true, ids: next);
    try {
      await ref
          .read(kvStoreProvider)
          .write(seenCombosKey, jsonEncode(next.toList()..sort()));
    } catch (_) {}
  }
}

final seenCombosProvider =
    NotifierProvider<SeenCombosController, ({bool loaded, Set<String> ids})>(
      SeenCombosController.new,
    );

/// High-value combos that have not been opened yet. Empty until the seen list
/// has loaded, so the badge never flashes for something already seen.
final newHighValueCombosProvider = Provider<Set<String>>((ref) {
  final seen = ref.watch(seenCombosProvider);
  if (!seen.loaded) return const {};
  final combos = ref.watch(cardCombosProvider).value ?? const <CardCombo>[];
  return {
    for (final c in combos)
      if (isHighValue(c) && !seen.ids.contains(c.id)) c.id,
  };
});
