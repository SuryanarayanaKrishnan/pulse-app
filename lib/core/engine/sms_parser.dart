/// Template-driven SMS parser used by the per-bank definitions, a generic
/// regex fallback and the registry that picks between them.
///
/// Port of `app/services/parsers/*` (pulse-api). A template is a regex written
/// with placeholders:
///
///   {AMT}  currency + amount          -> groups cur, amt
///   {L4}   masked card/account number -> group  last4
///   {M}    merchant / counterparty    -> group  merchant
///   {DATE} optional date in the text  -> group  date
library;

import 'dates.dart';
import 'institutions.dart';
import 'types.dart';

class ParsedTransaction {
  const ParsedTransaction({
    required this.amountMinor,
    required this.currency,
    required this.direction,
    this.merchantRaw,
    this.last4,
    this.postedAt,
    this.institution,
    this.confidence = 0.5,
  });

  final int amountMinor;
  final String currency;
  final Direction direction;
  final String? merchantRaw;
  final String? last4;
  final DateTime? postedAt;
  final String? institution;
  final double confidence;

  ParsedTransaction copyWith({
    String? institution,
    bool clearInstitution = false,
    double? confidence,
  }) => ParsedTransaction(
    amountMinor: amountMinor,
    currency: currency,
    direction: direction,
    merchantRaw: merchantRaw,
    last4: last4,
    postedAt: postedAt,
    institution: clearInstitution ? null : (institution ?? this.institution),
    confidence: confidence ?? this.confidence,
  );
}

/// One implementation per institution (and one generic fallback).
abstract class MessageParser {
  String get institution;

  /// Cheap check: does this look like it came from this institution?
  bool matches(String? sender, String text);

  /// A transaction, or null when the message is not one (OTP, promo...).
  ParsedTransaction? parse(String text, {DateTime? receivedAt});
}

const _currencies =
    'AED|USD|EUR|GBP|SAR|INR|PKR|QAR|KWD|BHD|OMR|EGP|CHF|JPY|CAD|AUD|SGD|CNY|THB|TRY|LKR|PHP';

final _placeholders = <String, String>{
  '{AMT}':
      '(?<cur>$_currencies|Dhs?\\.?)\\s?(?<amt>\\d[\\d,]*(?:\\.\\d{1,3})?)',
  '{L4}': r'(?:(?:x|X|\*|•){1,}\s?)?(?<last4>\d{4})\b',
  '{M}':
      r"(?<merchant>[A-Za-z0-9&'.\-*/+@ ]{2,60}?)"
      r'(?=\s*(?:\.(?:\s|$)|[,;]|\s(?:on|using|via|with|ref|avl|avail|available|bal|balance|total|date|at|from|'
      r'for|is|was|has|call|if)\b|\s\d{1,2}[/\-]|$))',
  '{DATE}': '(?<date>$dateRe)',
};

final _otp = RegExp(
  r'\b(otp|one[- ]?time (?:password|pin|code)|verification code|do not share|never share|cvv)\b',
  caseSensitive: false,
);
final _otpLoose = RegExp(
  r'\b(otp|one[- ]time|verification code)\b',
  caseSensitive: false,
);
final _ws = RegExp(r'\s+');

/// True for one-time-password style messages. These are never parsed, stored
/// or queued anywhere.
bool isOtpMessage(String text) => _otp.hasMatch(text) || _otpLoose.hasMatch(text);

class Template {
  const Template(this.pattern, this.direction);
  final RegExp pattern;

  /// Null means infer from keywords in the match.
  final Direction? direction;
}

/// Builds a [Template] from placeholder syntax.
Template tpl(String template, [Direction? direction = Direction.debit]) {
  var expanded = template;
  _placeholders.forEach((k, v) => expanded = expanded.replaceAll(k, v));
  return Template(RegExp(expanded, caseSensitive: false), direction);
}

const _cr = Direction.credit;

/// Wordings shared by most UAE banks; bank templates come first.
final List<Template> commonTemplates = [
  tpl(
    r'purchase of {AMT} (?:with|on|using) (?:your )?(?:[\w ]{0,25}?)(?:credit |debit |cr\. ?|dr\. ?)?card[^.]{0,12}?{L4}[, ]+at {M}',
  ),
  tpl(
    r'(?:credit |debit |cr\. ?|dr\. ?)?card[^.]{0,20}?{L4} (?:was|has been) (?:used|charged|debited)(?: for| with)? {AMT}(?: at {M})?',
  ),
  tpl(
    r'{AMT} (?:has been |was )?(?:spent|charged|debited|used)(?: on| using| with| from)? (?:your )?[\w ]{0,25}?card[^.]{0,12}?{L4}(?:[, ]+at {M})?',
  ),
  tpl(
    r'(?:spent|purchase of|paid|payment of) {AMT} at {M}(?: on| using| with)?(?: your)? [\w ]{0,20}?card[^.]{0,12}?{L4}',
  ),
  tpl(
    r'(?:atm )?(?:cash )?withdrawal of {AMT}[^.]{0,40}?{L4}(?:[^.]{0,20}? at {M})?',
  ),
  tpl(
    r'(?:a/c|acct|account)[^.]{0,12}?{L4} (?:has been |was )?debited (?:with|by|for)? ?{AMT}(?: (?:for|to|at) {M})?',
  ),
  tpl(
    r'{AMT} (?:has been |was )?credited to (?:your )?(?:a/c|acct|account|card)[^.]{0,12}?{L4}(?:[^.]{0,20}? (?:from|by) {M})?',
    _cr,
  ),
  tpl(
    r'(?:a/c|acct|account)[^.]{0,12}?{L4} (?:has been |was )?credited (?:with|by)? ?{AMT}(?: (?:from|by) {M})?',
    _cr,
  ),
  tpl(r'(?:salary|refund) (?:of )?{AMT}[^.]{0,40}?{L4}', _cr),
  tpl(r'payment of {AMT} (?:has been )?(?:received|credited)[^.]{0,40}?{L4}', _cr),
];

final _creditWords = RegExp(
  r'credit|refund|deposit|salary|received',
  caseSensitive: false,
);

String? _group(RegExpMatch m, String name) =>
    m.groupNames.contains(name) ? m.namedGroup(name) : null;

/// Concrete parser for one institution, driven by templates.
class SmsParser implements MessageParser {
  SmsParser(
    this.institution,
    List<Template> templates, {
    List<String> nameHints = const [],
  }) : _templates = [...templates, ...commonTemplates],
       _senders = {
         for (final s in institutions.get(institution)?.smsSenders ?? const [])
           normName(s),
       },
       _hints = [
         for (final h in nameHints)
           RegExp(
             '(?<![A-Za-z0-9])${RegExp.escape(h)}(?![A-Za-z0-9])',
             caseSensitive: false,
           ),
       ];

  @override
  final String institution;
  final List<Template> _templates;
  final Set<String> _senders;
  final List<RegExp> _hints;

  @override
  bool matches(String? sender, String text) {
    if (sender != null && _senders.contains(normName(sender))) return true;
    return _hints.any((h) => h.hasMatch(text));
  }

  @override
  ParsedTransaction? parse(String text, {DateTime? receivedAt}) {
    final t = text.replaceAll(_ws, ' ').trim();
    if (t.isEmpty || _otp.hasMatch(t)) return null;
    for (final template in _templates) {
      final m = template.pattern.firstMatch(t);
      if (m == null) continue;
      final direction =
          template.direction ??
          (_creditWords.hasMatch(m[0]!) ? Direction.credit : Direction.debit);
      final cur = _group(m, 'cur')!.toUpperCase();
      final currency = cur.startsWith('DH') ? 'AED' : cur;
      final amountMinor = parseMinorUnits(_group(m, 'amt')!);
      if (amountMinor == null || amountMinor <= 0) continue;
      var postedAt = receivedAt;
      final dateS = _group(m, 'date') ?? _findDate(t);
      if (dateS != null) {
        final d = parseDate(dateS);
        if (d != null) postedAt = atDate(d, receivedAt);
      }
      final merchant = (_group(m, 'merchant') ?? '').trim();
      final cleaned = _stripChars(merchant, ' .-,');
      return ParsedTransaction(
        amountMinor: amountMinor,
        currency: currency,
        direction: direction,
        merchantRaw: cleaned.isEmpty ? null : cleaned,
        last4: _group(m, 'last4'),
        postedAt: postedAt,
        institution: institution,
        confidence: 0.85,
      );
    }
    return null;
  }

  static final _onDate = RegExp('\\bon\\s+($dateRe)', caseSensitive: false);
  static String? _findDate(String text) => _onDate.firstMatch(text)?.group(1);
}

String _stripChars(String s, String chars) {
  var a = 0, b = s.length;
  while (a < b && chars.contains(s[a])) {
    a++;
  }
  while (b > a && chars.contains(s[b - 1])) {
    b--;
  }
  return s.substring(a, b);
}

// ---------------------------------------------------------------------------
// Fallback: bank-agnostic templates, then loose keyword heuristics.
// ---------------------------------------------------------------------------

final _genAmount = RegExp(
  r'(?<cur>AED|USD|EUR|GBP|Dhs?\.?)\s?(?<amt>\d[\d,]*(?:\.\d{1,2})?)',
  caseSensitive: false,
);
final _genLast4 = RegExp(
  r'(?:card|a/c|acct|account)[^\d]{0,20}(?:x+|\*+)?(\d{4})\b',
  caseSensitive: false,
);
final _genMerchant = RegExp(
  r"\b(?:at|to|from)\s+(?!your\b)(?<m>[A-Za-z0-9&'.\-* ]{2,40}?)"
  r'(?=\s+(?:on|using|via|with|ref|avl|available)\b|[.,;]|$)',
  caseSensitive: false,
);
final _genDebit = RegExp(
  r'\b(purchase|spent|debited|withdrawn|paid|payment of|charged)\b',
  caseSensitive: false,
);
final _genCredit = RegExp(
  r'\b(credited|received|deposit(?:ed)?|refund(?:ed)?|salary)\b',
  caseSensitive: false,
);

class GenericParser implements MessageParser {
  GenericParser();
  static final _common = SmsParser('generic', const []);

  @override
  String get institution => 'generic';

  @override
  bool matches(String? sender, String text) => true;

  @override
  ParsedTransaction? parse(String text, {DateTime? receivedAt}) {
    if (_otpLoose.hasMatch(text)) return null;
    final common = _common.parse(text, receivedAt: receivedAt);
    if (common != null) {
      return common.copyWith(clearInstitution: true, confidence: 0.6);
    }
    final amountM = _genAmount.firstMatch(text);
    if (amountM == null) return null;
    final credit = _genCredit.firstMatch(text);
    final debit = _genDebit.firstMatch(text);
    if (credit == null && debit == null) return null;
    final direction =
        credit != null && (debit == null || credit.start < debit.start)
        ? Direction.credit
        : Direction.debit;
    final cur = amountM.namedGroup('cur')!.toUpperCase();
    final currency = cur.startsWith('DH') ? 'AED' : cur;
    var amtS = amountM.namedGroup('amt')!;
    while (amtS.endsWith('.')) {
      amtS = amtS.substring(0, amtS.length - 1);
    }
    final amountMinor = parseMinorUnits(amtS);
    if (amountMinor == null) return null;
    final merchantM = _genMerchant.firstMatch(text);
    final last4M = _genLast4.firstMatch(text);
    return ParsedTransaction(
      amountMinor: amountMinor,
      currency: currency,
      direction: direction,
      merchantRaw: merchantM?.namedGroup('m')?.trim(),
      last4: last4M?.group(1),
      postedAt: receivedAt,
      confidence: 0.4,
    );
  }
}

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

class ParserRegistry {
  ParserRegistry({this.fallback});

  final Map<String, MessageParser> _parsers = {};
  final MessageParser? fallback;

  void register(MessageParser parser) =>
      _parsers[parser.institution.toLowerCase()] = parser;

  MessageParser? get(String? institution) {
    if (institution == null || institution.isEmpty) return null;
    final direct = _parsers[institution.toLowerCase()];
    if (direct != null) return direct;
    final key = institutions.resolveKey(institution);
    return key == null ? null : _parsers[key];
  }

  List<String> get institutionKeys => _parsers.keys.toList()..sort();

  /// Explicit institution, then sender id, then text sniffing, then fallback.
  MessageParser? resolve(String? institution, String? sender, String text) {
    final byName = get(institution);
    if (byName != null) return byName;
    if (sender != null && sender.isNotEmpty) {
      final key = institutions.fromSender(sender);
      if (key != null && _parsers.containsKey(key)) return _parsers[key];
    }
    for (final candidate in _parsers.values) {
      if (candidate.matches(sender, text)) return candidate;
    }
    return fallback;
  }

  ParsedTransaction? parse(
    String text, {
    String? institution,
    String? sender,
    DateTime? receivedAt,
  }) {
    final parser = resolve(institution, sender, text);
    if (parser == null) return null;
    var parsed = parser.parse(text, receivedAt: receivedAt);
    if (parsed == null && fallback != null && !identical(parser, fallback)) {
      // A bank parser that does not recognise the wording must not hide a
      // transaction the generic heuristics can still read.
      parsed = fallback!.parse(text, receivedAt: receivedAt);
      if (parsed != null && parser.institution.isNotEmpty) {
        parsed = parsed.copyWith(institution: parser.institution);
      }
    }
    return parsed;
  }
}

// ---------------------------------------------------------------------------
// The twelve banks. Order matters for text sniffing: specific brands first
// (Emirates Islamic / Liv before Emirates NBD).
// ---------------------------------------------------------------------------

final SmsParser eibParser = SmsParser(
  'eib',
  [
    tpl(
      r'a purchase of {AMT} was made on your emirates islamic (?:credit|debit) card ending {L4} at {M}',
    ),
    tpl(r'{AMT} has been credited to your account ending {L4}', _cr),
  ],
  nameHints: const ['Emirates Islamic'],
);

final SmsParser livParser = SmsParser(
  'liv',
  [
    tpl(r'you spent {AMT} at {M} with (?:your )?(?:\w+ )?card ending {L4}'),
    tpl(r'you received {AMT} from {M}', _cr),
  ],
  nameHints: const ['Liv.'],
);

final SmsParser enbdParser = SmsParser(
  'enbd',
  [
    tpl(r'purchase of {AMT} with (?:credit|debit) card ending {L4} at {M}'),
    tpl(r'(?:credit|debit) card ending {L4} was used for {AMT} at {M}'),
    tpl(r'{AMT} has been credited to your account ending {L4}', _cr),
  ],
  nameHints: const ['Emirates NBD', 'ENBD'],
);

final SmsParser adcbParser = SmsParser(
  'adcb',
  [
    tpl(r'card {L4} was used for {AMT} at {M}'),
    tpl(r'purchase {AMT} at {M} using card {L4}'),
    tpl(r'{AMT} credited to your account {L4}', _cr),
  ],
  nameHints: const ['ADCB'],
);

final SmsParser adibParser = SmsParser(
  'adib',
  [
    tpl(r'cr\. card {L4} was used for {AMT} at {M}'),
    tpl(r'purchase transaction of {AMT} on card ending {L4} at {M} was successful'),
    tpl(r'{AMT} deposited (?:in|into) your account {L4}', _cr),
  ],
  nameHints: const ['ADIB', 'Abu Dhabi Islamic Bank'],
);

final SmsParser fabParser = SmsParser(
  'fab',
  [
    tpl(r'card ending {L4} was used for a purchase of {AMT} at {M}'),
    tpl(r'card ending {L4}: {AMT} spent at {M}'),
    tpl(r'account ending {L4} has been credited with {AMT}', _cr),
  ],
  nameHints: const ['FAB', 'First Abu Dhabi Bank'],
);

final SmsParser mashreqParser = SmsParser(
  'mashreq',
  [
    tpl(
      r'{AMT} has been spent on your mashreq (?:credit|debit) card ending {L4} at {M}',
    ),
    tpl(r'{AMT} spent using mashreq (?:credit|debit) card {L4} at {M}'),
    tpl(r'{AMT} is credited to your account {L4}', _cr),
  ],
  nameHints: const ['Mashreq'],
);

final SmsParser rakbankParser = SmsParser(
  'rakbank',
  [
    tpl(r'rakbank (?:credit|debit) card {L4} has been charged {AMT} at {M}'),
    tpl(r'{AMT} has been credited in your (?:a/c|account) {L4}', _cr),
  ],
  nameHints: const ['RAKBANK', 'RAK Bank'],
);

final SmsParser dibParser = SmsParser(
  'dib',
  [
    tpl(r'card no\.? {L4} was used for {AMT} at {M}'),
    tpl(r'account {L4} has been credited with {AMT}', _cr),
  ],
  nameHints: const ['Dubai Islamic Bank', 'DIB'],
);

final SmsParser hsbcParser = SmsParser(
  'hsbc',
  [
    tpl(r'card ending {L4} was used for {AMT} at {M}'),
    tpl(r'{AMT} was spent on your card ending {L4} at {M}'),
    tpl(r'account ending {L4} was credited with {AMT}', _cr),
  ],
  nameHints: const ['HSBC'],
);

final SmsParser citiParser = SmsParser(
  'citi',
  [
    tpl(r'citi (?:credit |debit )?card ending {L4} was charged {AMT} at {M}'),
    tpl(r'payment of {AMT} was credited to your card ending {L4}', _cr),
  ],
  nameHints: const ['Citibank', 'Citi Alert'],
);

final SmsParser cbdParser = SmsParser(
  'cbd',
  [
    tpl(
      r'transaction of {AMT} done on your (?:credit|debit) card ending {L4} at {M}',
    ),
    tpl(r'{AMT} credited to your account ending {L4}', _cr),
  ],
  nameHints: const ['CBD', 'Commercial Bank of Dubai'],
);

/// All bank parsers in sniffing order.
final List<SmsParser> allBankParsers = [
  eibParser,
  livParser,
  enbdParser,
  adcbParser,
  adibParser,
  fabParser,
  mashreqParser,
  rakbankParser,
  dibParser,
  hsbcParser,
  citiParser,
  cbdParser,
];

/// The default registry: twelve banks plus the generic fallback.
ParserRegistry buildDefaultRegistry() {
  final r = ParserRegistry(fallback: GenericParser());
  allBankParsers.forEach(r.register);
  return r;
}

final ParserRegistry defaultParserRegistry = buildDefaultRegistry();
