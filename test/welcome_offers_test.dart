import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/catalog.dart';
import 'package:pulse/core/engine/welcome_offers.dart';

CatalogCard card(
  String id, {
  Map<String, Object?>? offer,
  String? source = 'https://bank.example/card',
  DateTime? checked,
  Map<String, Object?> extra = const {},
}) => CatalogCard(
  id: id,
  issuer: 'Bank',
  name: id,
  network: 'visa',
  annualFeeMinor: 0,
  minSalaryMinor: null,
  rewardStructure: const {'unit': 'cashback', 'base_rate': 0.01, 'rules': []},
  perks: {'welcome_offer': ?offer, ...extra},
  verifiedOn: checked ?? DateTime(2026, 11, 20),
  source: source,
);

void main() {
  final now = DateTime(2026, 11, 28, 12);

  test('an expired offer is never listed; the last day still is', () {
    final list = welcomeOffers([
      card('old', offer: {'text': 'x', 'valid_until': '2026-11-27'}),
      card('last', offer: {'text': 'x', 'valid_until': '2026-11-28'}),
    ], now: now);
    expect(list.map((o) => o.card.id), ['last']);
    expect(list.single.daysLeft, 0);
    expect(list.single.endingSoon, isTrue);
  });

  test('cards without an offer, or held, or closed to new are left out', () {
    final list = welcomeOffers(
      [
        card('none'),
        card('held', offer: {'text': 'x'}),
        card(
          'closed',
          offer: {'text': 'x'},
          extra: {'status': 'closed_to_new'},
        ),
        card('open', offer: {'text': 'x'}),
      ],
      now: now,
      heldCatalogIds: {'held'},
    );
    expect(list.map((o) => o.card.id), ['open']);
  });

  test('soonest deadline first, then biggest value, unknown value last', () {
    final list = welcomeOffers([
      card('big', offer: {'text': 'x', 'value_aed_est': 900}),
      card('small', offer: {'text': 'x', 'value_aed_est': 100}),
      card('unknown', offer: {'text': 'x'}),
      card(
        'soon',
        offer: {'text': 'x', 'value_aed_est': 50, 'valid_until': '2026-12-01'},
      ),
      card(
        'later',
        offer: {
          'text': 'x',
          'value_aed_est': 5000,
          'valid_until': '2027-03-01',
        },
      ),
    ], now: now);
    expect(list.map((o) => o.card.id), [
      'soon',
      'later',
      'big',
      'small',
      'unknown',
    ]);
  });

  test('evidence: bank page, comparison site, or unverified', () {
    expect(
      offerEvidence('https://www.hsbc.ae/cards', DateTime(2026, 11, 1)),
      OfferEvidence.bank,
    );
    expect(
      offerEvidence('https://kredit.ae/credit-cards/x', DateTime(2026, 11, 1)),
      OfferEvidence.aggregator,
    );
    expect(
      offerEvidence('https://www.reddit.com/r/x', DateTime(2026, 11, 1)),
      OfferEvidence.aggregator,
    );
    expect(
      offerEvidence(null, DateTime(2026, 11, 1)),
      OfferEvidence.unverified,
    );
    expect(offerEvidence('https://a.ae', null), OfferEvidence.unverified);
  });

  test("an offer's own source and date win over the card's", () {
    final list = welcomeOffers([
      card(
        'own',
        offer: {
          'text': 'x',
          'source_url': 'https://bank.example/promo',
          'verified_on': '2026-11-27',
        },
        checked: DateTime(2026, 1, 1),
      ),
    ], now: now);
    expect(list.single.sourceUrl, 'https://bank.example/promo');
    expect(list.single.checkedOn, DateTime(2026, 11, 27));
    expect(list.single.stale, isFalse);
  });

  test('a check older than 45 days is flagged stale', () {
    final list = welcomeOffers([
      card('fresh', offer: {'text': 'x'}, checked: DateTime(2026, 11, 1)),
      card('stale', offer: {'text': 'x'}, checked: DateTime(2026, 9, 1)),
    ], now: now);
    expect(
      {for (final o in list) o.card.id: o.stale},
      {'fresh': false, 'stale': true},
    );
  });

  test('a card in a combo names the combo', () {
    final list = welcomeOffers(
      [
        card('tabby', offer: {'text': 'x'}),
      ],
      now: now,
      comboCardIds: {
        'stack': ['tabby', 'sib'],
        'other': ['sib'],
      },
    );
    expect(list.single.comboIds, ['stack']);
  });

  test('reminders: a week before and the day before, only those ahead', () {
    final d = DateTime(2026, 12, 15);
    var r = offerReminderTimes(d, now);
    expect(r.map((t) => t.at), [
      DateTime(2026, 12, 8, 9),
      DateTime(2026, 12, 14, 9),
    ]);
    expect(r.map((t) => t.daysBefore), [7, 1]);
    r = offerReminderTimes(DateTime(2026, 12, 2), now);
    expect(r.map((t) => t.at), [DateTime(2026, 12, 1, 9)]);
    expect(offerReminderTimes(DateTime(2026, 11, 28), now), isEmpty);
  });

  group('bundled catalog and combos', () {
    final catalog = CardCatalog.fromJson(
      jsonDecode(File('assets/catalog/cards.json').readAsStringSync())
          as Map<String, Object?>,
    );
    final combos =
        (jsonDecode(File('assets/catalog/combos.json').readAsStringSync())
                as Map<String, dynamic>)['items']
            as List;
    final all = welcomeOffers(catalog.cards, now: DateTime(2026, 11, 28));

    test('there are offers, and every one has its text and a real figure', () {
      expect(all.length, greaterThan(40));
      for (final o in all) {
        expect(o.text.length, greaterThan(8), reason: o.card.id);
        if (o.valueAed != null) {
          expect(o.valueAed, greaterThan(0), reason: o.card.id);
        }
        if (o.minSpendMinor != null) {
          expect(o.minSpendMinor, greaterThan(0), reason: o.card.id);
        }
      }
    });

    test('every offer with a deadline has a real date on or after today', () {
      for (final o in all.where((o) => o.validUntil != null)) {
        expect(o.daysLeft, isNotNull, reason: o.card.id);
        expect(o.daysLeft, greaterThanOrEqualTo(0), reason: o.card.id);
      }
    });

    test('every offer has an official source and a check date', () {
      final bad = [
        for (final o in all)
          if (o.evidence != OfferEvidence.bank) o.card.id,
      ];
      expect(bad, isEmpty, reason: 'offers without a bank source: $bad');
      for (final o in all) {
        expect(Uri.parse(o.sourceUrl!).scheme, 'https', reason: o.card.id);
        expect(o.checkedOn, isNotNull, reason: o.card.id);
      }
    });

    test('every card in a combo exists in the catalog', () {
      final ids = {for (final c in catalog.cards) c.id};
      for (final c in combos) {
        for (final id in (c['card_ids'] as List).cast<String>()) {
          expect(ids, contains(id), reason: 'combo ${c['id']}');
        }
      }
    });

    test('the Reddit stack cards are in the catalog and stay linked', () {
      final stack = combos.firstWhere(
        (c) => c['id'] == 'reddit-tabby-sib-chain',
      ) as Map<String, dynamic>;
      final withLinks = welcomeOffers(
        catalog.cards,
        now: DateTime(2026, 11, 28),
        comboCardIds: {
          stack['id'] as String: (stack['card_ids'] as List).cast(),
        },
      );
      for (final o in withLinks.where((o) => o.comboIds.isNotEmpty)) {
        expect(o.comboIds, ['reddit-tabby-sib-chain']);
      }
    });
  });
}
