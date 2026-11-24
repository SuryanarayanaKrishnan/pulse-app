/// Receipt data types. Pure Dart. Only EXTRACTED fields live here: the raw
/// email body is parsed and thrown away, never stored or synced.
library;

/// Which merchant family a receipt belongs to. Also the only merchant detail
/// analytics may carry (`noon`, `talabat`, `careem`, `other`).
enum MerchantKind {
  noon,
  talabat,
  careem,
  other;

  static MerchantKind byName(String? s) =>
      values.firstWhere((v) => v.name == s, orElse: () => other);
}

/// What the email says happened.
enum ReceiptStage {
  /// Order placed, confirmed or paid: carries the amounts.
  confirmed,

  /// "Your order has been accepted": a restaurant and an order number, often
  /// no amount at all.
  accepted,

  /// Shipped or delivered: an order id only.
  delivered,

  /// Marketing or something we do not understand.
  unknown,
}

/// An email as the source hands it over. The body is used by the parser only.
class ReceiptMessage {
  const ReceiptMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.body,
    required this.receivedAt,
    this.isHtml = false,
  });

  /// Provider message id (also what the receipt link points at).
  final String id;
  final String from;
  final String subject;
  final String body;
  final DateTime receivedAt;
  final bool isHtml;
}

class ReceiptItem {
  const ReceiptItem(this.name, {this.quantity = 1, this.priceMinor});
  final String name;
  final int quantity;

  /// Line price in fils, when the email shows one.
  final int? priceMinor;

  Map<String, Object?> toJson() => {'n': name, 'q': quantity, 'p': priceMinor};
  static ReceiptItem fromJson(Map<String, Object?> j) => ReceiptItem(
    j['n'] as String? ?? '',
    quantity: (j['q'] as num?)?.toInt() ?? 1,
    priceMinor: (j['p'] as num?)?.toInt(),
  );
}

/// A fee, tip or discount line (amount in fils, always positive).
class ReceiptLine {
  const ReceiptLine(this.label, this.minor);
  final String label;
  final int minor;
  Map<String, Object?> toJson() => {'l': label, 'm': minor};
  static ReceiptLine fromJson(Map<String, Object?> j) =>
      ReceiptLine(j['l'] as String? ?? '', (j['m'] as num?)?.toInt() ?? 0);
}

class ParsedReceipt {
  const ParsedReceipt({
    required this.messageId,
    required this.kind,
    required this.stage,
    required this.merchantName,
    required this.when,
    this.venue,
    this.orderId,
    this.totalMinor,
    this.subtotalMinor,
    this.currency = 'AED',
    this.cardLast4,
    this.items = const [],
    this.fees = const [],
    this.discounts = const [],
    this.cashbackMinor,
    this.dining = false,
    this.verified = false,
  });

  final String messageId;
  final MerchantKind kind;
  final ReceiptStage stage;

  /// "noon", "talabat", "Careem Food", or the generic sender name.
  final String merchantName;

  /// Restaurant or shop inside a marketplace ("McDonald's").
  final String? venue;
  final String? orderId;

  /// What the receipt says was charged. Null when the email shows no amount;
  /// it is never guessed.
  final int? totalMinor;
  final int? subtotalMinor;
  final String currency;

  /// Last four digits of the card paid with, only when the email shows them.
  final String? cardLast4;
  final List<ReceiptItem> items;

  /// Delivery, service, tip, warranty lines.
  final List<ReceiptLine> fees;

  /// Promo, coupon and voucher lines.
  final List<ReceiptLine> discounts;

  /// Cashback the card issuer will credit (noon One card line). This is NOT a
  /// charge and never counts as spend.
  final int? cashbackMinor;

  /// Restaurant / food delivery order.
  final bool dining;

  /// True only for layouts checked against a real email.
  final bool verified;
  final DateTime when;

  int get discountMinor => discounts.fold(0, (s, d) => s + d.minor);
  int get feesMinor => fees.fold(0, (s, d) => s + d.minor);
  bool get hasAmount => totalMinor != null;

  /// Amounts the card may actually have been charged: the total, and the
  /// total less a discount line that some emails list after the total.
  List<int> get chargeCandidates {
    final t = totalMinor;
    if (t == null) return const [];
    final out = <int>[t];
    final d = discountMinor;
    if (d > 0 && t - d > 0) out.add(t - d);
    return out;
  }

  Map<String, Object?> toJson() => {
    'id': messageId,
    'kind': kind.name,
    'stage': stage.name,
    'merchant': merchantName,
    'venue': venue,
    'order': orderId,
    'total': totalMinor,
    'sub': subtotalMinor,
    'cur': currency,
    'last4': cardLast4,
    'items': [for (final i in items) i.toJson()],
    'fees': [for (final f in fees) f.toJson()],
    'disc': [for (final f in discounts) f.toJson()],
    'cashback': cashbackMinor,
    'dining': dining,
    'verified': verified,
    'when': when.toUtc().toIso8601String(),
  };

  static ParsedReceipt fromJson(Map<String, Object?> j) => ParsedReceipt(
    messageId: j['id'] as String,
    kind: MerchantKind.byName(j['kind'] as String?),
    stage: ReceiptStage.values.firstWhere(
      (s) => s.name == j['stage'],
      orElse: () => ReceiptStage.unknown,
    ),
    merchantName: j['merchant'] as String? ?? '',
    venue: j['venue'] as String?,
    orderId: j['order'] as String?,
    totalMinor: (j['total'] as num?)?.toInt(),
    subtotalMinor: (j['sub'] as num?)?.toInt(),
    currency: j['cur'] as String? ?? 'AED',
    cardLast4: j['last4'] as String?,
    items: [
      for (final i in (j['items'] as List? ?? const []))
        ReceiptItem.fromJson(Map<String, Object?>.from(i as Map)),
    ],
    fees: [
      for (final i in (j['fees'] as List? ?? const []))
        ReceiptLine.fromJson(Map<String, Object?>.from(i as Map)),
    ],
    discounts: [
      for (final i in (j['disc'] as List? ?? const []))
        ReceiptLine.fromJson(Map<String, Object?>.from(i as Map)),
    ],
    cashbackMinor: (j['cashback'] as num?)?.toInt(),
    dining: j['dining'] == true,
    verified: j['verified'] == true,
    when: DateTime.parse(j['when'] as String),
  );
}
