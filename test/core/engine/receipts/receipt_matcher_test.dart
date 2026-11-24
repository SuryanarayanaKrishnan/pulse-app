import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/receipts/merchant_offers.dart';
import 'package:pulse/core/engine/receipts/receipt_inbox.dart';
import 'package:pulse/core/engine/receipts/receipt_matcher.dart';
import 'package:pulse/core/engine/receipts/receipt_models.dart';
import 'package:pulse/core/engine/receipts/receipt_parsers.dart';
import 'package:pulse/core/engine/receipts/receipt_source.dart';
import 'package:pulse/core/engine/rewards.dart';

import 'fixture.dart';

ParsedReceipt _r({int? total = 6100, String? last4 = '1234', DateTime? when, String name = 'Talabat', MerchantKind kind = MerchantKind.talabat, List<ReceiptLine> disc = const [], ReceiptStage stage = ReceiptStage.confirmed}) =>
    ParsedReceipt(
      messageId: 'm1',
      kind: kind,
      stage: stage,
      merchantName: name,
      when: when ?? DateTime(2026, 3, 12, 19, 42),
      totalMinor: total,
      cardLast4: last4,
      discounts: disc,
    );

Charge _c(String id, int amt, {String m = 'TALABAT DUBAI AE', String? last4 = '1234', DateTime? at, bool linked = false}) =>
    Charge(id: id, amountMinor: amt, postedAt: at ?? DateTime(2026, 3, 13), merchant: m, cardLast4: last4, linked: linked);

void main() {
  group('matcher', () {
    test('same card, amount, near date, similar merchant matches', () {
      final m = matchReceipt(_r(), [_c('a', 6100), _c('b', 9999, m: 'CARREFOUR')]);
      expect(m.kind, MatchKind.matched);
      expect(m.charge!.id, 'a');
    });

    test('tolerance: a tip or VAT on top still matches, a bigger gap does not', () {
      expect(matchReceipt(_r(), [_c('a', 6600)]).kind, MatchKind.matched);
      expect(matchReceipt(_r(), [_c('a', 9000)]).kind, MatchKind.none);
      expect(matchReceipt(_r(), [_c('a', 5000)]).kind, MatchKind.none, reason: 'less than the receipt is not a tip');
    });

    test('a different card or a date over 3 days away never matches', () {
      expect(matchReceipt(_r(), [_c('a', 6100, last4: '9999')]).kind, MatchKind.none);
      expect(matchReceipt(_r(), [_c('a', 6100, at: DateTime(2026, 3, 17))]).kind, MatchKind.none);
      expect(matchReceipt(_r(), [_c('a', 6100, at: DateTime(2026, 3, 15))]).kind, MatchKind.matched);
    });

    test('unknown card on either side still matches on the rest', () {
      expect(matchReceipt(_r(last4: null), [_c('a', 6100)]).kind, MatchKind.matched);
      expect(matchReceipt(_r(), [_c('a', 6100, last4: null)]).kind, MatchKind.matched);
    });

    test('a charge net of the coupon matches a noon receipt', () {
      final r = _r(total: 16250, last4: null, name: 'noon supermall', kind: MerchantKind.noon, disc: const [ReceiptLine('Coupon', 1500)]);
      final m = matchReceipt(r, [_c('a', 14750, m: 'NOON.COM DUBAI AE', last4: '4444')]);
      expect(m.kind, MatchKind.matched);
    });

    test('a different merchant does not match', () {
      expect(matchReceipt(_r(), [_c('a', 6100, m: 'ENOC STATION')]).kind, MatchKind.none);
    });

    test('two equal charges are ambiguous and are not auto-linked', () {
      final m = matchReceipt(_r(), [_c('a', 6100), _c('b', 6100)]);
      expect(m.kind, MatchKind.ambiguous);
      expect(m.charge, isNull);
      expect(m.candidates.map((c) => c.id).toSet(), {'a', 'b'});
    });

    test('a charge that already has a receipt is never linked twice', () {
      final m = matchReceipt(_r(), [_c('a', 6100, linked: true)]);
      expect(m.kind, MatchKind.alreadyLinked);
      expect(matchReceipt(_r(), [_c('a', 6100, linked: true), _c('b', 6100)]).charge!.id, 'b');
    });

    test('a refund (credit) is not a charge', () {
      final credit = Charge(id: 'c', amountMinor: 6100, postedAt: DateTime(2026, 3, 13), merchant: 'TALABAT', cardLast4: '1234', isDebit: false);
      expect(matchReceipt(_r(), [credit]).kind, MatchKind.none);
    });

    test('no amount (noon food accepted): one same-day noon charge matches, two are ambiguous, never an invented total', () {
      final r = parseReceipt(loadReceipt('noon/noon_food_order_accepted_1.txt', at: DateTime(2026, 3, 12, 20, 0)));
      final one = _c('a', 4350, m: 'NOON FOOD DUBAI', last4: null, at: DateTime(2026, 3, 12, 20, 5));
      final m = matchReceipt(r, [one]);
      expect(m.kind, MatchKind.matched);
      expect(r.totalMinor, isNull);
      final two = _c('b', 2210, m: 'NOON FOOD DUBAI', last4: null, at: DateTime(2026, 3, 12, 20, 5));
      expect(matchReceipt(r, [one, two]).kind, MatchKind.ambiguous);
      expect(matchReceipt(r, [_c('a', 4350, m: 'NOON FOOD', last4: null, at: DateTime(2026, 3, 15))]).kind, MatchKind.none);
    });

    test('delivered and unknown emails never match', () {
      final r = parseReceipt(loadReceipt('noon/noon_shipment_delivered.txt'));
      expect(matchReceipt(r, [_c('a', 100, m: 'NOON')]).kind, MatchKind.none);
    });
  });

  group('inbox: hold, then review, never spend', () {
    test('held receipts become due after the hold period and survive a restart', () {
      final inbox = ReceiptInbox();
      final t0 = DateTime(2026, 3, 12);
      inbox.hold(_r(), t0);
      expect(inbox.dueForReview(t0.add(const Duration(days: holdDays - 1))), isEmpty);
      expect(inbox.waiting(t0), hasLength(1));
      final again = ReceiptInbox.decode(inbox.encode());
      expect(again.dueForReview(t0.add(const Duration(days: holdDays))), hasLength(1));
    });

    test('a handled or dismissed receipt is not held again', () {
      final inbox = ReceiptInbox()..hold(_r(), DateTime(2026, 3, 12));
      inbox.dismiss('m1');
      expect(inbox.held, isEmpty);
      expect(inbox.seen(_r()), isTrue);
    });

    test('the stored text holds extracted fields only', () {
      final msg = loadReceipt('noon/noon_order_confirmed.txt');
      final inbox = ReceiptInbox()..hold(parseReceipt(msg), DateTime(2026, 3, 12));
      final s = inbox.encode();
      for (final leak in ['Sample Customer', 'example tower', 'user@example.com', '+971', 'Verified']) {
        expect(s.contains(leak), isFalse, reason: leak);
      }
    });
  });

  group('sources', () {
    test('the in-memory source filters by date', () async {
      final src = InMemoryReceiptSource([loadReceipt('noon/noon_order_confirmed.txt', at: DateTime(2026, 3, 1))]);
      expect(await src.fetch(since: DateTime(2026, 3, 2)), isEmpty);
      expect(await src.fetch(since: DateTime(2026, 2, 1)), hasLength(1));
    });

    test('Gmail is read-only, narrow and not configured', () {
      expect(gmailReadOnlyScope, endsWith('gmail.readonly'));
      final q = gmailReceiptQuery(DateTime(2026, 3, 1));
      expect(q, contains('from:noon.com'));
      expect(q, contains('after:2026/03/01'));
      expect(const GmailReceiptSource().isConfigured, isFalse);
      expect(() => const GmailReceiptSource().fetch(since: DateTime(2026)), throwsUnsupportedError);
    });
  });

  group('merchant offers (invented, unverified)', () {
    RankableCard card(String id, String title, {double base = 0.01}) => RankableCard(
      id: id,
      title: title,
      spec: CardSpec(unit: 'cashback', pointValueAed: 1, baseRate: base),
      state: CycleResult(),
    );
    final offers = MerchantOffers.parse('''
{"version":1,"offers":[{"id":"o","merchant":"noon","card_title_contains":["noon one"],"unit":"cashback","rate":0.05,"label":"Example"}]}''');

    test('wrong card for noon is flagged as an estimate', () {
      final h = merchantCardHint(
        offers: offers,
        merchantKey: 'noon',
        paidCardId: 'plain',
        cards: [card('plain', 'Plain Card', base: 0.02), card('n', 'noon One Visa')],
        amountMinor: 100000,
      )!;
      expect(h.right, isFalse);
      expect(h.estimated, isTrue);
      expect(h.bestTitle, 'noon One Visa');
      expect(h.message, contains('estimate, unverified'));
      expect(h.missedMinor, 3000);
    });

    test('right card for noon', () {
      final h = merchantCardHint(
        offers: offers,
        merchantKey: 'noon',
        paidCardId: 'n',
        cards: [card('plain', 'Plain Card'), card('n', 'noon One Visa')],
        amountMinor: 100000,
      )!;
      expect(h.right, isTrue);
      expect(h.message, startsWith('Right card'));
    });

    test('nothing for other merchants, one card, or a bad file', () {
      expect(merchantCardHint(offers: offers, merchantKey: 'carrefour', paidCardId: 'n', cards: [card('plain', 'P'), card('n', 'noon One')], amountMinor: 100), isNull);
      expect(merchantCardHint(offers: offers, merchantKey: 'noon', paidCardId: 'n', cards: [card('n', 'noon One')], amountMinor: 100), isNull);
      expect(MerchantOffers.parse('nope').offers, isEmpty);
      expect(MerchantOffers.parse('{"version":2,"offers":[]}').offers, isEmpty);
    });
  });
}
