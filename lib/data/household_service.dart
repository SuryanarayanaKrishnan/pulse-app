import 'dart:async';
import 'dart:typed_data';

import '../backup/backup_crypto.dart';
import '../core/analytics/analytics.dart';
import '../core/household/household_bridge.dart';
import '../core/household/household_engine.dart';
import '../core/household/household_invite.dart';
import '../core/household/household_keys.dart';
import '../core/household/household_models.dart';
import '../core/household/household_rows.dart';
import '../core/household/household_scope.dart';
import '../core/household/household_store.dart';
import '../core/sync/sync_engine.dart';
import '../core/sync/sync_state.dart';
import '../core/sync/sync_transport.dart';

/// Everything a joint screen needs, with owners already in absolute form
/// (`me` replaced by this member's id) and the mirror merged in.
class JointData {
  const JointData({
    required this.config,
    required this.members,
    required this.txs,
    required this.lines,
    required this.goals,
    required this.bills,
    required this.limits,
  });
  final HouseholdConfig config;
  final List<HMember> members;
  final List<HTx> txs;
  final List<HLine> lines;
  final List<HGoal> goals;
  final List<HBill> bills;
  final List<HLimit> limits;

  String get me => config.myMemberId;
  bool get shareMine => config.shareMine;
  List<String> get memberIds => [for (final m in members) m.id];

  String nameOf(String owner) {
    if (owner == Owner.shared) return 'Shared';
    return members.where((m) => m.id == owner).firstOrNull?.name ?? 'Member';
  }

  HouseholdNetWorth netWorth(NwScope scope) => householdNetWorth(
    lines,
    scope: scope,
    me: me,
    memberIds: memberIds,
    shareMine: shareMine,
  );
}

/// What the Household screen shows about syncing.
class HouseholdStatus {
  const HouseholdStatus({this.running = false, this.lastSuccess, this.error, this.keyMissing = false});
  final bool running, keyMissing;
  final DateTime? lastSuccess;

  /// A calm sentence; null when the last run was fine.
  final String? error;
}

/// Creates, joins and leaves a household, keeps the shared log in sync and
/// builds the joint views. The protocol and its privacy gate are in
/// `core/household`; this only wires them to storage, the keystore and a
/// transport.
class HouseholdService {
  HouseholdService({
    required this.store,
    required this.keys,
    required this.analytics,
    this.transportFor,
    this.stateStoreFor,
    DateTime Function()? clock,
    String Function()? newId,
    int Function()? nowMs,
  }) : _clock = clock ?? DateTime.now,
       _newId = newId ?? (() => BackupCrypto.hex(BackupCrypto.randomBytes(8))),
       _nowMs = nowMs; // ignore: prefer_initializing_formals

  final HouseholdStore store;
  final HouseholdKeyStore keys;
  final Analytics analytics;

  /// Builds the transport for a household id; null: no network sharing in
  /// this build (demo data, web, not configured).
  final SyncTransport Function(String householdId)? transportFor;

  /// Where the log state is kept (a file beside the database in the app).
  final SyncStateStore Function(String householdId)? stateStoreFor;
  final DateTime Function() _clock;
  final String Function() _newId;
  final int Function()? _nowMs;

  final _status = StreamController<HouseholdStatus>.broadcast();
  HouseholdStatus _last = const HouseholdStatus();
  HouseholdStatus get status => _last;
  Stream<HouseholdStatus> get changes => _status.stream;

  void _emit(HouseholdStatus s) {
    _last = s;
    if (!_status.isClosed) _status.add(s);
  }

  void dispose() => _status.close();

  Future<HouseholdConfig?> config() => store.config();

  Future<List<HMember>> members() => store.members();

  // ---- create / join / leave -------------------------------------------------

  /// Starts a household with this phone as its first member.
  Future<HouseholdConfig> create({required String householdName, required String myName}) async {
    if (await store.config() != null) throw StateError('Already in a household');
    final id = BackupCrypto.hex(BackupCrypto.randomBytes(16));
    await keys.save(BackupCrypto.randomBytes(32));
    final cfg = await _enrol(id: id, name: householdName.trim().isEmpty ? 'Our household' : householdName.trim(), myName: myName);
    analytics.track(AnalyticsEvent.householdCreated);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
    return cfg;
  }

  /// Joins with an invite code. Throws [FormatException] for a bad code.
  Future<HouseholdConfig> join({required String code, required String myName}) async {
    if (await store.config() != null) throw StateError('Already in a household');
    final invite = HouseholdInvite.decode(code);
    await keys.save(invite.key);
    final cfg = await _enrol(id: invite.householdId, name: 'Our household', myName: myName);
    analytics.track(AnalyticsEvent.householdMemberJoined);
    // First sync pulls the log (the household's name and members) before
    // anything of mine is compared with it.
    try {
      await sync();
    } catch (_) {}
    return cfg;
  }

  Future<HouseholdConfig> _enrol({required String id, required String name, required String myName}) async {
    final me = _newId();
    final cfg = HouseholdConfig(id: id, name: name, myMemberId: me, createdAt: _clock().toUtc());
    await store.saveConfig(cfg);
    await store.saveMember(HMember(id: me, name: myName.trim().isEmpty ? 'Me' : myName.trim(), joinedAt: _clock().toUtc()));
    return cfg;
  }

  /// The code to show (as text and QR). Null when this phone has no key
  /// (restored from a backup): it needs a new invite.
  Future<String?> inviteCode() async {
    final cfg = await store.config();
    final key = await keys.load();
    if (cfg == null || key == null) return null;
    return HouseholdInvite(householdId: cfg.id, key: key).encode();
  }

  Future<bool> hasKey() async => (await keys.load()) != null;

  /// Stops sharing: my rows are withdrawn from the log (the others' copies
  /// of them are deleted), my membership is removed, and this phone forgets
  /// the household and its key. Everything of mine stays on this phone.
  ///
  /// It cannot take back what the others already saw, and it does not
  /// re-key the household: see `docs/HOUSEHOLD.md`.
  Future<void> leave() async {
    final cfg = await store.config();
    if (cfg == null) return;
    try {
      // One last sync with all my rows withdrawn and my membership gone, so
      // the others' mirrors drop what I shared.
      try {
        await _running; // let a run in progress finish first
      } catch (_) {}
      await store.deleteMember(cfg.myMemberId);
      await _sync(withdraw: true);
    } catch (_) {
      // Offline: leaving still works locally; the withdrawal could not be sent.
    }
    await store.clearAll();
    await keys.clear();
    final st = stateStoreFor?.call(cfg.id);
    if (st is ClearableStateStore) await st.clear();
    _emit(const HouseholdStatus());
  }

  Future<void> setShareMine(bool on) async {
    final cfg = await store.config();
    if (cfg == null) return;
    await store.saveConfig(cfg.copyWith(shareMine: on));
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  Future<void> rename(String name) async {
    final cfg = await store.config();
    if (cfg == null || name.trim().isEmpty) return;
    await store.saveConfig(cfg.copyWith(name: name.trim()));
  }

  // ---- ownership -----------------------------------------------------------------

  Future<Ownership> ownership(String table, String id) => store.ownership(table, id);

  Future<void> setOwnership(String table, String id, {String? owner, bool? isPrivate}) async {
    await store.setOwnership(table, id, owner: owner, isPrivate: isPrivate);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  // ---- bills and limits ----------------------------------------------------------

  Future<void> saveBill(HBill b) async {
    await store.saveBill(b);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  Future<void> deleteBill(String id) async {
    await store.deleteBill(id);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  Future<void> saveLimit(HLimit l) async {
    await store.saveLimit(l);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  Future<void> deleteLimit(String id) async {
    await store.deleteLimit(id);
    unawaited(sync().catchError((_) => const HouseholdSyncResult()));
  }

  String newRowId() => _newId();

  // ---- joint views --------------------------------------------------------------

  Future<JointData?> joint() async {
    final cfg = await store.config();
    if (cfg == null) return null;
    final me = cfg.myMemberId;
    final own = await store.ownRows();
    final mirror = await store.mirror();

    final txs = <HTx>[];
    final lines = <HLine>[];
    final goals = <HGoal>[];
    for (final r in own) {
      final owner = Owner.absolute(r.owner, me);
      final v = {...r.values, 'owner': owner, 'direction': r.values['direction'] ?? 'debit'};
      switch (r.table) {
        case HTable.transactions:
          if (txFromRow(r.id, v) case final t?) txs.add(_withPrivate(t, r.isPrivate));
        case HTable.lines:
          if (lineFromRow(r.id, v) case final l?) {
            lines.add(HLine(id: l.id, name: l.name, isLiability: l.isLiability, valueMinor: l.valueMinor, currency: l.currency, owner: owner, isPrivate: r.isPrivate));
          }
        case HTable.goals:
          if (goalFromRow(r.id, v) case final g?) {
            goals.add(HGoal(id: g.id, name: g.name, targetMinor: g.targetMinor, currentMinor: g.currentMinor, progressBps: g.progressBps, kind: g.kind, iconKey: g.iconKey, targetDate: g.targetDate, paused: g.paused, owner: owner, isPrivate: r.isPrivate));
          }
      }
    }
    // The mirror only ever holds what others chose to share (never Private).
    txs.addAll(mirrorOf(mirror, HTable.transactions, txFromRow));
    lines.addAll(mirrorOf(mirror, HTable.lines, lineFromRow));
    goals.addAll(mirrorOf(mirror, HTable.goals, goalFromRow));

    return JointData(
      config: cfg,
      members: await store.members(),
      txs: txs,
      lines: lines,
      goals: goals,
      bills: await store.bills(),
      limits: await store.limits(),
    );
  }

  static HTx _withPrivate(HTx t, bool p) => HTx(
    id: t.id,
    owner: t.owner,
    isPrivate: p,
    categoryId: t.categoryId,
    amountMinor: t.amountMinor,
    currency: t.currency,
    isDebit: t.isDebit,
    postedAt: t.postedAt,
    excluded: t.excluded,
    merchant: t.merchant,
  );

  // ---- sync -----------------------------------------------------------------------

  Future<HouseholdSyncResult>? _running;

  /// Runs one sync of the household log. Safe to call often; a call made
  /// while one runs joins it.
  Future<HouseholdSyncResult> sync() => _running ??= _sync().whenComplete(() => _running = null);

  Future<HouseholdSyncResult> _sync({bool withdraw = false}) async {
    final cfg = await store.config();
    if (cfg == null) return const HouseholdSyncResult();
    final key = await keys.load();
    if (key == null) {
      _emit(HouseholdStatus(keyMissing: true, lastSuccess: _last.lastSuccess));
      return const HouseholdSyncResult();
    }
    final tf = transportFor, sf = stateStoreFor;
    if (tf == null || sf == null) return const HouseholdSyncResult();
    _emit(HouseholdStatus(running: true, lastSuccess: _last.lastSuccess));
    try {
      final engine = SyncEngine(
        bridge: HouseholdBridge(StoreHouseholdSource(store, cfg, withdrawAll: withdraw)),
        transport: tf(cfg.id),
        store: sf(cfg.id),
        dataKey: Uint8List.fromList(key),
        namespace: householdNamespace(cfg.id),
        keyPurpose: householdKeyPurpose,
        nowMs: _nowMs,
      );
      final r = await engine.sync();
      _emit(HouseholdStatus(lastSuccess: _clock()));
      return HouseholdSyncResult(sent: r.pushedChanges, received: r.appliedChanges);
    } catch (e) {
      _emit(HouseholdStatus(lastSuccess: _last.lastSuccess, error: _message(e)));
      rethrow;
    }
  }

  static String _message(Object e) {
    if (e is SyncException && e.reason == 'integrity') {
      return 'Some shared data could not be verified, so it was not applied.';
    }
    if (e is SyncException && e.reason == 'too_new') {
      return 'Another member runs a newer version of Pulse. Update this one to keep sharing.';
    }
    if (e is SyncUnavailable || (e is SyncException && e.reason == 'signed_out')) {
      return 'Sign in to share with your household.';
    }
    final t = e.runtimeType.toString();
    if (t.contains('Socket') || t.contains('Timeout') || t.contains('ClientException') || t.contains('Handshake')) {
      return "You're offline. Changes are shared when you're back.";
    }
    return "Couldn't sync just now. Your data is safe on this phone.";
  }
}

class HouseholdSyncResult {
  const HouseholdSyncResult({this.sent = 0, this.received = 0});
  final int sent, received;
}

/// A state store that can be wiped when leaving.
abstract class ClearableStateStore implements SyncStateStore {
  Future<void> clear();
}
