import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/dates.dart';
import 'package:pulse/core/engine/prices.dart';
import 'package:pulse/core/engine/valuation.dart';

void main() {
  group('jewellery valuation', () {
    test('purity by karat', () {
      expect(purityForKarat(24), 1.0);
      expect(purityForKarat(22), closeTo(0.916667, 1e-6));
      expect(purityForKarat(21), 0.875);
      expect(purityForKarat(18), 0.75);
      expect(finenessLabel(22), '916');
      expect(karatForPurity(0.916), 22);
      expect(karatForPurity(0.5), isNull);
    });

    test('weight x purity x price, in fils', () {
      // 10 g of 22k at AED 400/g (24k): 10 * 22/24 * 400 = 3666.666... -> 3666.67
      final v = valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 22);
      expect(v.valueMinor, 366667);
      expect(v.pureGrams, closeTo(9.16667, 1e-4));
      expect(valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 24).valueMinor, 400000);
      expect(valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 18).valueMinor, 300000);
      expect(valueJewellery(weightGrams: 0, aedPerGram24: 400).valueMinor, 0);
    });

    test('an explicit fineness overrides the karat', () {
      final v = valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 22, purity: 0.9);
      expect(v.valueMinor, 360000);
    });

    test('gain and loss against the purchase price', () {
      final up = valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 22, purchasePriceMinor: 340000, makingChargesMinor: 30000);
      expect(up.gainMinor, 26667);
      expect(up.gainPct, closeTo(7.84, 0.01));
      final down = valueJewellery(weightGrams: 10, aedPerGram24: 400, karat: 22, purchasePriceMinor: 400000);
      expect(down.gainMinor, -33333);
      expect(down.gainPct!, lessThan(0));
      final none = valueJewellery(weightGrams: 10, aedPerGram24: 400);
      expect(none.gainMinor, isNull);
      expect(none.gainPct, isNull);
      expect(valueJewellery(weightGrams: 1, aedPerGram24: 1, purchasePriceMinor: 0).gainPct, isNull);
    });
  });

  group('fund valuation', () {
    test('units x NAV converted to AED', () {
      // 100.5 units at INR 52.30 = INR 5,256.15; at 0.0425 = AED 223.39
      final v = valueFund(units: 100.5, nav: 52.30, avgCostNav: 40, fxToAed: 0.0425);
      expect(v.valueNativeMinor, 525615);
      expect(v.costNativeMinor, 402000);
      expect(v.valueAedMinor, 22339);
      expect(v.gainPct, closeTo(30.75, 0.01));
      expect(v.gainAedMinor, 22339 - 17085);
    });

    test('an AED fund needs no conversion; a missing rate gives no AED value', () {
      final aed = valueFund(units: 10, nav: 12.5, fxToAed: 1);
      expect(aed.valueAedMinor, 12500);
      expect(aed.gainPct, isNull);
      final unknown = valueFund(units: 10, nav: 12.5, avgCostNav: 10, fxToAed: null);
      expect(unknown.valueAedMinor, isNull);
      expect(unknown.gainAedMinor, isNull);
      expect(unknown.gainPct, closeTo(25, 1e-9));
    });
  });

  group('SIP and reminders', () {
    test('next SIP date rolls over months and clamps short months', () {
      expect(nextSipDate(5, const CalDate(2026, 11, 3)), const CalDate(2026, 11, 5));
      expect(nextSipDate(5, const CalDate(2026, 11, 5)), const CalDate(2026, 11, 5));
      expect(nextSipDate(5, const CalDate(2026, 11, 6)), const CalDate(2026, 12, 5));
      expect(nextSipDate(5, const CalDate(2026, 12, 20)), const CalDate(2027, 1, 5));
      expect(nextSipDate(31, const CalDate(2027, 2, 10)), const CalDate(2027, 2, 28));
    });

    test('due status and text', () {
      const today = CalDate(2026, 11, 24);
      expect(dueStatus(const CalDate(2026, 11, 20), today), DueStatus.overdue);
      expect(dueStatus(const CalDate(2026, 11, 24), today), DueStatus.dueSoon);
      expect(dueStatus(const CalDate(2026, 12, 24), today), DueStatus.dueSoon);
      expect(dueStatus(const CalDate(2027, 2, 1), today), DueStatus.upcoming);
      expect(dueText(const CalDate(2026, 12, 4), today), 'in 10 days');
      expect(dueText(today, today), 'today');
      expect(dueText(const CalDate(2026, 11, 21), today), '3 days ago');
    });

    test('reminder fires at 09:00, N days before, and never in the past', () {
      final now = DateTime(2026, 11, 24, 12);
      expect(reminderTime(const CalDate(2026, 12, 24), 30, now), isNull); // 09:00 today has passed
      expect(reminderTime(const CalDate(2027, 1, 10), 14, now), DateTime(2026, 12, 27, 9));
      expect(reminderTime(const CalDate(2026, 11, 30), 14, now), isNull);
    });

    test('notification ids are stable and positive', () {
      expect(notificationIdFor('abc'), notificationIdFor('abc'));
      expect(notificationIdFor('abc'), isNot(notificationIdFor('abd')));
      expect(notificationIdFor('f' * 32), greaterThanOrEqualTo(0));
    });
  });

  group('price book', () {
    final at = DateTime.utc(2026, 11, 24, 8);
    final json = {
      'generated_at': '2026-11-24T08:00:00Z',
      'status': 'live',
      'gold': {
        'status': 'live',
        'source': 'gold-api.com',
        'last_updated': '2026-11-24T07:59:00Z',
        'per_gram': {
          '24k': {'aed': '480.50', 'usd': '130.8'},
          '22k': {'aed': 440.46, 'usd': 119.9},
          '18k': {'aed': 'bad', 'usd': 1},
        },
      },
      'fx': [
        {'currency': 'INR', 'aed_per_unit': '0.0427', 'status': 'live', 'source': 'open.er-api.com'},
        {'currency': 'EUR', 'aed_per_unit': 4.3, 'status': 'unavailable'},
      ],
    };

    test('parses decimals sent as strings and skips malformed entries', () {
      final q = parseSnapshot(json, fetchedAt: at);
      final book = PriceBook(q, origin: PriceOrigin.fetched);
      expect(book.gold24, 480.5);
      expect(book.goldPerGram(22), 440.46);
      expect(book.goldPerGram(21), closeTo(480.5 * 21 / 24, 1e-9)); // derived
      expect(book.goldPerGram(18), closeTo(480.5 * 18 / 24, 1e-9)); // bad entry skipped
      expect(book.fx('INR'), 0.0427);
      expect(book.fx('EUR'), isNull);
      expect(book.fx('AED'), 1);
      expect(book.fx('USD'), PriceBook.usdPeg);
      expect(book.isStale, isFalse);
      expect(book.fetchedAt, at);
    });

    test('garbage and unavailable gold yield nothing', () {
      expect(parseSnapshot('x', fetchedAt: at), isEmpty);
      expect(parseSnapshot({'gold': {'status': 'unavailable', 'per_gram': {}}}, fetchedAt: at), isEmpty);
    });

    test('the bundled fallback has gold and is marked stale', () {
      final b = bundledPriceBook();
      expect(b.gold24, isNotNull);
      expect(b.isStale, isTrue);
      expect(b.fx('INR'), isNotNull);
      final merged = mergeBooks(PriceBook(parseSnapshot(json, fetchedAt: at), origin: PriceOrigin.fetched), b);
      expect(merged.gold24, 480.5);
      expect(merged.fx('GBP'), isNotNull); // filled from the bundle
      expect(merged.origin, PriceOrigin.fetched);
      expect(mergeBooks(PriceBook(const []), b).origin, PriceOrigin.bundled);
    });
  });
}
