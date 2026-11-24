/// Art direction for card products: what a card looks like, as data. Pure
/// Dart (colours are ARGB ints) so the catalog can carry it and a downloaded
/// catalog can override it. Rendered by `CardFace` in core/widgets.
///
/// Everything here is our own description of a look (colours, finish, a
/// motif); no issuer artwork or logo is used. Colours are from memory of the
/// real products and are approximations.
library;

enum CardFinish { matte, gloss, metal }

enum ChipStyle { gold, silver, dark }

enum CardMotif { none, waves, lines, dots, arcs, grid }

enum CardNetworkMark { visa, mastercard, amex }

class CardArtSpec {
  const CardArtSpec({
    required this.stops,
    required this.network,
    required this.bank,
    required this.tier,
    this.finish = CardFinish.gloss,
    this.accent = 0xFFFFFFFF,
    this.text = 0xFFFFFFFF,
    this.chip = ChipStyle.gold,
    this.contactless = true,
    this.motif = CardMotif.none,
  });

  /// Gradient stops, top-left to bottom-right (2 to 3 colours).
  final List<int> stops;
  final CardNetworkMark network;

  /// Bank name as set in the wordmark position (plain text, not a logo).
  final String bank;

  /// Tier label: Platinum, Signature, Infinite, World Elite, Titanium...
  final String tier;
  final CardFinish finish;

  /// Motif and highlight tint.
  final int accent;

  /// Foreground (numbers, names). Chosen for contrast against every stop.
  final int text;
  final ChipStyle chip;
  final bool contactless;
  final CardMotif motif;

  factory CardArtSpec.fromJson(Map<String, Object?> j) => CardArtSpec(
    stops: [for (final s in (j['stops']! as List)) (s as num).toInt()],
    network: CardNetworkMark.values.byName(j['network']! as String),
    bank: j['bank']! as String,
    tier: j['tier']! as String,
    finish: CardFinish.values.byName((j['finish'] as String?) ?? 'gloss'),
    accent: (j['accent'] as num?)?.toInt() ?? 0xFFFFFFFF,
    text: (j['text'] as num?)?.toInt() ?? 0xFFFFFFFF,
    chip: ChipStyle.values.byName((j['chip'] as String?) ?? 'gold'),
    contactless: (j['contactless'] as bool?) ?? true,
    motif: CardMotif.values.byName((j['motif'] as String?) ?? 'none'),
  );

  Map<String, Object?> toJson() => {
    'stops': stops,
    'network': network.name,
    'bank': bank,
    'tier': tier,
    'finish': finish.name,
    'accent': accent,
    'text': text,
    'chip': chip.name,
    'contactless': contactless,
    'motif': motif.name,
  };
}

/// Bundled art by catalog id. A catalog entry's own `art` overrides these.
class CardArts {
  const CardArts._();

  static const _v = CardNetworkMark.visa;
  static const _m = CardNetworkMark.mastercard;

  static const Map<String, CardArtSpec> byCatalogId = {
    // Black metal with Emirates gold; the Skywards Infinite is a Visa Infinite.
    'emirates-nbd-skywards-infinite': CardArtSpec(
      stops: [0xFF15171B, 0xFF2A2D33, 0xFF16181C],
      network: _v,
      bank: 'Emirates NBD',
      tier: 'Infinite',
      finish: CardFinish.metal,
      accent: 0xFFC9A45C,
      text: 0xFFF1E6C8,
      motif: CardMotif.lines,
    ),
    // Bright, young: warm orange into magenta.
    'emirates-nbd-go4it': CardArtSpec(
      stops: [0xFFB4290F, 0xFFC23A18, 0xFF8E1F63],
      network: _m,
      bank: 'Emirates NBD',
      tier: 'Platinum',
      accent: 0xFFFFC857,
      motif: CardMotif.dots,
    ),
    // Lulu green with a red band.
    'adcb-lulu-platinum': CardArtSpec(
      stops: [0xFF0B5A2E, 0xFF12783D, 0xFF0A4424],
      network: _v,
      bank: 'ADCB',
      tier: 'Platinum',
      accent: 0xFFE23B3B,
      motif: CardMotif.waves,
    ),
    // ADCB navy sliding into red.
    'adcb-touchpoints-platinum': CardArtSpec(
      stops: [0xFF0F1A3A, 0xFF2B2250, 0xFFB3123A],
      network: _v,
      bank: 'ADCB',
      tier: 'Platinum',
      accent: 0xFFFF8FA3,
      motif: CardMotif.arcs,
    ),
    // FAB deep navy with a teal glow.
    'first-abu-dhabi-bank-cashback-card': CardArtSpec(
      stops: [0xFF0A1F3F, 0xFF0F3B5C, 0xFF0B5560],
      network: _m,
      bank: 'FAB',
      tier: 'Cashback',
      accent: 0xFF5FD4C4,
      motif: CardMotif.waves,
    ),
    // Mashreq charcoal with its orange.
    'mashreq-cashback-credit-card': CardArtSpec(
      stops: [0xFF1B1D22, 0xFF2D2A2A, 0xFF8A3A0E],
      network: _v,
      bank: 'Mashreq',
      tier: 'Platinum',
      accent: 0xFFFF8A3D,
      motif: CardMotif.arcs,
    ),
    // Solitaire: black metal, Visa Infinite, platinum chip.
    'mashreq-solitaire': CardArtSpec(
      stops: [0xFF0B0C0E, 0xFF23262B, 0xFF0E0F12],
      network: _v,
      bank: 'Mashreq',
      tier: 'Infinite',
      finish: CardFinish.metal,
      accent: 0xFFD7DBE0,
      text: 0xFFE9ECEF,
      chip: ChipStyle.silver,
      motif: CardMotif.lines,
    ),
    // noon yellow with black type.
    'mashreq-noon-card': CardArtSpec(
      stops: [0xFFFFE62E, 0xFFFFD500, 0xFFF2C200],
      network: _v,
      bank: 'Mashreq',
      tier: 'Platinum',
      finish: CardFinish.matte,
      accent: 0xFF111111,
      text: 0xFF111111,
      chip: ChipStyle.dark,
      motif: CardMotif.dots,
    ),
    // DIB emerald with a gold edge.
    'dubai-islamic-bank-cashback-card': CardArtSpec(
      stops: [0xFF063B2B, 0xFF0B5A3F, 0xFF07382A],
      network: _v,
      bank: 'Dubai Islamic Bank',
      tier: 'Platinum',
      accent: 0xFFD4B35E,
      motif: CardMotif.grid,
    ),
    // Titanium: brushed grey metal, Mastercard Titanium, red accent.
    'rakbank-titanium-credit-card': CardArtSpec(
      stops: [0xFF4A4E54, 0xFF666B73, 0xFF42464C],
      network: _m,
      bank: 'RAKBANK',
      tier: 'Titanium',
      finish: CardFinish.metal,
      accent: 0xFFE53935,
      chip: ChipStyle.silver,
      motif: CardMotif.lines,
    ),
    // HSBC: black with a red hexagon feel (motif is our own arcs).
    'hsbc-cashback-credit-card': CardArtSpec(
      stops: [0xFF16161A, 0xFF26262B, 0xFF7A0F14],
      network: _v,
      bank: 'HSBC',
      tier: 'Platinum',
      finish: CardFinish.matte,
      accent: 0xFFE0242B,
      motif: CardMotif.arcs,
    ),
    // Emirates Islamic Skywards: Emirates red into dark maroon, gold accent.
    'emirates-islamic-skywards-platinum': CardArtSpec(
      stops: [0xFF8A0F1E, 0xFFB01428, 0xFF5E0A15],
      network: _v,
      bank: 'Emirates Islamic',
      tier: 'Platinum',
      accent: 0xFFE2C275,
      motif: CardMotif.waves,
    ),
    // Liv: a digital-bank gradient, teal to violet.
    'liv-liv-credit-card': CardArtSpec(
      stops: [0xFF0E7C86, 0xFF3A55C4, 0xFF7A3FC9],
      network: _v,
      bank: 'Liv',
      tier: 'Platinum',
      accent: 0xFFB8F2E6,
      chip: ChipStyle.silver,
      motif: CardMotif.waves,
    ),
    // Standard Chartered blue with its green.
    'standard-chartered-manhattan-rewards': CardArtSpec(
      stops: [0xFF0A2A66, 0xFF0B4DA2, 0xFF0A6BA8],
      network: _v,
      bank: 'Standard Chartered',
      tier: 'Platinum',
      accent: 0xFF3CCB5A,
      motif: CardMotif.arcs,
    ),
  };

  /// Ids the mock and API repositories use, mapped to catalog ids.
  static const Map<String, String> _aliases = {
    'enbd-sky': 'emirates-nbd-skywards-infinite',
    'enbd-go4it': 'emirates-nbd-go4it',
    'mashreq-cb': 'mashreq-cashback-credit-card',
    'fab-cb': 'first-abu-dhabi-bank-cashback-card',
    'adcb-tp': 'adcb-touchpoints-platinum',
    'liv-plat': 'liv-liv-credit-card',
    'mashreq-solaris': 'mashreq-solitaire',
  };

  static String _slug(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  /// Art for a card by its id, or by issuer and name; null when unknown (the
  /// face then derives a plain look from the card's own colours).
  static CardArtSpec? resolve({
    required String id,
    String? issuer,
    String? name,
  }) {
    final direct = byCatalogId[id] ?? byCatalogId[_aliases[id]];
    if (direct != null) return direct;
    if (issuer != null && name != null) {
      return byCatalogId[_slug('$issuer $name')];
    }
    return null;
  }
}
