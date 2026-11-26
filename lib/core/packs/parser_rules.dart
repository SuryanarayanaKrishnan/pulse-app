import '../engine/sms_parser.dart';
import '../engine/types.dart';

/// One bank-text wording from the `parser_rules` content pack
/// (`pulse-api/data/packs/parser_rules.json`, docs/CONTENT.md there):
/// `{"institution": "enbd", "direction": "debit", "pattern": "you spent {AMT} at {M} on card {L4}"}`.
class RemoteSmsRule {
  const RemoteSmsRule(this.institution, this.pattern, this.direction);
  final String institution;
  final String pattern;

  /// Null: infer from the wording.
  final Direction? direction;

  /// A rule is usable only when it names an institution and has an amount
  /// placeholder. Anything else is ignored, never an error.
  static RemoteSmsRule? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final inst = raw['institution'];
    final pat = raw['pattern'];
    if (inst is! String || inst.isEmpty || pat is! String || !pat.contains('{AMT}') || pat.length > 600) {
      return null;
    }
    final dir = switch (raw['direction']) {
      'debit' => Direction.debit,
      'credit' => Direction.credit,
      _ => null,
    };
    return RemoteSmsRule(inst, pat, dir);
  }
}

/// Rules in [pack] that compile. Bad entries are skipped.
List<(RemoteSmsRule, Template)> compileSmsRules(Map<String, Object?>? pack) {
  final out = <(RemoteSmsRule, Template)>[];
  for (final raw in (pack?['sms'] as List?) ?? const []) {
    final rule = RemoteSmsRule.tryParse(raw);
    if (rule == null) continue;
    try {
      out.add((rule, tpl(rule.pattern, rule.direction)));
    } on Object {
      continue; // a pattern that is not a valid expression
    }
  }
  return out;
}

/// Hands the pack's wordings to the matching bank parsers. Idempotent: each
/// call replaces what the previous one added. Rules for a bank the app has no
/// parser for are ignored. Returns how many rules were applied.
int applyParserRules(ParserRegistry registry, Map<String, Object?>? pack) {
  final byBank = <String, List<Template>>{};
  for (final (rule, t) in compileSmsRules(pack)) {
    byBank.putIfAbsent(rule.institution, () => []).add(t);
  }
  for (final key in registry.institutionKeys) {
    final p = registry.get(key);
    if (p is SmsParser) p.setRemoteTemplates(byBank[key] ?? const []);
  }
  var applied = 0;
  for (final e in byBank.entries) {
    if (registry.get(e.key) is SmsParser) applied += e.value.length;
  }
  return applied;
}
