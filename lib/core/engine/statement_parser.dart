/// On-device port of the backend's line-oriented statement parser
/// (`app/services/parsers/statements/layout.py`): PDF text in, a summary
/// (due date, minimum due, balances) and transaction lines out. Pure Dart.
///
/// Credit card sign convention: balances are amounts OWED (a "Cr" balance is
/// negative) and closing = opening + debits - credits. Bank accounts: balances
/// are funds held and closing = opening + credits - debits.
library;

import 'dates.dart';
import 'types.dart';

enum StatementKind { creditCard, bankAccount }

class Money {
  const Money(this.minor, {this.negative = false, this.marker});
  final int minor; // absolute value
  final bool negative;
  final String? marker; // 'CR' | 'DR'
}

const amountRe =
    r'-?\(?\d{1,3}(?:,\d{3})*(?:\.\d{2})\)?(?:\s?(?:CR|DR|Cr|Dr|cr|dr))?'
    r'|-?\(?\d+\.\d{2}\)?(?:\s?(?:CR|DR|Cr|Dr|cr|dr))?';
final _moneyToken = RegExp(
  r'^(-)?(\()?([\d,]+\.\d{2})\)?(?:\s?(CR|DR))?$',
  caseSensitive: false,
);
final _amountToken = RegExp('^(?:$amountRe)\$');

/// '1,234.50', '(12.00)', '-5.00', '250.00 Cr', 'AED 10.00'.
Money? parseMoney(String token) {
  var t = token.trim().replaceAll('−', '-');
  t = t.replaceFirst(RegExp(r'^(?:AED|Dhs?\.?)\s*', caseSensitive: false), '');
  final m = _moneyToken.firstMatch(t);
  if (m == null) return null;
  final minor = parseMinorUnits(m[3]!);
  if (minor == null) return null;
  return Money(
    minor,
    negative: m[1] != null || m[2] != null,
    marker: m[4]?.toUpperCase(),
  );
}

const _month = r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*';
const lineDate =
    r'(?:\d{4}-\d{2}-\d{2}'
    r'|\d{1,2}[/.\-]\d{1,2}[/.\-](?:\d{4}|\d{2})(?!\d)'
    '|\\d{1,2}[ \\-]$_month[ \\-,]+(?:\\d{4}|\\d{2})(?!\\d))';
final _rowStart = RegExp(
  '^(?<d1>$lineDate)(?:\\s+(?<d2>$lineDate))?\\s+(?<rest>\\S.*)\$',
  caseSensitive: false,
);
const _knownCcy = {
  'AED', 'USD', 'EUR', 'GBP', 'SAR', 'INR', 'PKR', 'QAR', 'KWD', 'BHD', 'OMR',
  'EGP', 'CHF', 'JPY', 'CAD', 'AUD', 'SGD', 'CNY', 'THB', 'TRY', 'LKR', 'PHP',
  'HKD', 'MYR', 'IDR', 'KRW', 'NZD', 'ZAR', //
};
final _openingRow = RegExp(
  r'^(?:opening balance|balance (?:brought forward|b/?f)|previous balance)\b',
  caseSensitive: false,
);
final _closingRow = RegExp(
  r'^(?:closing balance|balance (?:carried forward|c/?f))\b',
  caseSensitive: false,
);
final _creditWords = RegExp(
  r'\b(?:payment received|payment\s*-?\s*thank you|thank you for your payment|'
  r'refund|reversal|cashback|salary|credit interest|deposit)\b',
  caseSensitive: false,
);
final _continuation = RegExp(r"^[A-Za-z0-9][A-Za-z0-9 .,&'*/\-#@()]{1,70}$");
final _noise = RegExp(
  r'\b(?:page\s+\d+|statement|total|balance|limit|minimum|payment due|due date|'
  r'date|description|amount|transaction|summary|reward|points|customer|please|'
  r'account|iban|swift|vat|trn)\b',
  caseSensitive: false,
);
final _cardNum = RegExp(
  r'(?:card\s*(?:no\.?|number|#)?|credit card)[:\s]*([\dXx*•\- ]{12,25})',
  caseSensitive: false,
);
final _acctNum = RegExp(
  r'(?:account\s*(?:no\.?|number|#)|a/c\s*(?:no\.?)?)[:\s]*([\dXx*\-]{6,30})',
  caseSensitive: false,
);
final _iban = RegExp(
  r'\bIBAN[:\s]*(AE\d{2}(?:\s?\d{4}){4}\s?\d{3})',
  caseSensitive: false,
);
final _ccyLabel = RegExp(
  r'(?:account |statement )?currency[:\s]+([A-Z]{3})\b',
  caseSensitive: false,
);
final _period = RegExp(
  r'(?:statement\s+period|period|from)[:\s]*'
  '(?<a>$lineDate)\\s*(?:to|-|–|through|till)\\s*(?<b>$lineDate)',
  caseSensitive: false,
);

class Labels {
  const Labels({
    this.opening = const [
      r'previous (?:statement )?balance',
      r'opening balance',
      r'balance brought forward',
    ],
    this.closing = const [
      r'total amount due',
      r'closing balance',
      r'new balance',
      r'statement balance',
      r'total outstanding(?: balance)?',
      r'balance carried forward',
    ],
    this.minDue = const [
      r'minimum (?:payment|amount)(?: due)?',
      r'min\.? (?:payment|amount)(?: due)?',
    ],
    this.dueDate = const [r'payment due date', r'due date', r'pay(?:ment)? by'],
    this.statementDate = const [
      r'statement date',
      r'statement closing date',
      r'closing date',
    ],
    this.payments = const [
      r'payments?(?: (?:and|&|/) credits?)?',
      r'total credits?',
    ],
    this.purchases = const [
      r'purchases?(?: (?:and|&|/) (?:charges|debits|cash advances?))?',
      r'total debits?',
      r'new charges',
    ],
  });
  final List<String> opening,
      closing,
      minDue,
      dueDate,
      statementDate,
      payments,
      purchases;
}

class Layout {
  const Layout({
    this.labels = const Labels(),
    this.useSecondDate = false,
    this.foreignBeforeLocal = true,
    this.hasBalanceColumn = true,
    this.negativeIsCredit = true,
    this.inferCreditFromText = true,
    this.summaryTable = false,
    this.extraNoise = const [],
  });
  final Labels labels;
  final bool useSecondDate, foreignBeforeLocal, hasBalanceColumn;
  final bool negativeIsCredit, inferCreditFromText, summaryTable;
  final List<String> extraNoise;
}

class StatementLine {
  const StatementLine({
    required this.postedOn,
    required this.description,
    required this.amountMinor,
    required this.direction,
    this.foreignAmountMinor,
    this.foreignCurrency,
    this.balanceMinor,
  });
  final CalDate postedOn;
  final String description;
  final int amountMinor; // positive
  final Direction direction;
  final int? foreignAmountMinor;
  final String? foreignCurrency;
  final int? balanceMinor;

  StatementLine withDescription(String d) => StatementLine(
    postedOn: postedOn,
    description: d,
    amountMinor: amountMinor,
    direction: direction,
    foreignAmountMinor: foreignAmountMinor,
    foreignCurrency: foreignCurrency,
    balanceMinor: balanceMinor,
  );
}

class ParsedStatement {
  ParsedStatement(this.kind);
  final StatementKind kind;
  String? institution;
  String currency = 'AED';
  CalDate? periodStart, periodEnd, statementDate, dueDate;
  int? openingMinor, closingMinor, minDueMinor;
  int? totalPaymentsMinor, totalPurchasesMinor;
  String? last4;
  final lines = <StatementLine>[];
  final warnings = <String>[];
  String parser = '';
}

StatementKind detectKind(String text) =>
    RegExp(
      r'credit card statement|card number|minimum (?:payment|amount)|'
      r'payment due date|credit limit',
      caseSensitive: false,
    ).hasMatch(text)
    ? StatementKind.creditCard
    : StatementKind.bankAccount;

String? _last4(String num) {
  final tail = num.length > 8 ? num.substring(num.length - 8) : num;
  final digits = tail.replaceAll(RegExp(r'\D'), '');
  return digits.length >= 4 ? digits.substring(digits.length - 4) : null;
}

RegExp _labelRe(List<String> alts) => RegExp(
  '(?<![A-Za-z])(?:${alts.join('|')})(?![A-Za-z])',
  caseSensitive: false,
);

/// Splits trailing money tokens off a row: (leading text, tokens, foreign ccy).
(String, List<String>, String?) _moneyTokens(
  String rest, {
  bool foreignAfter = false,
}) {
  final parts = rest.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  final tokens = <String>[];
  var i = parts.length;
  while (i > 0 && tokens.length < 4) {
    final tok = parts[i - 1];
    final up = tok.toUpperCase();
    if ((up == 'CR' || up == 'DR') &&
        i >= 2 &&
        _amountToken.hasMatch(parts[i - 2])) {
      tokens.add('${parts[i - 2]} $up');
      i -= 2;
      continue;
    }
    if (_amountToken.hasMatch(tok)) {
      tokens.add(tok);
      i -= 1;
      continue;
    }
    break;
  }
  String? ccy;
  if (foreignAfter &&
      tokens.length == 1 &&
      i >= 2 &&
      _knownCcy.contains(parts[i - 1]) &&
      _amountToken.hasMatch(parts[i - 2])) {
    ccy = parts[i - 1];
    tokens.add(parts[i - 2]);
    i -= 2;
  }
  return (parts.sublist(0, i).join(' '), tokens.reversed.toList(), ccy);
}

(StatementLine?, String?) _rowToLine(
  CalDate d1,
  CalDate? d2,
  String desc,
  List<String> tokens,
  String? ccyHint,
  StatementKind kind,
  Layout layout,
  int? prevBalance,
) {
  final posted = layout.useSecondDate && d2 != null ? d2 : d1;
  var money = [
    for (final t in tokens)
      if (parseMoney(t) case final m?) m,
  ];
  if (money.isEmpty) return (null, 'row without amount');
  int? balance;
  if (kind == StatementKind.bankAccount &&
      layout.hasBalanceColumn &&
      money.length >= 2) {
    final bal = money.last;
    balance = (bal.marker == 'DR' || bal.negative) ? -bal.minor : bal.minor;
    money = money.sublist(0, money.length - 1);
  }
  int? foreignAmt;
  String? foreignCcy;
  final words = desc.split(' ');
  if (money.length >= 2) {
    final foreign = layout.foreignBeforeLocal
        ? money[money.length - 2]
        : money.last;
    final local = layout.foreignBeforeLocal
        ? money.last
        : money[money.length - 2];
    money = [local];
    foreignAmt = foreign.minor;
    foreignCcy = ccyHint;
    if (foreignCcy == null &&
        words.isNotEmpty &&
        _knownCcy.contains(words.last)) {
      foreignCcy = words.removeLast();
    }
    desc = words.join(' ');
  }
  final amt = money.first;
  if (amt.minor == 0) return (null, 'zero amount');

  Direction? direction;
  String? note;
  if (balance != null && prevBalance != null) {
    final delta = balance - prevBalance;
    if (delta.abs() == amt.minor) {
      direction = delta > 0 ? Direction.credit : Direction.debit;
    } else {
      note = 'running balance does not match amount';
    }
  }
  if (direction == null) {
    if (amt.marker == 'CR') {
      direction = Direction.credit;
    } else if (amt.marker == 'DR') {
      direction = Direction.debit;
    } else if (kind == StatementKind.creditCard &&
        layout.negativeIsCredit &&
        amt.negative) {
      direction = Direction.credit;
    } else if (kind == StatementKind.bankAccount && amt.negative) {
      direction = Direction.debit;
    } else if (layout.inferCreditFromText && _creditWords.hasMatch(desc)) {
      direction = Direction.credit;
    } else {
      direction = Direction.debit;
      if (kind == StatementKind.bankAccount) note ??= 'direction assumed debit';
    }
  }
  return (
    StatementLine(
      postedOn: posted,
      description: desc.trim(),
      amountMinor: amt.minor,
      direction: direction,
      foreignAmountMinor: foreignAmt,
      foreignCurrency: foreignCcy,
      balanceMinor: balance,
    ),
    note,
  );
}

String _clip(String s, [int n = 60]) => s.length > n ? s.substring(0, n) : s;

ParsedStatement parseStatementText(
  String text,
  StatementKind kind,
  Layout layout,
) {
  final stmt = ParsedStatement(kind);
  final lines = [
    for (final ln in text.split('\n'))
      if (ln.replaceAll(RegExp(r'[ \t ]+'), ' ').trim() case final c
          when c.isNotEmpty)
        c,
  ];
  _extractSummary(lines, stmt, layout);
  final extraNoise = [
    for (final p in layout.extraNoise) RegExp(p, caseSensitive: false),
  ];
  var prevBalance = kind == StatementKind.bankAccount
      ? stmt.openingMinor
      : null;
  var canContinue = false;
  for (final ln in lines) {
    final m = _rowStart.firstMatch(ln);
    if (m == null) {
      if (canContinue &&
          _continuation.hasMatch(ln) &&
          !_noise.hasMatch(ln) &&
          !extraNoise.any((p) => p.hasMatch(ln)) &&
          _moneyTokens(ln).$2.isEmpty &&
          stmt.lines.last.description.length < 90) {
        final prev = stmt.lines.last;
        stmt.lines[stmt.lines.length - 1] = prev.withDescription(
          '${prev.description} $ln',
        );
      } else {
        canContinue = false;
      }
      continue;
    }
    canContinue = false;
    final d1 = parseDate(m.namedGroup('d1')!);
    final d2s = m.namedGroup('d2');
    final d2 = d2s == null ? null : parseDate(d2s);
    if (d1 == null) continue;
    final (desc, tokens, ccyHint) = _moneyTokens(
      m.namedGroup('rest')!,
      foreignAfter:
          !layout.foreignBeforeLocal && kind == StatementKind.creditCard,
    );
    if (tokens.isEmpty || extraNoise.any((p) => p.hasMatch(ln))) continue;
    if (_openingRow.hasMatch(desc) || _closingRow.hasMatch(desc)) {
      final value = parseMoney(tokens.last);
      if (value != null) {
        final signed = kind == StatementKind.bankAccount
            ? ((value.marker == 'DR' || value.negative)
                  ? -value.minor
                  : value.minor)
            : (value.marker == 'CR' ? -value.minor : value.minor);
        if (_openingRow.hasMatch(desc) && stmt.openingMinor == null) {
          stmt.openingMinor = signed;
          if (kind == StatementKind.bankAccount) prevBalance = signed;
        } else if (_closingRow.hasMatch(desc) && stmt.closingMinor == null) {
          stmt.closingMinor = signed;
        }
      }
      continue;
    }
    final (line, note) = _rowToLine(
      d1,
      d2,
      desc,
      tokens,
      ccyHint,
      kind,
      layout,
      prevBalance,
    );
    if (line == null) {
      if (note != null && note != 'zero amount') {
        stmt.warnings.add('skipped row: ${_clip(ln)} ($note)');
      }
      continue;
    }
    if (note != null) stmt.warnings.add('$note: ${_clip(ln)}');
    stmt.lines.add(line);
    canContinue = true;
    if (line.balanceMinor != null) {
      prevBalance = line.balanceMinor;
    } else if (kind == StatementKind.bankAccount) {
      prevBalance = null;
    }
  }
  _finish(stmt);
  return stmt;
}

int? _firstMoney(String line, int after) {
  for (final m in RegExp(amountRe).allMatches(line.substring(after))) {
    final money = parseMoney(m[0]!);
    if (money != null) {
      return (money.negative || money.marker == 'CR')
          ? -money.minor
          : money.minor;
    }
  }
  return null;
}

int _balance(int value, String line, StatementKind kind) {
  if (kind == StatementKind.creditCard) return value;
  return RegExp(r'\bDR\b|-\s?\d', caseSensitive: false).hasMatch(line)
      ? -value.abs()
      : value.abs();
}

void _extractSummary(List<String> lines, ParsedStatement stmt, Layout layout) {
  final l = layout.labels;
  final kind = stmt.kind;
  final patterns = {
    'opening': _labelRe(l.opening),
    'closing': _labelRe(l.closing),
    'min_due': _labelRe(l.minDue),
    'payments': _labelRe(l.payments),
    'purchases': _labelRe(l.purchases),
  };
  final dueRe = _labelRe(l.dueDate), stmtDateRe = _labelRe(l.statementDate);
  final dateFind = RegExp(lineDate, caseSensitive: false);
  for (final ln in lines) {
    if (_rowStart.hasMatch(ln)) continue;
    final cc = _ccyLabel.firstMatch(ln);
    if (cc != null) stmt.currency = cc[1]!.toUpperCase();
    if (stmt.last4 == null) {
      if (kind == StatementKind.creditCard) {
        final cm = _cardNum.firstMatch(ln);
        if (cm != null) stmt.last4 = _last4(cm[1]!.trim());
      } else {
        final im = _iban.firstMatch(ln);
        if (im != null) {
          stmt.last4 = _last4(im[1]!.replaceAll(' ', ''));
        } else if (_acctNum.firstMatch(ln) case final am?) {
          stmt.last4 = _last4(am[1]!);
        }
      }
    }
    if (stmt.periodStart == null) {
      final pm = _period.firstMatch(ln);
      if (pm != null) {
        stmt.periodStart = parseDate(pm.namedGroup('a')!);
        stmt.periodEnd = parseDate(pm.namedGroup('b')!);
      }
    }
    var dueLine = false;
    for (final (rx, target) in [(dueRe, 'due'), (stmtDateRe, 'stmt')]) {
      final mm = rx.firstMatch(ln);
      if (mm == null) continue;
      dueLine = true;
      final dm = dateFind.firstMatch(ln.substring(mm.end));
      final d = dm == null ? null : parseDate(dm[0]!);
      if (d == null) continue;
      if (target == 'due') stmt.dueDate ??= d;
      if (target == 'stmt') stmt.statementDate ??= d;
    }
    if (dueLine) continue;
    for (final name in [
      'min_due',
      'opening',
      'closing',
      'purchases',
      'payments',
    ]) {
      final mm = patterns[name]!.firstMatch(ln);
      if (mm == null) continue;
      final value = _firstMoney(ln, mm.end);
      if (value == null) continue;
      switch (name) {
        case 'opening':
          stmt.openingMinor ??= _balance(value, ln, kind);
        case 'closing':
          stmt.closingMinor ??= _balance(value, ln, kind);
        case 'min_due':
          stmt.minDueMinor ??= value.abs();
        case 'payments':
          if (kind == StatementKind.creditCard) {
            stmt.totalPaymentsMinor ??= value.abs();
          }
        case 'purchases':
          if (kind == StatementKind.creditCard) {
            stmt.totalPurchasesMinor ??= value.abs();
          }
      }
      break;
    }
  }
  if (layout.summaryTable) _extractSummaryTable(lines, stmt, layout);
}

void _extractSummaryTable(
  List<String> lines,
  ParsedStatement stmt,
  Layout layout,
) {
  final order = [
    ('opening', layout.labels.opening),
    ('payments', layout.labels.payments),
    ('purchases', layout.labels.purchases),
    ('closing', layout.labels.closing),
    ('min_due', layout.labels.minDue),
  ];
  for (var i = 0; i < lines.length - 1; i++) {
    final hits = <(int, String)>[];
    for (final (name, alts) in order) {
      final m = _labelRe(alts).firstMatch(lines[i]);
      if (m != null) hits.add((m.start, name));
    }
    hits.sort((a, b) => a.$1.compareTo(b.$1));
    if (hits.length < 3) continue;
    final values = [
      for (final t in RegExp(amountRe).allMatches(lines[i + 1]))
        if (parseMoney(t[0]!) case final m?) m,
    ];
    if (values.length != hits.length) continue;
    for (var k = 0; k < hits.length; k++) {
      final money = values[k];
      final signed = money.marker == 'CR' ? -money.minor : money.minor;
      switch (hits[k].$2) {
        case 'opening':
          stmt.openingMinor ??= signed;
        case 'closing':
          stmt.closingMinor ??= signed;
        case 'min_due':
          stmt.minDueMinor ??= money.minor;
        case 'payments':
          stmt.totalPaymentsMinor ??= money.minor;
        case 'purchases':
          stmt.totalPurchasesMinor ??= money.minor;
      }
    }
    return;
  }
}

void _finish(ParsedStatement stmt) {
  final dates = [for (final l in stmt.lines) l.postedOn]..sort();
  stmt.periodEnd ??= stmt.statementDate ?? (dates.isEmpty ? null : dates.last);
  if (stmt.periodStart == null && dates.isNotEmpty) {
    stmt.periodStart = dates.first;
  }
  final s = stmt.periodStart, e = stmt.periodEnd;
  if (s != null && e != null && s > e) {
    stmt.periodStart = e;
    stmt.periodEnd = s;
  }
  if (dates.isNotEmpty &&
      stmt.periodEnd != null &&
      dates.last > stmt.periodEnd!) {
    stmt.warnings.add('transactions dated after the statement period end');
  }
}

/// Per-bank layouts, mirroring the backend modules.
const _generic = Layout(hasBalanceColumn: false);
final _cardLayouts = <String, Layout>{
  'enbd': const Layout(hasBalanceColumn: false),
  'adcb': const Layout(hasBalanceColumn: false, summaryTable: true),
  'fab': const Layout(hasBalanceColumn: false, useSecondDate: true),
  'hsbc': const Layout(
    hasBalanceColumn: false,
    labels: Labels(
      closing: [r'statement balance', r'total amount due', r'closing balance'],
    ),
  ),
  'citi': const Layout(
    hasBalanceColumn: false,
    labels: Labels(
      closing: [r'new balance', r'total amount due', r'closing balance'],
    ),
  ),
  'mashreq': const Layout(
    hasBalanceColumn: false,
    labels: Labels(
      closing: [r'statement balance', r'total amount due', r'closing balance'],
    ),
  ),
  'rakbank': const Layout(hasBalanceColumn: false, foreignBeforeLocal: false),
};
final _accountLayouts = <String, Layout>{
  'enbd': const Layout(
    labels: Labels(opening: [r'opening balance', r'balance brought forward']),
  ),
};

/// Parses statement text for [institution] (null = generic layout). Returns
/// null when no transaction lines were found.
ParsedStatement? parseStatement(
  String text, {
  String? institution,
  StatementKind? kind,
}) {
  final k = kind ?? detectKind(text);
  final layout = k == StatementKind.creditCard
      ? (_cardLayouts[institution] ?? _generic)
      : (_accountLayouts[institution] ?? const Layout());
  final stmt = parseStatementText(text, k, layout);
  stmt.institution = institution;
  stmt.parser =
      '${institution ?? 'generic'}:${k == StatementKind.creditCard ? 'credit_card' : 'bank_account'}';
  return stmt.lines.isEmpty ? null : stmt;
}
