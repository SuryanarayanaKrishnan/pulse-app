/// Pure logic behind "change this category for the merchant too".
///
/// The user picks a scope; this file works out which past transactions a
/// merchant rule would touch, using the same normaliser and rule engine the
/// ingest pipeline uses, so spelling variants of one merchant ("CARREFOUR MOE
/// DUBAI AE 0123", "Carrefour") are treated alike.
library;

import 'merchants.dart';
import 'rule_engine.dart';
import 'types.dart';

/// How far a category change reaches.
enum RecategoriseScope {
  /// Only the transaction that was edited.
  once,

  /// Also every future capture from the merchant (a rule).
  future,

  /// Future captures and every past transaction from the merchant.
  all;

  /// The value used in analytics (`recategorise_scope`).
  String get analyticsValue => name;
}

/// The rule key of a transaction's merchant, or null when it has no usable
/// merchant. Prefers the stored normalised name, else normalises [raw].
String? recategoriseKey({
  String? normalized,
  String? raw,
  Direction? direction,
}) => merchantKey(
  (normalized != null && normalized.trim().isNotEmpty)
      ? normalized
      : normalizeMerchant(raw, direction),
);

/// A stored transaction as the planner sees it.
class RecatRow {
  const RecatRow({
    required this.id,
    required this.categoryId,
    this.merchantRaw,
    this.merchantNormalized,
    this.direction,
  });
  final String id;
  final String? categoryId;
  final String? merchantRaw;
  final String? merchantNormalized;
  final Direction? direction;
}

/// Past transactions a scoped change would re-categorise.
class RecatPlan {
  const RecatPlan(this.key, this.rule, this.pastIds);

  /// Null when there is no merchant to match on.
  final String? key;

  /// The rule that `future` and `all` create. Null when [key] is null.
  final CompiledRule? rule;

  /// Ids of past rows whose category would change (never the edited one).
  final List<String> pastIds;

  int get pastCount => pastIds.length;
}

/// Works out the merchant rule for [key] and which of [rows] it would change
/// to [targetCategoryId]. [excludeId] is the transaction being edited.
///
/// Each row's merchant is normalised again here, so rows stored before a
/// dictionary change still match their variants.
RecatPlan planRecategorise({
  required String? key,
  required String targetCategoryId,
  required Iterable<RecatRow> rows,
  String? excludeId,
}) {
  if (key == null) return const RecatPlan(null, null, []);
  final rule = merchantEqualsRule(key, targetCategoryId);
  final preview = previewRule(rule, [
    for (final r in rows)
      if (r.id != excludeId)
        (
          id: r.id,
          facts: TxnFacts(
            merchantRaw: r.merchantRaw,
            merchantNormalized:
                normalizeMerchant(r.merchantRaw, r.direction) ??
                r.merchantNormalized,
            direction: r.direction,
          ),
          categoryId: r.categoryId,
        ),
  ]);
  return RecatPlan(key, rule, preview.wouldChangeIds);
}
