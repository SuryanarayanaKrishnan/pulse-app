import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/receipts/receipt_category.dart';
import 'package:pulse/core/engine/receipts/receipt_models.dart';
import 'package:pulse/core/engine/receipts/receipt_parsers.dart';

import 'fixture.dart';

void main() {
  group('noon (anonymised real emails)', () {
    test(
      'food order accepted: restaurant and order number, NO amount invented',
      () {
        final r = parseReceipt(
          loadReceipt('noon/noon_food_order_accepted_1.txt'),
        );
        expect(r.kind, MerchantKind.noon);
        expect(r.stage, ReceiptStage.accepted);
        expect(r.venue, "McDonald's");
        expect(r.orderId, '1234');
        expect(r.totalMinor, isNull);
        expect(r.chargeCandidates, isEmpty);
        expect(r.dining, isTrue);
        expect(categoryFromReceipt(r), 'dining');
        final r2 = parseReceipt(
          loadReceipt('noon/noon_food_order_accepted_2.txt'),
        );
        expect(r2.venue, "Papa Murphy's Pizza");
        expect(r2.orderId, '5678');
      },
    );

    test('order confirmed: total, free shipping; the card line is cashback, not spend', () {
      final r = parseReceipt(loadReceipt('noon/noon_order_confirmed.txt'));
      expect(r.stage, ReceiptStage.confirmed);
      expect(r.merchantName, 'noon');
      expect(r.orderId, 'NAEIA0000000001');
      expect(r.subtotalMinor, 120000);
      expect(r.totalMinor, 120000);
      expect(r.currency, 'AED');
      expect(r.cashbackMinor, 6000);
      expect(r.fees.single.minor, 0);
      expect(r.cardLast4, isNull);
      expect(r.discounts, isEmpty);
      expect(r.verified, isTrue);
      expect(r.chargeCandidates, [
        120000,
      ], reason: 'cashback must not become a charge');
    });

    test('supermall: service fee, warranty, coupon listed after the total', () {
      final r = parseReceipt(
        loadReceipt('noon/noon_supermall_order_confirmed.txt'),
      );
      expect(r.merchantName, 'noon supermall');
      expect(r.orderId, 'NAEIB0000000001');
      expect(r.totalMinor, 16250);
      expect(r.fees.map((f) => (f.label, f.minor)), [
        ('Shipping fee', 0),
        ('Supermall service fees', 350),
        ('Extended Warranty', 900),
      ]);
      expect(r.discounts.single.minor, 1500);
      expect(r.cashbackMinor, 1625);
      // The card may have been charged with or without the coupon.
      expect(r.chargeCandidates, [16250, 14750]);
      expect(receiptNotes(r), contains('Supermall service fees: AED 3.50'));
      expect(receiptNotes(r), contains('Coupon: -AED 15.00'));
    });

    test('shipment delivered: order id only, shipment suffix dropped', () {
      final r = parseReceipt(loadReceipt('noon/noon_shipment_delivered.txt'));
      expect(r.stage, ReceiptStage.delivered);
      expect(r.orderId, 'NAEIA0000000001');
      expect(r.totalMinor, isNull);
    });
  });

  group('talabat and careem (SYNTHETIC fixtures, real layouts unverified)', () {
    test('talabat HTML: items, fees, promo, card last 4, date', () {
      final r = parseReceipt(
        loadReceipt(
          'synthetic/talabat_confirmed.html',
          from: 'talabat <no-reply@talabat.example>',
          subject: 'Your talabat order',
        ),
      );
      expect(r.kind, MerchantKind.talabat);
      expect(r.verified, isFalse);
      expect(r.stage, ReceiptStage.confirmed);
      expect(r.venue, 'Example Burger House');
      expect(r.orderId, '900100200');
      expect(r.totalMinor, 6100);
      expect(r.subtotalMinor, 6000);
      expect(r.items.map((i) => (i.quantity, i.name, i.priceMinor)), [
        (2, 'Cheese Burger', 4800),
        (1, 'Large Fries', 1200),
      ]);
      expect(r.fees.map((f) => f.minor), [500, 200]);
      expect(r.discounts.single.minor, 600);
      expect(r.cardLast4, '1234');
      expect(r.when, DateTime(2026, 3, 12, 19, 42));
      expect(categoryFromReceipt(r), 'dining');
    });

    test('talabat mart basket is groceries, not dining', () {
      final r = parseReceipt(
        loadReceipt('synthetic/talabat_mart_confirmed.txt'),
      );
      expect(r.merchantName, 'Talabat Mart');
      expect(r.totalMinor, 7400);
      expect(r.cardLast4, '5678');
      expect(r.dining, isFalse);
      expect(categoryFromReceipt(r), 'groceries');
    });

    test('careem quik groceries and careem food dining', () {
      final q = parseReceipt(
        loadReceipt('synthetic/careem_quik_confirmed.txt'),
      );
      expect(q.kind, MerchantKind.careem);
      expect(q.merchantName, 'Careem Quik');
      expect(q.orderId, 'QK-778899');
      expect(q.totalMinor, 1600);
      expect(q.discounts.single.minor, 500);
      expect(categoryFromReceipt(q), 'groceries');
      final f = parseReceipt(
        loadReceipt('synthetic/careem_food_confirmed.txt'),
      );
      expect(f.merchantName, 'Careem Food');
      expect(f.fees.map((x) => x.label), ['Delivery fee', 'Tip']);
      expect(categoryFromReceipt(f), 'dining');
    });

    test('a promo email is not a receipt', () {
      final r = parseReceipt(loadReceipt('synthetic/talabat_promo.txt'));
      expect(r.stage, ReceiptStage.unknown);
      expect(r.totalMinor, isNull);
    });
  });

  test('generic merchant: total, shipping and card', () {
    final r = parseReceipt(loadReceipt('synthetic/generic_shop.txt'));
    expect(r.kind, MerchantKind.other);
    expect(r.merchantName, 'Example Shop');
    expect(r.totalMinor, 11000);
    expect(r.orderId, 'ES-5511');
    expect(r.cardLast4, '4321');
    expect(r.fees.single.minor, 1000);
  });

  test('garbage never throws', () {
    final r = parseReceipt(
      ReceiptMessage(
        id: 'x',
        from: '',
        subject: '',
        body: '<<<\u0000>>',
        receivedAt: DateTime(2026),
      ),
    );
    expect(r.stage, ReceiptStage.unknown);
  });

  test(
    'a receipt survives JSON (only extracted fields) and holds no body text',
    () {
      final r = parseReceipt(
        loadReceipt('noon/noon_supermall_order_confirmed.txt'),
      );
      final j = r.toJson();
      expect(ParsedReceipt.fromJson(j).toJson(), j);
      final text = j.toString();
      expect(text.contains('Sample Customer'), isFalse);
      expect(text.contains('example tower'), isFalse);
      expect(text.contains('user@example.com'), isFalse);
    },
  );
}
