import '../core/engine/cap_tracker.dart';
import '../core/engine/dates.dart';
import '../core/engine/next_best.dart' show LedgerSpend;
import '../core/engine/rewards.dart' show RankableCard;

/// Everything the cap meters, alerts and next-best suggestion need, read from
/// the on-device ledger in one go.
class CapSnapshot {
  const CapSnapshot({
    required this.today,
    this.cards = const [],
    this.held = const [],
    this.history = const [],
  });

  final CalDate today;

  /// Cap status per owned card for its current cycle.
  final List<CardCapStatus> cards;

  /// The same cards with their cycle state, for ranking.
  final List<RankableCard> held;

  /// Past AED expenses (any account) for the spend forecast.
  final List<LedgerSpend> history;

  Set<String> get heldCatalogIds => {
    for (final c in cards)
      if (c.catalogId != null) c.catalogId!,
  };
}

/// Implemented by repositories that hold the real ledger.
abstract interface class CapSource {
  Future<CapSnapshot> capSnapshot();
}
