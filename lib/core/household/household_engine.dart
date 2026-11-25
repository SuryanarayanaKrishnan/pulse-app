/// Joint views for a household: net worth (mine or joint), spending by
/// member, the shared budget, shared goals and bill splits. Pure functions
/// over plain inputs; no storage, no Flutter.
///
/// Everything here takes absolute owners (a member id or `shared`). What a
/// phone passes in is what it can see: its own items (including Private
/// ones) and the mirror of what the other members chose to share. Joint
/// views drop Private items and, while [shareMine] is off, the caller's own.
library;

import '../engine/dates.dart';
import '../engine/networth.dart';
import 'household_models.dart';

/// Visible in a joint view: not Private, and mine only if I share mine.
bool visibleInJoint({
  required String owner,
  required bool isPrivate,
  required String me,
  required bool shareMine,
}) {
  if (isPrivate) return false;
  if (owner == me) return shareMine;
  return true;
}

/// Splits [total] by weights with no money lost or invented: largest
/// remainder, ties broken by key order. Weights must be positive overall.
Map<String, int> splitMinor(int total, Map<String, int> weights) {
  final keys = weights.keys.toList()..sort();
  final sum = keys.fold(0, (a, k) => a + weights[k]!);
  if (keys.isEmpty || sum <= 0) return {for (final k in keys) k: 0};
  final out = <String, int>{};
  final rem = <String, int>{};
  var given = 0;
  final sign = total < 0 ? -1 : 1;
  final abs = total.abs();
  for (final k in keys) {
    final share = abs * weights[k]!;
    out[k] = share ~/ sum;
    rem[k] = share % sum;
    given += out[k]!;
  }
  var left = abs - given;
  final order = [...keys]
    ..sort((a, b) {
      final c = rem[b]!.compareTo(rem[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  for (final k in order) {
    if (left == 0) break;
    out[k] = out[k]! + 1;
    left--;
  }
  return {for (final k in keys) k: out[k]! * sign};
}

/// Equal weights for [memberIds].
Map<String, int> equalSplit(Iterable<String> memberIds) => {
  for (final m in memberIds) m: 10000 ~/ memberIds.length,
};

// ---- net worth ----------------------------------------------------------------

enum NwScope { mine, joint }

class MemberNetWorth {
  const MemberNetWorth(this.owner, this.netMinor);

  /// A member id or `shared`.
  final String owner;
  final int netMinor;
}

class HouseholdNetWorth {
  const HouseholdNetWorth({
    required this.scope,
    required this.assetsMinor,
    required this.liabilitiesMinor,
    required this.byOwner,
    required this.lineCount,
    required this.unconverted,
  });
  final NwScope scope;
  final int assetsMinor, liabilitiesMinor;
  int get netMinor => assetsMinor - liabilitiesMinor;

  /// Joint only: net per owner, `shared` first, then members by id.
  final List<MemberNetWorth> byOwner;
  final int lineCount;
  final List<String> unconverted;
}

/// Net worth for the viewer [me].
///
/// * [NwScope.mine]: everything I own (Private included) plus my equal
///   share of what is shared.
/// * [NwScope.joint]: what is shared, plus every member's items that are not
///   Private (mine only while [shareMine] is on). My Private items are never
///   in it, so the number matches what the other phone shows.
HouseholdNetWorth householdNetWorth(
  Iterable<HLine> lines, {
  required NwScope scope,
  required String me,
  required Iterable<String> memberIds,
  bool shareMine = true,
}) {
  final members = {...memberIds, me}.toList()..sort();
  final assets = <AssetInput>[];
  final liabilities = <LiabilityInput>[];
  final perOwner = <String, int>{};
  var count = 0;

  void add(HLine l, int value, String bucket) {
    count++;
    if (l.isLiability) {
      liabilities.add(LiabilityInput('liability', l.currency, value));
    } else {
      assets.add(AssetInput('asset', l.currency, value));
    }
    // Per-owner buckets are in AED only (others are reported as unconverted).
    if (l.currency == 'AED') {
      perOwner[bucket] = (perOwner[bucket] ?? 0) + (l.isLiability ? -value : value);
    }
  }

  for (final l in lines) {
    if (scope == NwScope.mine) {
      if (l.owner == me) {
        add(l, l.valueMinor, me);
      } else if (l.owner == Owner.shared) {
        // my equal share, split without losing a fils
        final mine = splitMinor(l.valueMinor, {for (final m in members) m: 1})[me]!;
        add(l, mine, Owner.shared);
      }
    } else {
      if (!visibleInJoint(owner: l.owner, isPrivate: l.isPrivate, me: me, shareMine: shareMine)) {
        continue;
      }
      add(l, l.valueMinor, l.owner);
    }
  }
  final r = computeNetWorth(assets, liabilities);
  final owners = perOwner.keys.toList()
    ..sort((a, b) => a == Owner.shared ? -1 : (b == Owner.shared ? 1 : a.compareTo(b)));
  return HouseholdNetWorth(
    scope: scope,
    assetsMinor: r.totalAssetsMinor,
    liabilitiesMinor: r.totalLiabilitiesMinor,
    byOwner: [for (final o in owners) MemberNetWorth(o, perOwner[o]!)],
    lineCount: count,
    unconverted: r.unconvertedCurrencies,
  );
}

// ---- spending -----------------------------------------------------------------

bool _counts(HTx t, DateTime from, DateTime to, String me, bool shareMine) =>
    t.isDebit &&
    !t.excluded &&
    t.currency == 'AED' &&
    !t.postedAt.isBefore(from) &&
    t.postedAt.isBefore(to) &&
    visibleInJoint(owner: t.owner, isPrivate: t.isPrivate, me: me, shareMine: shareMine);

class MemberSpend {
  const MemberSpend(this.owner, this.spentMinor, this.count);

  /// A member id or `shared`.
  final String owner;
  final int spentMinor, count;
}

/// Spending in [from, to) per owner, biggest first. Private transactions
/// are left out, so a member's total is only what they chose to share.
List<MemberSpend> spendByMember(
  Iterable<HTx> txs, {
  required DateTime from,
  required DateTime to,
  required String me,
  bool shareMine = true,
}) {
  final spent = <String, int>{}, n = <String, int>{};
  for (final t in txs) {
    if (!_counts(t, from, to, me, shareMine)) continue;
    spent[t.owner] = (spent[t.owner] ?? 0) + t.amountMinor;
    n[t.owner] = (n[t.owner] ?? 0) + 1;
  }
  final out = [for (final k in spent.keys) MemberSpend(k, spent[k]!, n[k]!)]
    ..sort((a, b) {
      final c = b.spentMinor.compareTo(a.spentMinor);
      return c != 0 ? c : a.owner.compareTo(b.owner);
    });
  return out;
}

class JointBudgetLine {
  const JointBudgetLine({
    required this.limit,
    required this.spentMinor,
    required this.byOwner,
  });
  final HLimit limit;
  final int spentMinor;
  final Map<String, int> byOwner;

  int get remainingMinor => limit.limitMinor - spentMinor;
  double get progress => limit.limitMinor <= 0 ? (spentMinor > 0 ? 2 : 0) : spentMinor / limit.limitMinor;
}

class JointBudget {
  const JointBudget(this.lines);
  final List<JointBudgetLine> lines;
  int get plannedMinor => lines.fold(0, (a, l) => a + l.limit.limitMinor);
  int get spentMinor => lines.fold(0, (a, l) => a + l.spentMinor);
  int get remainingMinor => plannedMinor - spentMinor;
  double get progress => plannedMinor <= 0 ? 0 : spentMinor / plannedMinor;
}

/// The joint limits against what the household spent in those categories in
/// [month] (any member's visible spending counts, whoever paid).
JointBudget jointBudget(
  Iterable<HLimit> limits,
  Iterable<HTx> txs, {
  required DateTime month,
  required String me,
  bool shareMine = true,
}) {
  final from = DateTime.utc(month.year, month.month, 1);
  final to = DateTime.utc(month.year, month.month + 1, 1);
  final lines = <JointBudgetLine>[];
  for (final l in limits) {
    var spent = 0;
    final by = <String, int>{};
    for (final t in txs) {
      if (t.categoryId != l.categoryId || !_counts(t, from, to, me, shareMine)) continue;
      spent += t.amountMinor;
      by[t.owner] = (by[t.owner] ?? 0) + t.amountMinor;
    }
    lines.add(JointBudgetLine(limit: l, spentMinor: spent, byOwner: by));
  }
  lines.sort((a, b) => b.progress.compareTo(a.progress));
  return JointBudget(lines);
}

// ---- goals --------------------------------------------------------------------

/// Goals the household can see: shared ones first, then members' (never
/// Private ones).
List<HGoal> jointGoals(
  Iterable<HGoal> goals, {
  required String me,
  bool shareMine = true,
}) {
  final out = [
    for (final g in goals)
      if (visibleInJoint(owner: g.owner, isPrivate: g.isPrivate, me: me, shareMine: shareMine)) g,
  ]..sort((a, b) {
      final sa = a.owner == Owner.shared ? 0 : 1, sb = b.owner == Owner.shared ? 0 : 1;
      return sa != sb ? sa.compareTo(sb) : a.name.compareTo(b.name);
    });
  return out;
}

// ---- bills --------------------------------------------------------------------

/// Each member's share of one bill, summing exactly to the amount.
Map<String, int> billShares(HBill b) => splitMinor(b.amountMinor, b.split);

/// A split is valid when it has members and its weights are positive.
bool validSplit(Map<String, int> split) =>
    split.isNotEmpty && split.values.every((v) => v >= 0) && split.values.fold(0, (a, v) => a + v) > 0;

/// The next due date on or after [today] (day clamps to short months).
CalDate nextDue(HBill b, CalDate today) {
  CalDate inMonth(int y, int m) {
    final last = DateTime.utc(y, m + 1, 0).day;
    return CalDate(y, m, b.dueDay > last ? last : b.dueDay);
  }

  final thisMonth = inMonth(today.year, today.month);
  if (!(thisMonth < today)) return thisMonth;
  final d = DateTime.utc(today.year, today.month + 1, 1);
  return inMonth(d.year, d.month);
}

class BillDue {
  const BillDue(this.bill, this.due, this.daysAway, this.myShareMinor);
  final HBill bill;
  final CalDate due;
  final int daysAway, myShareMinor;
}

/// Bills ordered by next due date, with what I owe of each.
List<BillDue> upcomingBills(Iterable<HBill> bills, CalDate today, String me) {
  final out = [
    for (final b in bills)
      () {
        final d = nextDue(b, today);
        return BillDue(b, d, d.daysSince(today), billShares(b)[me] ?? 0);
      }(),
  ]..sort((a, b) => a.daysAway != b.daysAway ? a.daysAway.compareTo(b.daysAway) : a.bill.name.compareTo(b.bill.name));
  return out;
}

/// What I owe in total across bills each month.
int myMonthlyBills(Iterable<HBill> bills, String me) =>
    bills.fold(0, (a, b) => a + (billShares(b)[me] ?? 0));
