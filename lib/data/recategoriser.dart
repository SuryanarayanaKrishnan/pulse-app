import '../core/engine/recategorise.dart';
import 'models.dart';

/// What choosing "all past and future" would do, shown before confirming.
class RecatPreview {
  const RecatPreview({required this.merchant, required this.pastCount});

  /// Normalised merchant name, as shown on the sheet.
  final String merchant;

  /// Past transactions (not counting the one being edited) that would move.
  final int pastCount;
}

/// Everything needed to put things back exactly as they were.
class RecatUndo {
  const RecatUndo({
    required this.txId,
    required this.txCategoryId,
    this.createdRuleId,
    this.replacedRule,
    this.pastBefore = const {},
  });

  final String txId;
  final String? txCategoryId;

  /// Rule created by this change (deleted on undo).
  final String? createdRuleId;

  /// Rule that this change overwrote (restored on undo): column values.
  final Map<String, Object?>? replacedRule;

  /// Past rows changed: id -> (category id, applied rule id) before.
  final Map<String, (String?, String?)> pastBefore;

  int get pastCount => pastBefore.length;
}

/// Optional repository capability: re-categorise with a scope. Only the local
/// and demo repositories implement it; the UI falls back to a plain change.
abstract interface class Recategoriser {
  Future<RecatPreview?> previewRecategorise(String txId, SpendCategory to);

  /// Applies [scope] in one database transaction. Writes go through the
  /// normal tables, so sync picks the changes up like any other edit.
  Future<RecatUndo> recategoriseScoped(
    String txId,
    SpendCategory to,
    RecategoriseScope scope,
  );

  Future<void> undoRecategorise(RecatUndo undo);
}
