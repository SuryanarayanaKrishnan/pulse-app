import 'models.dart';

/// What a rule looks at.
enum RuleField {
  merchant('Merchant'),
  description('Description'),
  amount('Amount'),
  account('Account');

  const RuleField(this.label);
  final String label;

  bool get numeric => this == RuleField.amount;

  List<RuleOperator> get operators => numeric
      ? const [
          RuleOperator.equals,
          RuleOperator.greaterThan,
          RuleOperator.lessThan,
        ]
      : const [
          RuleOperator.contains,
          RuleOperator.equals,
          RuleOperator.startsWith,
        ];
}

enum RuleOperator {
  contains('contains'),
  equals('is'),
  startsWith('starts with'),
  greaterThan('is over'),
  lessThan('is under');

  const RuleOperator(this.label);
  final String label;
}

/// What a rule does to a matching transaction.
enum RuleAction {
  setCategory('Set category'),
  rename('Rename'),
  exclude('Exclude from budget');

  const RuleAction(this.label);
  final String label;
}

/// "When `field` `operator` `value`, do `action`."
class AutomationRule {
  const AutomationRule({
    required this.id,
    required this.field,
    required this.op,
    required this.value,
    required this.action,
    this.category,
    this.renameTo,
    this.enabled = true,
  });

  final String id;
  final RuleField field;
  final RuleOperator op;
  final String value;
  final RuleAction action;

  /// For [RuleAction.setCategory].
  final SpendCategory? category;

  /// For [RuleAction.rename].
  final String? renameTo;
  final bool enabled;

  /// The simple shape the backend's merchant rules support.
  bool get isMerchantCategoryRule =>
      field == RuleField.merchant &&
      op == RuleOperator.equals &&
      action == RuleAction.setCategory;

  bool get isValid {
    if (value.trim().isEmpty) return false;
    if (!field.operators.contains(op)) return false;
    if (field.numeric && double.tryParse(value.trim()) == null) return false;
    return switch (action) {
      RuleAction.setCategory => category != null,
      RuleAction.rename => (renameTo ?? '').trim().isNotEmpty,
      RuleAction.exclude => true,
    };
  }

  bool matches(Transaction t) {
    if (!enabled || !isValid) return false;
    if (field.numeric) {
      final v = double.parse(value.trim());
      return switch (op) {
        RuleOperator.greaterThan => t.amount > v,
        RuleOperator.lessThan => t.amount < v,
        _ => (t.amount - v).abs() < 0.005,
      };
    }
    final subject = normaliseText(switch (field) {
      RuleField.merchant => t.merchant,
      RuleField.description => t.description,
      RuleField.account => t.accountLabel,
      RuleField.amount => '',
    });
    final needle = normaliseText(value);
    return switch (op) {
      RuleOperator.equals => subject == needle,
      RuleOperator.startsWith => subject.startsWith(needle),
      _ => subject.contains(needle),
    };
  }

  String get condition {
    final v = field.numeric ? 'AED ${value.trim()}' : '"${value.trim()}"';
    return '${field.label} ${op.label} $v';
  }

  String get outcome => switch (action) {
    RuleAction.setCategory => 'Categorise as ${category?.label ?? '?'}',
    RuleAction.rename => 'Rename to "${renameTo ?? ''}"',
    RuleAction.exclude => 'Exclude from budget',
  };

  AutomationRule copyWith({String? id, bool? enabled}) => AutomationRule(
    id: id ?? this.id,
    field: field,
    op: op,
    value: value,
    action: action,
    category: category,
    renameTo: renameTo,
    enabled: enabled ?? this.enabled,
  );
}

/// Lower-case, trimmed, single-spaced.
String normaliseText(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Applies every enabled matching rule in order. Later rules win when two
/// rules set the same thing. Rules see the transaction as captured, so a
/// rename does not change what later merchant rules match.
Transaction applyRules(Transaction t, List<AutomationRule> rules) {
  var out = t;
  for (final r in rules) {
    if (!r.matches(t)) continue;
    out = switch (r.action) {
      RuleAction.setCategory => out.copyWith(category: r.category),
      RuleAction.rename => out.copyWith(merchant: r.renameTo!.trim()),
      RuleAction.exclude => out.copyWith(excluded: true),
    };
  }
  return out;
}

/// The rule offered after a manual re-categorisation:
/// "Always categorise `merchant` as `category`?"
AutomationRule suggestMerchantRule(Transaction t, SpendCategory category) =>
    AutomationRule(
      id: '',
      field: RuleField.merchant,
      op: RuleOperator.equals,
      value: t.merchant,
      action: RuleAction.setCategory,
      category: category,
    );

/// True when an enabled rule already sends [merchant] to [category], so the
/// suggestion would be redundant.
bool hasMerchantRule(
  List<AutomationRule> rules,
  String merchant,
  SpendCategory category,
) => rules.any(
  (r) =>
      r.enabled &&
      r.field == RuleField.merchant &&
      r.action == RuleAction.setCategory &&
      r.category == category &&
      switch (r.op) {
        RuleOperator.equals =>
          normaliseText(merchant) == normaliseText(r.value),
        RuleOperator.contains => normaliseText(
          merchant,
        ).contains(normaliseText(r.value)),
        RuleOperator.startsWith => normaliseText(
          merchant,
        ).startsWith(normaliseText(r.value)),
        _ => false,
      },
);

/// What saving a rule would do to history.
class RulePreviewSummary {
  const RulePreviewSummary({required this.matched, required this.wouldChange});
  final int matched;
  final int wouldChange;
}
