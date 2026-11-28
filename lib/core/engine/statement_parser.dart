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
final _rowStartYearless = RegExp(
  r'^(?<d1>\d{1,2}/\d{1,2})(?:\s+(?<d2>\d{1,2}/\d{1,2}))?\s+(?<rest>\S.*)$',
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
    this.yearlessDates = false,
    this.trailingMinusIsCredit = false,
    this.collapseDuplicateAmounts = false,
  });
  final Labels labels;
  final bool useSecondDate, foreignBeforeLocal, hasBalanceColumn;
  final bool negativeIsCredit, inferCreditFromText, summaryTable;
  final List<String> extraNoise;

  /// Rows start with `dd/mm` (no year); the year comes from the statement date.
  final bool yearlessDates;

  /// "44.00 -" after the amount marks a credit.
  final bool trailingMinusIsCredit;

  /// "AED 40.89 40.89": the amount is printed twice (original and AED).
  final bool collapseDuplicateAmounts;

  /// The same layout with the options real Mashreq and Sharjah Islamic card
  /// PDFs need, tried when nothing was found with the standard row format.
  Layout asYearless() => Layout(
    labels: labels,
    useSecondDate: useSecondDate,
    foreignBeforeLocal: foreignBeforeLocal,
    hasBalanceColumn: hasBalanceColumn,
    negativeIsCredit: negativeIsCredit,
    inferCreditFromText: inferCreditFromText,
    summaryTable: summaryTable,
    extraNoise: extraNoise,
    yearlessDates: true,
    trailingMinusIsCredit: true,
    collapseDuplicateAmounts: true,
  );
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

  /// The card's credit limit, when the statement prints it.
  int? creditLimitMinor;
  String? last4;
  final lines = <StatementLine>[];
  final warnings = <String>[];
  String parser = '';
}

StatementKind detectKind(String text) =>
    RegExp(
      r'credit card statement|card number|minimum (?:payment|amount)|'
      r'payment due date|credit limit|main card|\b\d{4,6}[ ]?x{4,}[ x]*\d{4}\b',
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
  bool trailingMinus = false,
}) {
  final parts = rest.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  final tokens = <String>[];
  var i = parts.length;
  while (i > 0 && tokens.length < 4) {
    final tok = parts[i - 1];
    final up = tok.toUpperCase();
    if (trailingMinus &&
        tok == '-' &&
        tokens.isEmpty &&
        i >= 2 &&
        _amountToken.hasMatch(parts[i - 2])) {
      tokens.add('${parts[i - 2]} CR');
      i -= 2;
      continue;
    }
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
  var money = [for (final t in tokens) ?parseMoney(t)];
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
  if (layout.collapseDuplicateAmounts &&
      money.length >= 2 &&
      money.last.minor == money[money.length - 2].minor) {
    money = [money.last];
    if (words.isNotEmpty && words.last == 'AED') {
      words.removeLast();
      desc = words.join(' ');
    }
  }
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
  final rowStart = layout.yearlessDates ? _rowStartYearless : _rowStart;
  final refDate = stmt.statementDate ?? stmt.periodEnd;
  CalDate? rowDate(String? v) {
    if (v == null) return null;
    if (!layout.yearlessDates) return parseDate(v);
    if (refDate == null) return null;
    final parts = v.split('/');
    final day = int.parse(parts[0]), month = int.parse(parts[1]);
    var d = parseDate('$day/$month/${refDate.year}');
    if (d != null && d > refDate)
      d = parseDate('$day/$month/${refDate.year - 1}');
    return d;
  }

  final extraNoise = [
    for (final p in layout.extraNoise) RegExp(p, caseSensitive: false),
  ];
  var prevBalance = kind == StatementKind.bankAccount
      ? stmt.openingMinor
      : null;
  var canContinue = false;
  for (final ln in lines) {
    final m = rowStart.firstMatch(ln);
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
    final d1 = rowDate(m.namedGroup('d1'));
    final d2 = rowDate(m.namedGroup('d2'));
    if (d1 == null) continue;
    final (desc, tokens, ccyHint) = _moneyTokens(
      m.namedGroup('rest')!,
      foreignAfter:
          !layout.foreignBeforeLocal && kind == StatementKind.creditCard,
      trailingMinus: layout.trailingMinusIsCredit,
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

final _limitLabel = RegExp(
  r'(?:total\s+)?credit\s+limit',
  caseSensitive: false,
);

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
    if (_rowStart.hasMatch(ln) ||
        (layout.yearlessDates && _rowStartYearless.hasMatch(ln))) {
      continue;
    }
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
    if (kind == StatementKind.creditCard && stmt.creditLimitMinor == null) {
      final lm = _limitLabel.firstMatch(ln);
      final lv = lm == null ? null : _firstMoney(ln, lm.end);
      if (lv != null && lv > 0) stmt.creditLimitMinor = lv;
    }
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
  // Shapes seen in real statements whose labels are not on the same line as
  // their values. They only fire on that exact shape, so every layout runs them.
  _enbdSummary(lines, stmt);
  _sibSummary(lines, stmt);
  _fabDates(lines, stmt);
}

final _valueToken = RegExp('$lineDate|[\\d,]+\\.\\d{2}|\\d+');
final _plainMoney = RegExp(r'^-?[\d,]+\.\d{2}$');

/// Emirates NBD cards print a row of labels and, on the next line, the values:
/// "Credit Limit ... Statement Date  Payment Due Date  Minimum Payment Due"
/// then "19500 15,878.69 28/10/2026 22/11/2026 180.44"; and a second table
/// "Previous Statement Due | Purchase / Cash Advance | Interest/Other Charges |
/// Payments/Credits | Total Payment Due | Current Balance" with six amounts.
void _enbdSummary(List<String> lines, ParsedStatement stmt) {
  final dueRow = RegExp(
    r'statement date.*payment due date.*minimum payment due',
    caseSensitive: false,
  );
  final balRow = RegExp(
    r'total payment due.*current balance',
    caseSensitive: false,
  );
  for (var i = 0; i < lines.length - 1; i++) {
    if (dueRow.hasMatch(lines[i])) {
      final tokens = [
        for (final m in _valueToken.allMatches(lines[i + 1])) m[0]!,
      ];
      if (tokens.length >= 3) {
        final t = tokens.sublist(tokens.length - 3);
        final stmtDate = parseDate(t[0]), due = parseDate(t[1]);
        final min = _plainMoney.hasMatch(t[2]) ? parseMinorUnits(t[2]) : null;
        if (stmtDate != null && due != null && min != null) {
          stmt.statementDate ??= stmtDate;
          stmt.dueDate ??= due;
          stmt.minDueMinor ??= min;
        }
      }
    }
    if (balRow.hasMatch(lines[i])) {
      for (var j = i + 1; j <= i + 3 && j < lines.length; j++) {
        final t = lines[j].split(RegExp(r'\s+'));
        if (t.length == 6 && t.every(_plainMoney.hasMatch)) {
          final v = [for (final x in t) parseMinorUnits(x)!];
          // opening, purchases, charges, payments, closing, current balance
          stmt.openingMinor ??= v[0];
          stmt.totalPurchasesMinor ??= v[1];
          stmt.totalPaymentsMinor ??= v[3];
          stmt.closingMinor ??= v[4];
          break;
        }
      }
    }
  }
}

/// Sharjah Islamic Bank cards print the summary as two unlabelled rows:
/// "14/NOV/2026 510299XXXXXX1234 -100.00 30/NOV/2026 10,000.00"
/// (statement date, card, minimum due, payment due date, limit) and
/// "-4,449.26 -2,113.66 -360.63 5,417.63 -1,505.92" (previous balance,
/// purchases, charges, payments, closing). Negative means owed.
void _sibSummary(List<String> lines, ParsedStatement stmt) {
  final head = RegExp(
    r'^(\d{1,2}/[A-Za-z]{3}/\d{4})\s+(\d{4,6}X+\d{4})\s+(-?[\d,]+\.\d{2})\s+'
    r'(\d{1,2}/[A-Za-z]{3}/\d{4})\s+([\d,]+\.\d{2})$',
    caseSensitive: false,
  );
  for (var i = 0; i < lines.length - 1; i++) {
    final m = head.firstMatch(lines[i]);
    if (m == null) continue;
    final next = lines[i + 1].split(RegExp(r'\s+'));
    if (next.length != 5 || !next.every(_plainMoney.hasMatch)) continue;
    CalDate? d(String v) => parseDate(v.replaceAll('/', '-'));
    stmt.statementDate ??= d(m[1]!);
    stmt.dueDate ??= d(m[4]!);
    stmt.last4 ??= _last4(m[2]!);
    stmt.minDueMinor ??= parseMinorUnits(m[3]!.replaceAll('-', ''));
    stmt.creditLimitMinor ??= parseMinorUnits(m[5]!);
    int owed(String v) =>
        -parseMinorUnits(v.replaceAll('-', ''))! * (v.startsWith('-') ? -1 : 1);
    stmt.openingMinor ??= owed(next[0]);
    stmt.totalPurchasesMinor ??= parseMinorUnits(next[1].replaceAll('-', ''));
    stmt.totalPaymentsMinor ??= parseMinorUnits(next[3].replaceAll('-', ''));
    stmt.closingMinor ??= owed(next[4]);
    return;
  }
}

/// Dubai First (FAB) cards: "CREDIT 22-Oct-2026 16-Nov-2026" (statement date,
/// payment due date); the labels are not extractable from the PDF.
void _fabDates(List<String> lines, ParsedStatement stmt) {
  final re = RegExp(
    r'^CREDIT\s+(\d{1,2}-[A-Za-z]{3}-\d{4})\s+(\d{1,2}-[A-Za-z]{3}-\d{4})$',
  );
  for (final ln in lines) {
    final m = re.firstMatch(ln);
    if (m == null) continue;
    stmt.statementDate ??= parseDate(m[1]!);
    stmt.dueDate ??= parseDate(m[2]!);
    return;
  }
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
        ?parseMoney(t[0]!),
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
      closing: [
        r'statement balance',
        r'total amount due',
        r'total outstanding balance',
        r'closing balance',
      ],
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
  var stmt = parseStatementText(text, k, layout);
  if (stmt.lines.isEmpty && k == StatementKind.creditCard) {
    // Real Mashreq and Sharjah Islamic cards print rows as "dd/mm dd/mm ...".
    final retry = parseStatementText(text, k, layout.asYearless());
    if (retry.lines.isNotEmpty) stmt = retry;
  }
  stmt.institution = institution;
  stmt.parser =
      '${institution ?? 'generic'}:${k == StatementKind.creditCard ? 'credit_card' : 'bank_account'}';
  return stmt.lines.isEmpty ? null : stmt;
}
