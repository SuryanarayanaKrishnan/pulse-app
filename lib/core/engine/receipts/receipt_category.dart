/// A better category from a receipt's line items. Pure Dart.
library;

import 'receipt_models.dart';

const _grocery = [
  'milk',
  'eggs',
  'egg ',
  'bread',
  'rice',
  'flour',
  'sugar',
  'oil',
  'butter',
  'cheese',
  'yogurt',
  'yoghurt',
  'laban',
  'chicken breast',
  'minced',
  'beef',
  'lamb',
  'fish',
  'banana',
  'apple',
  'tomato',
  'onion',
  'potato',
  'cucumber',
  'lettuce',
  'fruit',
  'vegetable',
  'water 1',
  'pack of',
  'detergent',
  'tissue',
  'diaper',
  'cereal',
  'pasta',
  'noodles',
  'lentil',
  'dates',
  'fresh',
  'organic', 'frozen', 'snack', 'juice 1l', 'kg', 'dozen', //
];

const _meal = [
  'burger',
  'pizza',
  'shawarma',
  'sandwich',
  'wrap',
  'meal',
  'combo',
  'fries',
  'nuggets',
  'biryani',
  'kebab',
  'sushi',
  'roll',
  'salad bowl',
  'latte',
  'coffee',
  'cappuccino',
  'dessert',
  'platter', //
];

/// `groceries` or `dining` when the lines make it clear, else null (keep the
/// category the bank line already has). A food-delivery marketplace's grocery
/// baskets are groceries even though the merchant looks like dining.
String? categoryFromReceipt(ParsedReceipt r) {
  if (r.stage == ReceiptStage.accepted && r.dining) return 'dining';
  if (r.items.isEmpty) {
    return r.dining && r.stage == ReceiptStage.confirmed ? 'dining' : null;
  }
  var g = 0, m = 0;
  for (final i in r.items) {
    final n = '${i.name.toLowerCase()} ';
    if (_grocery.any(n.contains)) g++;
    if (_meal.any(n.contains)) m++;
  }
  final mart =
      r.merchantName.toLowerCase().contains('mart') ||
      r.merchantName.toLowerCase().contains('quik');
  if (g > m || (mart && m == 0)) return 'groceries';
  if (m > g) return 'dining';
  return r.dining ? 'dining' : null;
}

/// Item-level note, "2 x Chicken Burger, Fries" plus fee and promo lines.
String receiptNotes(ParsedReceipt r) {
  String aed(int m) => (m / 100).toStringAsFixed(2);
  final parts = <String>[];
  if (r.venue != null) parts.add('From ${r.venue}');
  if (r.items.isNotEmpty) {
    parts.add(
      r.items
          .map((i) => i.quantity > 1 ? '${i.quantity} x ${i.name}' : i.name)
          .join(', '),
    );
  }
  for (final f in r.fees) {
    parts.add(
      '${f.label}: ${f.minor == 0 ? 'free' : '${r.currency} ${aed(f.minor)}'}',
    );
  }
  for (final d in r.discounts) {
    parts.add('${d.label}: -${r.currency} ${aed(d.minor)}');
  }
  if (r.cashbackMinor != null) {
    parts.add(
      'Card cashback (estimate): ${r.currency} ${aed(r.cashbackMinor!)}',
    );
  }
  return parts.join('\n');
}
