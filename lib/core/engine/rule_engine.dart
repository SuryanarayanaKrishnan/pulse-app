/// Classification rules: conditions are AND-ed, rules are tried in priority
/// order. Port of `app/services/rule_engine.py` plus the resolver from
/// `categorisation.py` (user rules first, then the merchant dictionary).
library;

import '../learning/global_merchant_map.dart';
import '../learning/merchant_memory.dart';
import 'merchants.dart';
import 'types.dart';

/// Tag on a payment whose category came from the person's own earlier choice.
const learnedTag = 'learned';

const maxRegexLen = 200;
const maxSubjectLen = 500;

final _nestedQuantifier = RegExp(
  r'\((?:[^()\\]|\\.)*[+*](?:[^()\\]|\\.)*\)[+*{]',
);

/// Compiles a user pattern or throws [FormatException] (overlong, nested
/// quantifiers - the classic ReDoS shape - or invalid).
RegExp checkRegex(String pattern) {
  if (pattern.length > maxRegexLen) {
    throw const FormatException('regex is too long');
  }
  if (_nestedQuantifier.hasMatch(pattern)) {
    throw const FormatException('regex has nested quantifiers');
  }
  try {
    return RegExp(pattern, caseSensitive: false);
  } on FormatException {
    throw const FormatException('invalid regex');
  }
}

/// What a rule may look at.
class TxnFacts {
  const TxnFacts({
    this.merchantRaw,
    this.merchantNormalized,
    this.notes,
    this.amountMinor,
    this.direction,
    this.accountId,
    this.source,
  });
  final String? merchantRaw;
  final String? merchantNormalized;
  final String? notes;
  final int? amountMinor;
  final Direction? direction;
  final String? accountId;
  final TxnSource? source;
}

typedef Predicate = bool Function(TxnFacts f);

List<String> _texts(List<String?> values) => [
  for (final v in values)
    if (v != null && v.isNotEmpty)
      (v.toLowerCase().length > maxSubjectLen
          ? v.toLowerCase().substring(0, maxSubjectLen)
          : v.toLowerCase()),
];

Predicate _textPredicate(String field, String op, String value) {
  final needle = value.toLowerCase();
  final regex = op == 'regex' ? checkRegex(value) : null;
  List<String> subjects(TxnFacts f) => field == 'merchant'
      ? _texts([f.merchantNormalized, f.merchantRaw])
      : _texts([f.merchantRaw, f.notes]);
  return (f) {
    final subs = subjects(f);
    switch (op) {
      case 'contains':
        return subs.any((s) => s.contains(needle));
      case 'equals':
        if (field == 'merchant') {
          final key = merchantKey(value);
          return subs.any((s) => merchantKey(s) == key);
        }
        return subs.any((s) => s.trim() == needle.trim());
      default:
        return subs.any((s) => regex!.hasMatch(s));
    }
  };
}

Predicate _amountPredicate(Map<String, Object?> c) {
  final op = c['op'];
  int n(String k) => (c[k]! as num).toInt();
  return (f) {
    final a = f.amountMinor;
    if (a == null) return false;
    return switch (op) {
      'equals' => a == n('value_minor'),
      'gte' => a >= n('value_minor'),
      'lte' => a <= n('value_minor'),
      _ => n('min_minor') <= a && a <= n('max_minor'),
    };
  };
}

Predicate compileCondition(Map<String, Object?> c) {
  final kind = c['field'];
  switch (kind) {
    case 'merchant' || 'description':
      return _textPredicate(
        kind! as String,
        c['op']! as String,
        c['value']! as String,
      );
    case 'amount':
      return _amountPredicate(c);
    case 'direction':
      final want = Direction.tryParse(c['value'] as String?);
      return (f) => f.direction == want;
    case 'account':
      final id = '${c['account_id']}'.toLowerCase();
      return (f) => f.accountId?.toLowerCase() == id;
    case 'source':
      final src = TxnSource.tryParse(c['value'] as String?);
      return (f) => f.source == src;
  }
  throw FormatException('unknown condition field $kind');
}

class CompiledRule {
  const CompiledRule({
    required this.predicates,
    this.id,
    this.priority = 0,
    this.categoryId,
    this.renameMerchant,
    this.markTransfer = false,
    this.excludeFromBudget = false,
    this.tags = const [],
  });
  final String? id;
  final int priority;
  final List<Predicate> predicates;
  final String? categoryId;
  final String? renameMerchant;
  final bool markTransfer;
  final bool excludeFromBudget;
  final List<String> tags;

  /// A rule without conditions never matches.
  bool matches(TxnFacts f) =>
      predicates.isNotEmpty && predicates.every((p) => p(f));
}

CompiledRule compileRule(
  Iterable<Map<String, Object?>> conditions, {
  String? id,
  int priority = 0,
  String? categoryId,
  String? renameMerchant,
  bool markTransfer = false,
  bool excludeFromBudget = false,
  List<String> tags = const [],
}) => CompiledRule(
  id: id,
  priority: priority,
  predicates: [for (final c in conditions) compileCondition(c)],
  categoryId: categoryId,
  renameMerchant: renameMerchant,
  markTransfer: markTransfer,
  excludeFromBudget: excludeFromBudget,
  tags: tags,
);

/// The learnt shortcut "always categorise merchant X as Y".
CompiledRule merchantEqualsRule(
  String key,
  String categoryId, {
  String? id,
  int priority = 1000,
}) => compileRule(
  [
    {'field': 'merchant', 'op': 'equals', 'value': key},
  ],
  id: id,
  priority: priority,
  categoryId: categoryId,
);

class RuleOutcome {
  String? categoryId;
  String? renameMerchant;
  bool markTransfer = false;
  bool excludeFromBudget = false;
  final List<String> tags = [];
  final List<String> ruleIds = [];

  /// The rule that decided the category, else the first match.
  String? firstRuleId;
}

/// Runs [rules] (already in priority order); null when nothing matched. The
/// first rule that sets a field wins that field; tags accumulate.
RuleOutcome? evaluate(List<CompiledRule> rules, TxnFacts facts) {
  RuleOutcome? out;
  for (final rule in rules) {
    if (!rule.matches(facts)) continue;
    out ??= RuleOutcome()..firstRuleId = rule.id;
    if (rule.id != null) out.ruleIds.add(rule.id!);
    if (out.categoryId == null && rule.categoryId != null) {
      out.categoryId = rule.categoryId;
      out.firstRuleId = rule.id;
    }
    if (out.renameMerchant == null &&
        rule.renameMerchant != null &&
        rule.renameMerchant!.isNotEmpty) {
      out.renameMerchant = rule.renameMerchant;
    }
    out.markTransfer = out.markTransfer || rule.markTransfer;
    out.excludeFromBudget = out.excludeFromBudget || rule.excludeFromBudget;
    for (final t in rule.tags) {
      if (!out.tags.contains(t)) out.tags.add(t);
    }
  }
  return out;
}

/// Sorts rules the way they are evaluated: lowest priority number first, then
/// stable by the given order.
List<CompiledRule> byPriority(List<CompiledRule> rules) {
  final indexed = [for (var i = 0; i < rules.length; i++) (i, rules[i])];
  indexed.sort((a, b) {
    final c = a.$2.priority.compareTo(b.$2.priority);
    return c != 0 ? c : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

class Enrichment {
  const Enrichment({
    required this.merchantNormalized,
    required this.categoryId,
    required this.source,
    this.excludeFromBudget = false,
    this.tags = const [],
    this.ruleId,
    this.matchedRuleIds = const [],
  });
  final String? merchantNormalized;
  final String? categoryId;

  /// `rule`, `memory`, `dictionary`, `global_map` or null.
  final String? source;
  final bool excludeFromBudget;
  final List<String> tags;
  final String? ruleId;
  final List<String> matchedRuleIds;
}

/// Deterministic categorisation: the user's rules first, then the curated
/// dictionary. [systemCategories] maps default slugs to category ids.
class CategoryResolver {
  CategoryResolver(
    List<CompiledRule> rules,
    this.systemCategories, {
    this.globalMap,
    this.memory,
  }) : rules = byPriority(rules);

  /// What this person has confirmed before. Consulted after their explicit
  /// rules and before the built-in dictionary: their own choice beats a default.
  final MerchantMemory? memory;

  /// Consulted after the user's rules and the built-in dictionary, before
  /// giving up (see `GlobalMerchantMap`).
  final GlobalMerchantMap? globalMap;

  final List<CompiledRule> rules;
  final Map<String, String> systemCategories;

  Enrichment apply(
    RuleOutcome? outcome,
    String? normalized,
    String? dictionarySlug,
  ) {
    var category = outcome?.categoryId;
    if (category == null && outcome != null && outcome.markTransfer) {
      category = systemCategories['transfer'];
    }
    String? source = category != null && outcome != null ? 'rule' : null;
    var learned = false;
    if (category == null && outcome?.markTransfer != true) {
      final hit = memory?.lookup(normalized);
      final memoryCat = hit == null
          ? null
          : (systemCategories[hit.category] ??
                (systemCategories.containsValue(hit.category)
                    ? hit.category
                    : null));
      if (memoryCat != null) {
        category = memoryCat;
        source = 'memory';
        learned = true;
      }
    }
    if (category == null &&
        dictionarySlug != null &&
        systemCategories.containsKey(dictionarySlug)) {
      category = systemCategories[dictionarySlug];
      source = 'dictionary';
    }
    if (category == null) {
      final slug = globalMap?.lookup(normalized);
      if (slug != null && systemCategories.containsKey(slug)) {
        category = systemCategories[slug];
        source = 'global_map';
      }
    }
    if (outcome == null) {
      return Enrichment(
        merchantNormalized: normalized,
        categoryId: category,
        source: source,
        tags: learned ? const [learnedTag] : const [],
      );
    }
    return Enrichment(
      merchantNormalized: outcome.renameMerchant ?? normalized,
      categoryId: category,
      source: source,
      excludeFromBudget: outcome.excludeFromBudget || outcome.markTransfer,
      tags: [...outcome.tags, if (learned) learnedTag],
      ruleId: outcome.firstRuleId,
      matchedRuleIds: List.of(outcome.ruleIds),
    );
  }

  Enrichment enrich(
    String? merchantRaw,
    Direction? direction, {
    String? accountId,
    int? amountMinor,
    TxnSource? source,
    String? notes,
  }) {
    final normalized = normalizeMerchant(merchantRaw, direction);
    final facts = TxnFacts(
      merchantRaw: merchantRaw,
      merchantNormalized: normalized,
      notes: notes,
      amountMinor: amountMinor,
      direction: direction,
      accountId: accountId,
      source: source,
    );
    return apply(
      evaluate(rules, facts),
      normalized,
      guessCategorySlug(merchantRaw, direction),
    );
  }
}

/// Preview of applying a rule to history: how many match and which would
/// change category. [rows] are (id, facts, currentCategoryId).
class RulePreview {
  const RulePreview(
    this.matchedCount,
    this.scannedCount,
    this.matchedIds,
    this.wouldChangeIds,
  );
  final int matchedCount;
  final int scannedCount;
  final List<String> matchedIds;
  final List<String> wouldChangeIds;
}

RulePreview previewRule(
  CompiledRule rule,
  Iterable<({String id, TxnFacts facts, String? categoryId})> rows, {
  bool onlyUncategorised = false,
  String? transferCategoryId,
}) {
  final target =
      rule.categoryId ?? (rule.markTransfer ? transferCategoryId : null);
  var scanned = 0;
  final matched = <String>[], change = <String>[];
  for (final r in rows) {
    if (onlyUncategorised && r.categoryId != null) continue;
    scanned++;
    if (!rule.matches(r.facts)) continue;
    matched.add(r.id);
    if (target != null && r.categoryId != target) change.add(r.id);
  }
  return RulePreview(matched.length, scanned, matched, change);
}
