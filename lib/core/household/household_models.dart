/// Household planning: who owns what, and what a household can see.
///
/// Pure data, no I/O. Money is integer minor units (fils) like the ledger.
library;

/// Who an item belongs to, as the local database stores it.
///
/// * `me` - the person holding this phone (the default for everything);
/// * `shared` - the household's, joint;
/// * anything else - another member's id (a partner, a child).
///
/// Inside the household log (and in the engine) `me` is always replaced by
/// the member's real id, so an owner means the same thing on every phone.
abstract final class Owner {
  static const me = 'me';
  static const shared = 'shared';

  /// The absolute form of a locally stored owner.
  static String absolute(String local, String myId) =>
      local == me ? myId : local;

  /// The local form of an absolute owner, as seen from [myId].
  static String local(String abs, String myId) => abs == myId ? me : abs;
}

class HMember {
  const HMember({required this.id, required this.name, this.joinedAt});
  final String id;
  final String name;
  final DateTime? joinedAt;
}

/// The one household this phone belongs to.
class HouseholdConfig {
  const HouseholdConfig({
    required this.id,
    required this.name,
    required this.myMemberId,
    this.shareMine = true,
    required this.createdAt,
  });

  /// Random, names the shared log (`household/<id>/...`).
  final String id;
  final String name;
  final String myMemberId;

  /// Whether my own (non-private) items are visible to the household. Items
  /// marked Private are never visible, whatever this says.
  final bool shareMine;
  final DateTime createdAt;

  HouseholdConfig copyWith({String? name, bool? shareMine}) => HouseholdConfig(
    id: id,
    name: name ?? this.name,
    myMemberId: myMemberId,
    shareMine: shareMine ?? this.shareMine,
    createdAt: createdAt,
  );
}

/// A recurring due split between members.
class HBill {
  const HBill({
    required this.id,
    required this.name,
    required this.amountMinor,
    this.currency = 'AED',
    required this.dueDay,
    this.categoryId,
    required this.split,
  });
  final String id, name;
  final int amountMinor;
  final String currency;

  /// Day of the month (1-28; shorter months clamp).
  final int dueDay;
  final String? categoryId;

  /// member id -> share in basis points (sums to 10000).
  final Map<String, int> split;
}

/// A joint monthly limit on a category.
class HLimit {
  const HLimit({
    required this.id,
    required this.categoryId,
    required this.limitMinor,
    this.currency = 'AED',
  });
  final String id, categoryId;
  final int limitMinor;
  final String currency;
}

/// A transaction as the household engine sees it. [owner] is absolute.
class HTx {
  const HTx({
    required this.id,
    required this.owner,
    this.isPrivate = false,
    this.categoryId,
    required this.amountMinor,
    this.currency = 'AED',
    required this.isDebit,
    required this.postedAt,
    this.excluded = false,
    this.merchant = '',
  });
  final String id, owner, merchant;
  final bool isPrivate, isDebit, excluded;
  final String? categoryId;
  final int amountMinor;
  final String currency;
  final DateTime postedAt;
}

/// One line of net worth: an account, an asset, a loan or a card balance.
class HLine {
  const HLine({
    required this.id,
    required this.name,
    required this.isLiability,
    required this.valueMinor,
    this.currency = 'AED',
    required this.owner,
    this.isPrivate = false,
  });
  final String id, name, currency, owner;
  final bool isLiability, isPrivate;

  /// Always positive.
  final int valueMinor;
}

class HGoal {
  const HGoal({
    required this.id,
    required this.name,
    required this.targetMinor,
    required this.currentMinor,
    required this.progressBps,
    this.kind = 'save',
    this.iconKey,
    this.targetDate,
    this.paused = false,
    required this.owner,
    this.isPrivate = false,
  });
  final String id, name, kind, owner;
  final String? iconKey, targetDate;

  /// Save: the amount to reach and what is there. Pay down: the balance to
  /// reach and what is still owed.
  final int targetMinor, currentMinor;

  /// 0..10000, worked out on the phone that owns the goal.
  final int progressBps;
  final bool paused, isPrivate;

  double get progress => (progressBps / 10000).clamp(0.0, 1.0);
}
