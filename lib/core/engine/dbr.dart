/// Debt Burden Ratio (DBR) and total credit capacity (pure, all in fils).
///
/// What is official and what is not:
///
/// * VERIFIED. The Central Bank of the UAE caps the DBR at 50 percent of
///   gross salary and any regular income from a defined and specific source.
///   Source: CBUAE Rulebook, "Regulations Regarding Mortgage Loans"
///   (Circular No. 31/2013), Article 3.1 and 3.4 ("the DBR cannot exceed
///   50%"), which refers to the regulation on loans for individual customers
///   for the same figure. Article 1.4 defines DBR as "ratio of debt burden to
///   income". Article 2.3 says lenders must count other debt servicing
///   including credit card debt. https://rulebook.centralbank.ae/en/rulebook/article-3-important-ratios
///   Lenders are told not to apply the maximum automatically, so being under
///   the cap does not guarantee approval.
/// * NOT VERIFIED. The share of a card limit that counts as a monthly
///   obligation. The CBUAE pages read for this feature do not state a
///   percentage. 5 percent is a widely quoted bank practice, so it is only a
///   default for an estimate, shown to the user as such, and each bank may
///   differ. Change [cardShareOfLimitPct] only with an official source.
library;

import 'dart:math' as math;

/// CBUAE cap, percent of gross monthly income. Circular 31/2013 Art. 3.1, 3.4.
const dbrMaxPct = 50.0;

/// Estimate only (see library docs): monthly obligation per card, as a
/// percent of its limit.
const cardShareOfLimitPct = 5.0;

class DbrCard {
  const DbrCard({required this.name, required this.limitMinor});
  final String name;
  final int limitMinor;
}

enum DbrLevel { unknown, healthy, tight, over }

class DbrCardShare {
  const DbrCardShare(this.name, this.limitMinor, this.sharePct);
  final String name;
  final int limitMinor;

  /// This card's part of the total limit, 0 to 100.
  final double sharePct;
}

class DbrReport {
  const DbrReport({
    required this.totalLimitMinor,
    required this.cards,
    required this.cardObligationMinor,
    required this.loanObligationMinor,
    required this.salaryMinor,
    required this.dbrPct,
    required this.headroomMinor,
    required this.extraCardLimitMinor,
    required this.level,
  });

  final int totalLimitMinor;
  final List<DbrCardShare> cards;

  /// Monthly obligation the cards add (estimate).
  final int cardObligationMinor;
  final int loanObligationMinor;
  final int? salaryMinor;

  /// Total obligations as a percent of income; null without a salary.
  final double? dbrPct;

  /// Monthly obligation still available under the cap (negative when over).
  final int? headroomMinor;

  /// Extra card limit that fits in the headroom (0 when none).
  final int? extraCardLimitMinor;
  final DbrLevel level;
}

/// Warn from this much of the cap used.
const dbrTightPct = 40.0;

int cardObligationMinor(
  int limitMinor, {
  double sharePct = cardShareOfLimitPct,
}) => (limitMinor * sharePct / 100).round();

DbrReport computeDbr({
  required List<DbrCard> cards,
  int? salaryMinor,
  int loanEmisMinor = 0,
  double sharePct = cardShareOfLimitPct,
}) {
  final valid = [
    for (final c in cards)
      if (c.limitMinor > 0) c,
  ];
  final total = valid.fold<int>(0, (a, c) => a + c.limitMinor);
  final shares = [
    for (final c in valid)
      DbrCardShare(
        c.name,
        c.limitMinor,
        total == 0 ? 0 : c.limitMinor / total * 100,
      ),
  ]..sort((a, b) => b.limitMinor.compareTo(a.limitMinor));
  final cardOb = cardObligationMinor(total, sharePct: sharePct);
  final emis = math.max(0, loanEmisMinor);
  final hasSalary = salaryMinor != null && salaryMinor > 0;
  double? pct;
  int? headroom;
  int? extra;
  var level = DbrLevel.unknown;
  if (hasSalary) {
    pct = (cardOb + emis) / salaryMinor * 100;
    headroom = (salaryMinor * dbrMaxPct / 100).round() - cardOb - emis;
    extra = sharePct <= 0
        ? 0
        : math.max(0, (headroom * 100 / sharePct).floor());
    level = pct > dbrMaxPct
        ? DbrLevel.over
        : (pct >= dbrTightPct ? DbrLevel.tight : DbrLevel.healthy);
  }
  return DbrReport(
    totalLimitMinor: total,
    cards: shares,
    cardObligationMinor: cardOb,
    loanObligationMinor: emis,
    salaryMinor: hasSalary ? salaryMinor : null,
    dbrPct: pct == null ? null : (pct * 10).round() / 10,
    headroomMinor: headroom,
    extraCardLimitMinor: extra,
    level: level,
  );
}

/// Would a new card with [newLimitMinor] push the DBR over the cap? Null when
/// the salary is unknown.
bool? newCardBreaksCap(
  DbrReport r,
  int newLimitMinor, {
  double sharePct = cardShareOfLimitPct,
}) {
  final h = r.headroomMinor;
  if (h == null) return null;
  return cardObligationMinor(newLimitMinor, sharePct: sharePct) > h;
}
