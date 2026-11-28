/// Receipt email parsers (HTML or text). Pure Dart.
///
/// Verification status, per merchant:
///  * noon: written against five anonymised REAL emails (food order
///    accepted x2, order confirmed, supermall order confirmed, shipment
///    delivered). Other noon layouts (returns, partial shipments) are unseen.
///  * Talabat and Careem: NO real email was available. Their parsers target
///    SYNTHETIC fixtures that imitate typical receipt structure; the real
///    layouts are UNVERIFIED and results are flagged `verified: false`.
///  * generic: a best-effort label/amount reader for any other merchant.
library;

import 'receipt_models.dart';

// ---- text preparation ---------------------------------------------------------

/// HTML to one trimmed line per element. Scripts and styles are dropped.
List<String> htmlToLines(String html) {
  var s = html
      .replaceAll(
        RegExp(
          r'<(script|style)[^>]*>.*?</\1>',
          caseSensitive: false,
          dotAll: true,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), ' ')
      .replaceAll(
        RegExp(
          r'<\s*(br|/p|/div|/tr|/li|/h\d|/table|/td|/th)\b[^>]*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<[^>]+>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&rsquo;', "'")
      .replaceAll('&#x20AC;', '€');
  return _lines(s);
}

List<String> _lines(String s) => [
  for (final l in s.split(RegExp(r'\r?\n')))
    if (l.replaceAll(RegExp(r'\s+'), ' ').trim().isNotEmpty)
      l.replaceAll(RegExp(r'\s+'), ' ').trim(),
];

List<String> _bodyLines(ReceiptMessage m) =>
    m.isHtml ||
        RegExp(
          r'<(html|body|div|table)\b',
          caseSensitive: false,
        ).hasMatch(m.body)
    ? htmlToLines(m.body)
    : _lines(m.body);

// ---- amounts ------------------------------------------------------------------

final _amountCore =
    r'(-?\s*[\d]{1,3}(?:,\d{3})*(?:\.\d{1,2})?|-?\s*\d+(?:\.\d{1,2})?)';
final _cur = r'(AED|USD|EUR|GBP|SAR|Dhs?\.?)';
final _amountOnly = RegExp(
  '^(?:-\\s*)?(?:$_cur\\s*)?$_amountCore(?:\\s*$_cur)?\$',
  caseSensitive: false,
);
final _inline = RegExp(
  '^(.*?)[:\\s]+((?:-\\s*)?$_cur\\s*$_amountCore|$_amountCore\\s*$_cur)\$',
  caseSensitive: false,
);

/// fils from "1,200.50", or null.
int? _minor(String raw) {
  final neg = raw.contains('-');
  final t = raw.replaceAll(RegExp(r'[^\d.]'), '');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null) return null;
  final m = (v * 100).round();
  return neg ? -m : m;
}

String _curOf(String s) {
  final m = RegExp(_cur, caseSensitive: false).firstMatch(s);
  if (m == null) return 'AED';
  final c = m.group(1)!.toUpperCase();
  return c.startsWith('DH') ? 'AED' : c;
}

class _Pair {
  _Pair(this.label, this.minor, this.line, this.currency);
  final String label;
  final int minor; // negative when shown with a minus sign
  final int line; // index of the label line
  final String currency;
}

/// Label/amount pairs, either on one line ("Delivery fee AED 5.00") or label
/// on one line and amount on the next. "FREE" reads as zero.
List<_Pair> _pairs(List<String> lines) {
  final out = <_Pair>[];
  var i = 0;
  while (i < lines.length) {
    final l = lines[i];
    final inl = _inline.firstMatch(l);
    if (inl != null &&
        inl.group(1)!.trim().isNotEmpty &&
        RegExp(r'[A-Za-z]').hasMatch(inl.group(1)!)) {
      final amt = _minor(inl.group(2)!);
      if (amt != null) {
        out.add(
          _Pair(
            inl.group(1)!.trim().replaceAll(RegExp(r'[:\-\s]+$'), ''),
            amt,
            i,
            _curOf(l),
          ),
        );
        i++;
        continue;
      }
    }
    if (i + 1 < lines.length &&
        RegExp(r'[A-Za-z]').hasMatch(l) &&
        !_amountOnly.hasMatch(l)) {
      final n = lines[i + 1].trim();
      if (n.toUpperCase() == 'FREE') {
        out.add(_Pair(l, 0, i, 'AED'));
        i += 2;
        continue;
      }
      // The next line must be a currency-marked amount, so a plain number
      // such as an order number is never read as money.
      if (RegExp(_cur, caseSensitive: false).hasMatch(n) &&
          _amountOnly.hasMatch(n)) {
        final amt = _minor(n);
        if (amt != null) {
          out.add(_Pair(l, amt, i, _curOf(n)));
          i += 2;
          continue;
        }
      }
    }
    i++;
  }
  return out;
}

// ---- shared extraction --------------------------------------------------------

final _last4 = RegExp(
  r'(?:ending(?:\s+in|\s+with)?|ends\s+with|last\s*4(?:\s+digits)?(?:\s+of)?|[•*·]{2,}|x{2,})\s*:?\s*(\d{4})\b',
  caseSensitive: false,
);

String? _findLast4(List<String> lines) {
  for (final l in lines) {
    final m = _last4.firstMatch(l);
    if (m != null) return m.group(1);
  }
  return null;
}

final _orderRe = RegExp(
  r'order(?:\s+(?:number|no\.?|id|ref(?:erence)?))?\s*[#:,]?\s*#?\s*((?=[A-Z0-9-]*\d)[A-Z0-9][A-Z0-9-]{3,})',
  caseSensitive: false,
);

String? _findOrderId(Iterable<String> texts) {
  for (final t in texts) {
    final m = _orderRe.firstMatch(t);
    if (m != null)
      return m.group(1)!.toUpperCase().replaceAll(RegExp(r'-$'), '');
  }
  return null;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12, //
};

/// "12 Mar 2026, 19:42" or "12 March 2026 7:42 PM" in a labelled line.
DateTime? _findWhen(List<String> lines) {
  final re = RegExp(
    r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?,?\s+(\d{4})(?:[,\sat]+(\d{1,2}):(\d{2})\s*(AM|PM)?)?',
    caseSensitive: false,
  );
  for (final l in lines) {
    if (!RegExp(
      r'date|placed|ordered|delivered on|time',
      caseSensitive: false,
    ).hasMatch(l))
      continue;
    final m = re.firstMatch(l);
    if (m == null) continue;
    final mon = _months[m.group(2)!.toLowerCase()];
    if (mon == null) continue;
    var h = int.tryParse(m.group(4) ?? '') ?? 12;
    final min = int.tryParse(m.group(5) ?? '') ?? 0;
    final ap = m.group(6)?.toUpperCase();
    if (ap == 'PM' && h < 12) h += 12;
    if (ap == 'AM' && h == 12) h = 0;
    return DateTime(
      int.parse(m.group(3)!),
      mon,
      int.parse(m.group(1)!),
      h,
      min,
    );
  }
  return null;
}

final _itemRe = RegExp(r'^(\d{1,2})\s*[x×]\s+(.+)$', caseSensitive: false);

/// Classifies pairs into total, subtotal, fees, discounts, cashback, items.
class _Sorted {
  int? total, subtotal, cashback;
  String currency = 'AED';
  final fees = <ReceiptLine>[];
  final discounts = <ReceiptLine>[];
  final items = <ReceiptItem>[];
}

_Sorted _sort(List<String> lines) {
  final r = _Sorted();
  for (final p in _pairs(lines)) {
    final label = p.label;
    final low = label.toLowerCase();
    final item = _itemRe.firstMatch(label);
    if (item != null) {
      r.items.add(
        ReceiptItem(
          item.group(2)!.trim(),
          quantity: int.parse(item.group(1)!),
          priceMinor: p.minor.abs(),
        ),
      );
      continue;
    }
    // A card line followed by "cashback" text is a reward, never a charge.
    if (RegExp(r'\b(visa|mastercard|master card|amex|card)\b').hasMatch(low) &&
        !low.startsWith('total')) {
      final next = lines.skip(p.line + 1).take(4).join(' ').toLowerCase();
      if (next.contains('cashback') || low.contains('cashback')) {
        r.cashback ??= p.minor.abs();
      }
      continue;
    }
    if (low.contains('cashback')) {
      r.cashback ??= p.minor.abs();
      continue;
    }
    if (RegExp(r'sub\s?-?total').hasMatch(low)) {
      r.subtotal ??= p.minor;
      continue;
    }
    if (RegExp(
      r'^(grand total|total|amount paid|amount charged|you paid|order total|total paid)',
    ).hasMatch(low)) {
      r.total ??= p.minor;
      r.currency = p.currency;
      continue;
    }
    if (RegExp(r'coupon|promo|discount|voucher|offer|saving|wallet credit')
            .hasMatch(low) ||
        p.minor < 0) {
      r.discounts.add(ReceiptLine(label, p.minor.abs()));
      continue;
    }
    if (RegExp(r'\bvat\b|\btax\b').hasMatch(low)) continue;
    if (RegExp(
      r'fee|charge|delivery|shipping|tip|warranty|service|packaging|surcharge',
    ).hasMatch(low)) {
      r.fees.add(ReceiptLine(label, p.minor));
    }
  }
  return r;
}

/// A short hint that this food order is dining, not groceries, or vice versa,
/// is decided from items in category.dart; here only the delivery context.
bool _looksFood(String text) => RegExp(
  r'restaurant|food|meal|burger|pizza|menu',
  caseSensitive: false,
).hasMatch(text);

// ---- noon ---------------------------------------------------------------------

ParsedReceipt _noon(ReceiptMessage m, List<String> lines) {
  final subj = m.subject.toLowerCase();
  final all = lines.join('\n');
  final food = subj.contains('noon food') || all.contains('noon Food Team');
  if (food) {
    final fm = RegExp(
      r'order number\s+(\S+)\s+from\s+(.+?)\s+has been',
      caseSensitive: false,
    ).firstMatch(all);
    return ParsedReceipt(
      messageId: m.id,
      kind: MerchantKind.noon,
      stage: ReceiptStage.accepted,
      merchantName: 'noon Food',
      venue: fm?.group(2)?.trim(),
      orderId: fm?.group(1),
      when: m.receivedAt,
      dining: true,
      verified: true,
    );
  }
  final delivered =
      subj.contains('delivered') ||
      subj.contains('dispatched') ||
      subj.contains('shipped');
  final confirmed =
      subj.contains('thank you for your') ||
      subj.contains('order is confirmed') ||
      all.contains('is confirmed!');
  final shipment = RegExp(r'[Ss]hipment,?\s+([A-Z]{3,}\d{4,})(?:-S\d+)?')
      .firstMatch(all);
  final order = delivered
      ? shipment?.group(1)
      : RegExp(
              r'order,?\s+((?:N[A-Z]{3,5})\d{6,})',
              caseSensitive: false,
            ).firstMatch(all)?.group(1)?.toUpperCase() ??
            _findOrderId(lines);
  final super_ =
      subj.contains('supermall') ||
      all.toLowerCase().contains('supermall order');
  if (delivered || !confirmed) {
    return ParsedReceipt(
      messageId: m.id,
      kind: MerchantKind.noon,
      stage: delivered ? ReceiptStage.delivered : ReceiptStage.unknown,
      merchantName: 'noon',
      orderId: order,
      when: m.receivedAt,
      verified: true,
    );
  }
  final s = _sort(lines);
  return ParsedReceipt(
    messageId: m.id,
    kind: MerchantKind.noon,
    stage: ReceiptStage.confirmed,
    merchantName: super_ ? 'noon supermall' : 'noon',
    orderId: order,
    totalMinor: s.total,
    subtotalMinor: s.subtotal,
    currency: s.currency,
    items: s.items,
    fees: s.fees,
    discounts: s.discounts,
    cashbackMinor: s.cashback,
    cardLast4: _findLast4(lines),
    when: _findWhen(lines) ?? m.receivedAt,
    verified: true,
  );
}

// ---- Talabat and Careem (synthetic layouts, unverified) ------------------------

ParsedReceipt _marketplace(
  ReceiptMessage m,
  List<String> lines,
  MerchantKind kind,
  String brand,
) {
  final all = lines.join('\n');
  final subj = m.subject.toLowerCase();
  final s = _sort(lines);
  final venueM = RegExp(
    r'^(?:restaurant|store|vendor|from)\s*:\s*(.+)$',
    caseSensitive: false,
    multiLine: true,
  ).firstMatch(all);
  final accepted =
      (subj.contains('accepted') || subj.contains('on its way')) &&
      s.total == null;
  final has = s.total != null;
  final lower = all.toLowerCase();
  final mart =
      lower.contains('talabat mart') ||
      lower.contains('quik') ||
      lower.contains('grocer');
  var name = brand;
  if (kind == MerchantKind.talabat && lower.contains('talabat mart'))
    name = 'Talabat Mart';
  if (kind == MerchantKind.careem && lower.contains('quik'))
    name = 'Careem Quik';
  if (kind == MerchantKind.careem && lower.contains('food') && !mart)
    name = 'Careem Food';
  return ParsedReceipt(
    messageId: m.id,
    kind: kind,
    stage: has
        ? ReceiptStage.confirmed
        : (accepted ? ReceiptStage.accepted : ReceiptStage.unknown),
    merchantName: name,
    venue: venueM?.group(1)?.trim(),
    orderId: _findOrderId(
      lines.where((l) => !l.toLowerCase().startsWith('subject')),
    ),
    totalMinor: s.total,
    subtotalMinor: s.subtotal,
    currency: s.currency,
    items: s.items,
    fees: s.fees,
    discounts: s.discounts,
    cashbackMinor: s.cashback,
    cardLast4: _findLast4(lines),
    when: _findWhen(lines) ?? m.receivedAt,
    dining: !mart && _looksFood(all + subj),
    verified: false,
  );
}

// ---- generic ------------------------------------------------------------------

ParsedReceipt _generic(ReceiptMessage m, List<String> lines) {
  final s = _sort(lines);
  final from = m.from;
  final nameM = RegExp(r'^\s*"?([^"<@]+?)"?\s*<').firstMatch(from);
  final domain = RegExp(r'@([A-Za-z0-9-]+)\.').firstMatch(from)?.group(1);
  final name = (nameM?.group(1)?.trim().isNotEmpty ?? false)
      ? nameM!.group(1)!.trim()
      : (domain ?? 'Unknown');
  return ParsedReceipt(
    messageId: m.id,
    kind: MerchantKind.other,
    stage: s.total != null ? ReceiptStage.confirmed : ReceiptStage.unknown,
    merchantName: name,
    orderId: _findOrderId(lines),
    totalMinor: s.total,
    subtotalMinor: s.subtotal,
    currency: s.currency,
    items: s.items,
    fees: s.fees,
    discounts: s.discounts,
    cashbackMinor: s.cashback,
    cardLast4: _findLast4(lines),
    when: _findWhen(lines) ?? m.receivedAt,
    dining: _looksFood(m.subject),
  );
}

/// Parses one email. Never throws: anything unreadable comes back as
/// [ReceiptStage.unknown] with no amounts.
ParsedReceipt parseReceipt(ReceiptMessage m) {
  try {
    final lines = _bodyLines(m);
    final from = m.from.toLowerCase();
    if (from.contains('noon.com')) return _noon(m, lines);
    if (from.contains('talabat'))
      return _marketplace(m, lines, MerchantKind.talabat, 'Talabat');
    if (from.contains('careem'))
      return _marketplace(m, lines, MerchantKind.careem, 'Careem');
    return _generic(m, lines);
  } catch (_) {
    return ParsedReceipt(
      messageId: m.id,
      kind: MerchantKind.other,
      stage: ReceiptStage.unknown,
      merchantName: 'Unknown',
      when: m.receivedAt,
    );
  }
}
