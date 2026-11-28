/// Example merchant offers (card x merchant) and a right/wrong card hint for
/// a merchant, built on the card value engine. Pure Dart.
///
/// The bundled offers in `assets/merchant_offers.json` are INVENTED examples.
/// Everything this file returns is an estimate and is flagged as such.
library;

import 'dart:convert';

import '../card_value.dart';
import '../rewards.dart';

class MerchantOffer {
  const MerchantOffer({
    required this.id,
    required this.merchant,
    required this.cardTitleContains,
    required this.rate,
    required this.label,
  });
  final String id;

  /// Lower-case merchant key ("noon").
  final String merchant;
  final List<String> cardTitleContains;

  /// Share of spend returned (0.05 = 5%).
  final double rate;
  final String label;

  bool appliesTo(String cardTitle) {
    final t = cardTitle.toLowerCase();
    return cardTitleContains.any((s) => t.contains(s.toLowerCase()));
  }
}

class MerchantOffers {
  const MerchantOffers(this.version, this.verified, this.offers);
  final int version;
  final bool verified;
  final List<MerchantOffer> offers;

  static const empty = MerchantOffers(0, false, []);

  /// Tolerant: unknown versions and bad entries are skipped, never thrown.
  static MerchantOffers parse(String json) {
    try {
      final j = Map<String, Object?>.from(jsonDecode(json) as Map);
      final version = (j['version'] as num?)?.toInt() ?? 0;
      if (version != 1) return empty;
      final out = <MerchantOffer>[];
      for (final raw in (j['offers'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final rate = (raw['rate'] as num?)?.toDouble();
        final merchant = raw['merchant'];
        if (rate == null ||
            rate <= 0 ||
            rate > 1 ||
            merchant is! String ||
            merchant.isEmpty)
          continue;
        out.add(
          MerchantOffer(
            id: '${raw['id']}',
            merchant: merchant.toLowerCase(),
            cardTitleContains: [
              for (final s in (raw['card_title_contains'] as List? ?? const []))
                '$s',
            ],
            rate: rate,
            label: '${raw['label'] ?? ''}',
          ),
        );
      }
      return MerchantOffers(version, j['verified'] == true, out);
    } catch (_) {
      return empty;
    }
  }
}

class OfferHint {
  const OfferHint({
    required this.right,
    required this.message,
    required this.paidTitle,
    required this.bestTitle,
    required this.missedMinor,
  });
  final bool right;
  final String message;
  final String paidTitle, bestTitle;
  final int missedMinor;

  /// Always true: offers are invented examples and issuer terms unverified.
  bool get estimated => true;
}

CardSpec _withOffer(CardSpec s, MerchantOffer o) {
  final units = s.isCashback ? o.rate : o.rate / s.pointValueAed;
  return CardSpec(
    unit: s.unit,
    pointValueAed: s.pointValueAed,
    baseRate: s.baseRate,
    // A merchant rule is picked before category rules, so it goes first.
    rules: [
      RuleSpec(name: o.label, rate: units, merchants: [o.merchant]),
      ...s.rules,
    ],
    excludedCategories: s.excludedCategories,
    minMonthlySpendMinor: s.minMonthlySpendMinor,
    feeWaiverSpendMinor: s.feeWaiverSpendMinor,
  );
}

/// "You used the wrong/right card for noon", or null when there is nothing to
/// compare (one card, no earning difference, no offer for this merchant).
OfferHint? merchantCardHint({
  required MerchantOffers offers,
  required String merchantKey,
  required String paidCardId,
  required List<RankableCard> cards,
  required int amountMinor,
  String? category,
}) {
  final key = merchantKey.toLowerCase();
  final relevant = offers.offers
      .where((o) => key.contains(o.merchant))
      .toList();
  if (relevant.isEmpty) return null;
  final boosted = [
    for (final c in cards)
      RankableCard(
        id: c.id,
        title: c.title,
        spec: relevant
            .where((o) => o.appliesTo(c.title))
            .fold(c.spec, _withOffer),
        state: c.state,
        createdOrder: c.createdOrder,
      ),
  ];
  final check = checkCard(
    paidCardId: paidCardId,
    before: boosted,
    spend: Spend(amountMinor, category, key),
    unverifiedCardIds: {for (final c in cards) c.id},
  );
  if (check == null) return null;
  String aed(int m) => (m / 100).toStringAsFixed(2);
  final name = key[0].toUpperCase() + key.substring(1);
  final msg = check.right
      ? 'Right card for $name (estimate, unverified): ${check.paidTitle} is the best of your cards here.'
      : 'Wrong card for $name (estimate, unverified): ${check.bestTitle} could have earned about AED ${aed(check.missedMinor)} more than ${check.paidTitle}.';
  return OfferHint(
    right: check.right,
    message: msg,
    paidTitle: check.paidTitle,
    bestTitle: check.bestTitle,
    missedMinor: check.missedMinor,
  );
}
