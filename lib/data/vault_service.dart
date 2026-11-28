import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../core/analytics/analytics.dart';
import '../core/engine/investing.dart';
import '../core/engine/valuation.dart' show notificationIdFor;
import '../core/vault/emergency_sheet.dart';
import '../core/vault/input_guard.dart';
import '../core/vault/release.dart';
import '../core/vault/suggestions.dart';
import '../core/vault/vault_models.dart';
import 'local/attachments.dart';
import 'local/ids.dart';
import 'local/reminders.dart';
import 'local/vault_store.dart';
import 'models.dart';
import 'wealth_models.dart';

/// Thrown when free text looks like a secret. The message is shown as is.
class VaultGuardException implements Exception {
  const VaultGuardException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Everything the app already knows that could belong in the vault.
class VaultSourceData {
  const VaultSourceData({
    this.accounts = const [],
    this.cards = const [],
    this.assets = const [],
    this.funds = const [],
    this.recurring = const [],
    this.paydownGoals = const [],
    this.documents = const [],
    this.rules = const [],
  });
  final List<BankAccount> accounts;
  final List<CreditCard> cards;

  /// Includes liabilities (`Asset.isLiability`).
  final List<Asset> assets;
  final List<FundHolding> funds;

  /// (key, merchant, isSubscription) of confirmed recurring payments.
  final List<({String key, String merchant, bool isSubscription})> recurring;
  final List<({String id, String name})> paydownGoals;

  /// Wealth documents: title deeds, FD certificates, insurance, gold bills.
  final List<WealthDocument> documents;

  /// Standing buys and SIPs, so the family knows money leaves on a schedule.
  final List<InvestRule> rules;
}

VaultType vaultTypeForAsset(AssetKind k) => switch (k) {
  AssetKind.liability => VaultType.loan,
  AssetKind.realEstate => VaultType.property,
  AssetKind.fixedDeposit ||
  AssetKind.stocks ||
  AssetKind.funds ||
  AssetKind.gold => VaultType.investment,
  AssetKind.cash => VaultType.bank,
  AssetKind.other => VaultType.documents,
};

/// Maps the app's own data to vault sources. Pure, so it is tested directly.
List<VaultSource> sourcesFrom(VaultSourceData d) {
  final out = <VaultSource>[];
  for (final a in d.accounts) {
    if (a.kind == BankAccountKind.cash || a.kind == BankAccountKind.wallet)
      continue;
    out.add(
      VaultSource(
        ref: 'account:${a.id}',
        type: VaultType.bank,
        institution: a.bank,
        title: a.name,
        valueMinor: _minor(a.balance),
      ),
    );
  }
  for (final c in d.cards) {
    out.add(
      VaultSource(
        ref: 'card:${c.id}',
        type: VaultType.card,
        institution: c.issuer,
        title: c.name,
      ),
    );
  }
  for (final a in d.assets) {
    final type = vaultTypeForAsset(a.kind);
    out.add(
      VaultSource(
        ref: '${a.isLiability ? 'liability' : 'asset'}:${a.id}',
        type: type,
        institution: a.name,
        title: a.isLiability ? 'Amount owed' : a.kind.label,
        valueMinor: _minor(a.value),
      ),
    );
  }
  for (final f in d.funds) {
    out.add(
      VaultSource(
        ref: 'fund:${f.id}',
        type: VaultType.investment,
        institution: f.name,
        title: 'Fund',
      ),
    );
  }
  for (final r in d.recurring) {
    final t = typeFromRecurringMerchant(
      r.merchant,
      isSubscription: r.isSubscription,
    );
    if (t != null)
      out.add(
        VaultSource(
          ref: 'recurring:${r.key}',
          type: t,
          institution: r.merchant,
          title: 'Recurring payment',
        ),
      );
  }
  for (final doc in d.documents) {
    final type = switch (doc.category) {
      DocCategory.titleDeed => VaultType.property,
      DocCategory.fdCertificate => VaultType.investment,
      DocCategory.insurance => VaultType.insurance,
      _ => VaultType.documents,
    };
    out.add(
      VaultSource(
        ref: 'doc:${doc.id}',
        type: type,
        institution: doc.title,
        title: doc.category.label,
      ),
    );
  }
  for (final r in d.rules) {
    final amount =
        '${r.currency} ${(r.amountMinor / 100).toStringAsFixed(r.amountMinor % 100 == 0 ? 0 : 2)}';
    out.add(
      VaultSource(
        ref: 'rule:${r.id}',
        type: VaultType.investment,
        institution: r.label,
        title: 'Recurring buy · $amount ${r.cadenceLabel}',
      ),
    );
  }
  for (final g in d.paydownGoals) {
    out.add(
      VaultSource(
        ref: 'goal:${g.id}',
        type: VaultType.loan,
        institution: g.name,
        title: 'Pay-down goal',
      ),
    );
  }
  return out;
}

int _minor(double v) => (v * 100).round();

/// What the app knows, counted per type (raises the "typical" expectation).
Map<VaultType, int> trackedCounts(List<VaultSource> sources) {
  final m = <VaultType, int>{};
  for (final s in sources) {
    m[s.type] = (m[s.type] ?? 0) + 1;
  }
  return m;
}

class VaultService {
  VaultService({
    required this.store,
    required this.storage,
    required this.relay,
    required this.sources,
    this.reminders,
    this.analytics,
    DateTime Function()? clock,
    this.random,
  }) : _clock = clock ?? DateTime.now;

  final VaultStore store;
  final AttachmentStorage storage;
  final InactivityRelay relay;

  /// Phone notifications that warn the owner before a release. Local only:
  /// they work with no push service.
  final Reminders? reminders;
  final Future<VaultSourceData> Function() sources;
  final Analytics? analytics;
  final DateTime Function() _clock;
  final Random? random;

  static const _kInterval = 'vault.interval_days';
  static const _kLastCheckIn = 'vault.last_checkin';
  static const _kOwnerName = 'vault.owner_name';
  static String _kShare(String id) => 'vault.share1.$id';
  static String _kKit(String id) => 'vault.kit.$id';

  // ---- entries -----------------------------------------------------------

  Future<List<VaultEntry>> entries() => store.entries();

  Future<List<Nominee>> nominees() => store.nominees();

  static String? guardProblem(Iterable<String> texts) =>
      InputGuard.firstProblem(texts);

  /// Creates or updates an entry. Refuses secrets with [VaultGuardException].
  Future<VaultEntry> saveEntry(VaultEntry e) async {
    if (e.institution.trim().isEmpty)
      throw const VaultGuardException(
        'Say which bank, insurer or company it is.',
      );
    final problem = guardProblem([
      e.institution,
      e.title,
      e.whereToFind,
      e.nomineeName,
      e.contactPerson,
    ]);
    if (problem != null) throw VaultGuardException(problem);
    final isNew = !(await store.entries()).any((x) => x.id == e.id);
    final saved = await store.saveEntry(
      e.copyWith(updatedAt: _clock().toUtc()),
    );
    if (isNew) analytics?.track(AnalyticsEvent.vaultEntryAdded(e.type.key));
    return saved;
  }

  VaultEntry blank(VaultType type) {
    final now = _clock().toUtc();
    return VaultEntry(
      id: newId(),
      type: type,
      institution: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> deleteEntry(String id) async {
    final all = await store.entries();
    final e = all.where((x) => x.id == id).firstOrNull;
    await store.deleteEntry(id);
    if (e != null) await storage.delete(e.photoPaths);
    // A person who could see only some things no longer lists the removed one.
    for (final n in await store.nominees()) {
      if (n.entryIds != null && n.entryIds!.contains(id)) {
        await store.saveNominee(
          n.copyWith(entryIds: {...n.entryIds!}..remove(id)),
        );
      }
    }
  }

  Future<String> addPhoto(String sourcePath) => storage.import(sourcePath);

  Future<void> removePhotos(Iterable<String> paths) => storage.delete(paths);

  /// A paper's content (decrypted), or null when the file is gone.
  Future<Uint8List?> readFile(String path) => storage.read(path);

  // ---- suggestions & score -----------------------------------------------

  Future<List<VaultSource>> allSources() async => sourcesFrom(await sources());

  Future<List<VaultSource>> suggestions() async =>
      suggestEntries(await allSources(), await store.entries());

  /// Adds the chosen suggestions as entries; returns how many.
  Future<int> addSuggestions(List<VaultSource> chosen) async {
    var n = 0;
    final now = _clock().toUtc();
    for (final s in chosen) {
      final e = VaultEntry(
        id: newId(),
        type: s.type,
        institution: s.institution,
        title: s.title,
        estimatedValueMinor: s.type == VaultType.loan ? null : s.valueMinor,
        sourceRef: s.ref,
        createdAt: now,
        updatedAt: now,
      );
      await saveEntry(e);
      n++;
    }
    return n;
  }

  Future<Completeness> score() async => completeness(
    await store.entries(),
    tracked: trackedCounts(await allSources()),
  );

  // ---- nominees ---------------------------------------------------------

  Nominee blankNominee() =>
      Nominee(id: newId(), name: '', createdAt: _clock().toUtc());

  Future<Nominee> saveNominee(Nominee n) async {
    if (n.name.trim().isEmpty)
      throw const VaultGuardException('Add their name.');
    final problem = guardProblem([n.name, n.relationship, n.contact]);
    if (problem != null) throw VaultGuardException(problem);
    return store.saveNominee(n);
  }

  Future<void> deleteNominee(String id) async {
    await store.deleteNominee(id);
    await store.removeSetting(_kShare(id));
    await store.removeSetting(_kKit(id));
    await relay.disarm(id);
  }

  // ---- settings & check-in ---------------------------------------------

  Future<String> ownerName() async => await store.setting(_kOwnerName) ?? '';
  Future<void> setOwnerName(String v) =>
      store.putSetting(_kOwnerName, v.trim());

  Future<int> intervalDays() async =>
      int.tryParse(await store.setting(_kInterval) ?? '') ?? defaultCheckInDays;

  Future<void> setIntervalDays(int days) async {
    await store.putSetting(_kInterval, '$days');
    await scheduleOwnerWarnings();
    try {
      await relay.setInterval(days);
    } on Object {
      // Offline: the next check-in's server call carries on with the old
      // interval until this is changed again; the local timer already follows
      // the new one.
    }
  }

  Future<DateTime?> lastCheckIn() async =>
      DateTime.tryParse(await store.setting(_kLastCheckIn) ?? '');

  /// Opening the app is the check-in. Called on start and resume.
  Future<void> checkIn() async {
    final now = _clock().toUtc();
    await store.putSetting(_kLastCheckIn, now.toIso8601String());
    // Local warnings first: they must not depend on the network.
    await scheduleOwnerWarnings();
    await relay.heartbeat(now);
  }

  /// Local warnings that a file will be shared soon, rescheduled on every
  /// check-in (opening the app pushes them out again). Needs a sealed file to
  /// exist; one 14 days before the release date and one the day before.
  Future<void> scheduleOwnerWarnings() async {
    final r = reminders;
    if (r == null) return;
    final soon = notificationIdFor('vault-release:soon');
    final last = notificationIdFor('vault-release:last');
    await r.cancel(soon);
    await r.cancel(last);
    var sealed = false;
    for (final n in await store.nominees()) {
      if (await kitCreatedAt(n.id) != null) sealed = true;
    }
    if (!sealed) return;
    final st = await status();
    final now = _clock();
    final heads = st.releaseAt.subtract(
      const Duration(days: reminderWindowDays),
    );
    final eve = st.releaseAt.subtract(const Duration(days: 1));
    if (heads.isAfter(now)) {
      await r.schedule(
        id: soon,
        title: 'Open Pulse to keep your family vault private',
        body:
            'Your vault will be shared with a trusted person in $reminderWindowDays days unless you open Pulse.',
        at: heads,
      );
    }
    if (eve.isAfter(now)) {
      await r.schedule(
        id: last,
        title: 'Your family vault is shared tomorrow',
        body: 'Open Pulse today to keep it private.',
        at: eve,
      );
    }
  }

  Future<CheckInStatus> status() async {
    final last = await lastCheckIn() ?? _clock().toUtc();
    return checkInStatus(
      lastCheckIn: last,
      intervalDays: await intervalDays(),
      now: _clock().toUtc(),
    );
  }

  // ---- export ---------------------------------------------------------------

  Future<String> sheetText({Nominee? forNominee}) async => emergencySheet(
    ownerName: await ownerName(),
    entries: await store.entries(),
    forNominee: forNominee,
    now: _clock(),
  );

  void noteExported(String kind) =>
      analytics?.track(AnalyticsEvent.vaultExported(kind));

  /// Seals what [nominee] may see and arms the relay (a no-op until a server
  /// exists). The owner's share stays on this phone; the rest is shown once.
  Future<ReleaseKit> createKit(Nominee nominee) async {
    final kit = await VaultSeal.createKit(
      ownerName: await ownerName(),
      nominee: nominee,
      entries: await store.entries(),
      now: _clock(),
      random: random,
      readPaper: storage.read,
    );
    await store.putSetting(_kShare(nominee.id), kit.ownerShare);
    await store.putSetting(
      _kKit(nominee.id),
      kit.createdAt.toUtc().toIso8601String(),
    );
    var armed = false;
    try {
      await relay.arm(
        nomineeId: nominee.id,
        sealedFile: kit.sealedFile,
        claimCodeHash: kit.claimCodeHash,
        intervalDays: await intervalDays(),
        now: _clock().toUtc(),
      );
      armed = relay.isAvailable;
    } on Object {
      armed = false; // offline or server down: the owner hands the file over
    }
    noteExported('sealed');
    try {
      await scheduleOwnerWarnings();
    } on Object {
      // Notifications are a courtesy; sealing must not fail because of them.
    }
    return kit.withRelayArmed(armed);
  }

  Future<DateTime?> kitCreatedAt(String nomineeId) async =>
      DateTime.tryParse(await store.setting(_kKit(nomineeId)) ?? '');

  Future<bool> holdsOwnerShare(String nomineeId) async =>
      (await store.setting(_kShare(nomineeId))) != null;

  /// The owner's own share, for the owner to copy into a safe place.
  Future<String?> ownerShare(String nomineeId) =>
      store.setting(_kShare(nomineeId));

  /// Convenience for the UI.
  static List<String> photosOf(String json) {
    try {
      return [for (final p in jsonDecode(json) as List) p as String];
    } catch (_) {
      return const [];
    }
  }
}
