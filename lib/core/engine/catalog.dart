/// The card catalog: a versioned document of card products and their reward
/// structures. It ships bundled as `assets/catalog/cards.json` and can be
/// replaced by a newer downloaded version (see `CatalogService`). Pure Dart.
library;

import 'card_art.dart';
import 'rewards.dart';

class CatalogCard {
  CatalogCard({
    required this.id,
    required this.issuer,
    required this.name,
    required this.network,
    required this.annualFeeMinor,
    required this.minSalaryMinor,
    required this.rewardStructure,
    required this.perks,
    this.verifiedOn,
    this.source,
  });

  /// Stable slug, e.g. `emirates-nbd-skywards-infinite`.
  final String id;
  final String issuer;
  final String name;
  final String? network;
  final int annualFeeMinor;
  final int? minSalaryMinor;
  final Map<String, Object?> rewardStructure;
  final Map<String, Object?> perks;

  /// When the figures were last checked against the issuer's published terms;
  /// null = unverified.
  final DateTime? verifiedOn;

  /// Where they were checked.
  final String? source;

  /// How the card looks: the catalog's own `art` (carried in `perks.art`),
  /// else the bundled art for this id; null for a product with neither.
  CardArtSpec? get art => artFromPerks(perks) ?? CardArts.byCatalogId[id];

  /// Reads `perks.art`; a malformed entry is ignored, never fatal.
  static CardArtSpec? artFromPerks(Map<String, Object?>? perks) {
    final a = perks?['art'];
    if (a is! Map) return null;
    try {
      return CardArtSpec.fromJson(Map<String, Object?>.from(a));
    } on Object {
      return null;
    }
  }

  bool get verified => verifiedOn != null;

  /// Parsed reward rules; throws [FormatException] for a malformed entry.
  CardSpec get spec => parseStructure(rewardStructure);

  factory CatalogCard.fromJson(Map<String, Object?> j) => CatalogCard(
    id: j['id']! as String,
    issuer: j['issuer']! as String,
    name: j['name']! as String,
    network: j['network'] as String?,
    annualFeeMinor: (j['annual_fee_minor'] as num?)?.toInt() ?? 0,
    minSalaryMinor: (j['min_salary_minor'] as num?)?.toInt(),
    rewardStructure: Map<String, Object?>.from(
      (j['reward_structure'] as Map?) ?? const {},
    ),
    perks: {
      ...Map<String, Object?>.from((j['perks'] as Map?) ?? const {}),
      // The backend catalog carries art at the top level of each card.
      if (j['art'] is Map) 'art': j['art'],
    },
    verifiedOn: j['verified_on'] == null
        ? null
        : DateTime.parse(j['verified_on']! as String),
    source: j['source'] as String?,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'issuer': issuer,
    'name': name,
    'network': network,
    'annual_fee_minor': annualFeeMinor,
    'min_salary_minor': minSalaryMinor,
    'reward_structure': rewardStructure,
    'perks': perks,
    'verified_on': verifiedOn?.toIso8601String().substring(0, 10),
    'source': source,
  };
}

class CardCatalog {
  const CardCatalog({
    required this.version,
    required this.updatedOn,
    required this.cards,
    this.notice,
  });
  final int version;
  final String updatedOn;
  final String? notice;
  final List<CatalogCard> cards;

  CatalogCard? byId(String id) {
    for (final c in cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Parses a catalog document. Entries whose reward structure is malformed
  /// are dropped, so one bad card never breaks the catalog.
  factory CardCatalog.fromJson(Map<String, Object?> j) {
    final cards = <CatalogCard>[];
    for (final c in (j['cards'] as List? ?? const [])) {
      try {
        final card = CatalogCard.fromJson(Map<String, Object?>.from(c as Map));
        card.spec;
        cards.add(card);
      } on Object {
        continue;
      }
    }
    return CardCatalog(
      version: (j['version'] as num?)?.toInt() ?? 0,
      updatedOn: (j['updated_on'] as String?) ?? '',
      notice: j['notice'] as String?,
      cards: cards,
    );
  }

  Map<String, Object?> toJson() => {
    'version': version,
    'updated_on': updatedOn,
    if (notice != null) 'notice': notice,
    'cards': [for (final c in cards) c.toJson()],
  };
}
