/// Welcome bonuses per card, built only from the card catalog.
///
/// Nothing here is typed by hand: every figure is the catalog's own
/// `perks.welcome_offer`, shown with the source and the date the catalog was
/// last checked against it. An offer that has expired is never listed. A card
/// with no source or no check date is listed but marked, never presented as
/// confirmed. Pure Dart.
library;

import 'catalog.dart';

/// How well the catalog backs an offer.
enum OfferEvidence {
  /// The source is the bank's own page or terms.
  bank,

  /// The source is a comparison site, not the bank.
  aggregator,

  /// No source or no check date is on file.
  unverified,
}

/// Comparison and community sites: a source on one of these is never "bank".
const _aggregatorHosts = [
  'kredit.ae',
  'souqalmal.com',
  'yallacompare.com',
  'bankbazaar.ae',
  'bayut.com',
  'reddit.com',
  'moneyfit.ae',
  'wise.com',
];

/// Offers ending within this many days are flagged.
const offerEndingSoonDays = 14;

/// A bank page not re-read for this long is flagged for re-checking.
const offerStaleAfterDays = 45;

class WelcomeOffer {
  const WelcomeOffer({
    required this.card,
    required this.text,
    required this.evidence,
    this.valueAed,
    this.minSpendMinor,
    this.windowDays,
    this.requiresFeePayment = false,
    this.validUntil,
    this.daysLeft,
    this.sourceUrl,
    this.checkedOn,
    this.stale = false,
    this.lowConfidenceCard = false,
    this.comboIds = const [],
  });

  final CatalogCard card;

  /// The catalog's description of the bonus.
  final String text;

  /// The catalog's estimate of what the bonus is worth, in AED.
  final double? valueAed;
  final int? minSpendMinor;
  final int? windowDays;
  final bool requiresFeePayment;
  final DateTime? validUntil;

  /// Whole days until [validUntil] (0 = last day); null when no end date.
  final int? daysLeft;
  final String? sourceUrl;
  final DateTime? checkedOn;
  final OfferEvidence evidence;

  /// The check is older than [offerStaleAfterDays].
  final bool stale;

  /// The card's overall catalog confidence is "low".
  final bool lowConfidenceCard;

  /// Combos (by id) this card is part of.
  final List<String> comboIds;

  bool get endingSoon => daysLeft != null && daysLeft! <= offerEndingSoonDays;
}

bool _isAggregator(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return _aggregatorHosts.any((h) => host == h || host.endsWith('.$h'));
}

OfferEvidence offerEvidence(String? sourceUrl, DateTime? checkedOn) {
  if (sourceUrl == null || sourceUrl.isEmpty || checkedOn == null) {
    return OfferEvidence.unverified;
  }
  return _isAggregator(sourceUrl)
      ? OfferEvidence.aggregator
      : OfferEvidence.bank;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Every live welcome offer in [catalog], best estimated value first.
///
/// [comboCardIds] maps a combo id to the catalog ids it uses, so a card that
/// is part of a stack says so. Cards in [heldCatalogIds] are left out: a
/// welcome bonus is for a card you do not have yet.
List<WelcomeOffer> welcomeOffers(
  List<CatalogCard> catalog, {
  required DateTime now,
  Map<String, List<String>> comboCardIds = const {},
  Set<String> heldCatalogIds = const {},
}) {
  final today = _day(now);
  final out = <WelcomeOffer>[];
  for (final card in catalog) {
    if (heldCatalogIds.contains(card.id)) continue;
    final status = card.perks['status'];
    if (status == 'closed_to_new' || status == 'discontinued') continue;
    final raw = card.perks['welcome_offer'];
    if (raw is! Map) continue;
    final text = (raw['text'] as String?)?.trim();
    if (text == null || text.isEmpty) continue;

    final until = DateTime.tryParse('${raw['valid_until'] ?? ''}');
    int? daysLeft;
    if (until != null) {
      daysLeft = _day(until).difference(today).inDays;
      if (daysLeft < 0) continue; // expired: never listed
    }
    final checked = card.verifiedOn;
    out.add(
      WelcomeOffer(
        card: card,
        text: text,
        valueAed: (raw['value_aed_est'] as num?)?.toDouble(),
        minSpendMinor: (raw['min_spend_minor'] as num?)?.toInt(),
        windowDays: (raw['window_days'] as num?)?.toInt(),
        requiresFeePayment: raw['requires_fee_payment'] == true,
        validUntil: until,
        daysLeft: daysLeft,
        sourceUrl: card.source,
        checkedOn: checked,
        evidence: offerEvidence(card.source, checked),
        stale:
            checked != null &&
            today.difference(_day(checked)).inDays > offerStaleAfterDays,
        lowConfidenceCard: card.perks['confidence'] == 'low',
        comboIds: [
          for (final e in comboCardIds.entries)
            if (e.value.contains(card.id)) e.key,
        ],
      ),
    );
  }
  out.sort((a, b) {
    // Ending soonest first among those about to end, then by value.
    if (a.endingSoon != b.endingSoon) return a.endingSoon ? -1 : 1;
    if (a.endingSoon && b.endingSoon) {
      final r = a.daysLeft!.compareTo(b.daysLeft!);
      if (r != 0) return r;
    }
    final av = a.valueAed, bv = b.valueAed;
    if (av != bv) {
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    }
    return a.card.id.compareTo(b.card.id);
  });
  return out;
}

/// When to remind someone to apply before [deadline]: 09:00 a week before and
/// 09:00 the day before, keeping only moments still ahead of [now].
List<({DateTime at, int daysBefore})> offerReminderTimes(
  DateTime deadline,
  DateTime now,
) {
  final d = _day(deadline);
  return [
    for (final back in const [7, 1])
      if (DateTime(d.year, d.month, d.day - back, 9).isAfter(now))
        (at: DateTime(d.year, d.month, d.day - back, 9), daysBefore: back),
  ];
}
