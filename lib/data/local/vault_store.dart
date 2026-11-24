import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/vault/vault_models.dart';
import 'database.dart';

/// Storage for the family vault: the encrypted drift database, or memory
/// (demo data, web builds, tests). `setting`s are per-device and never sync:
/// the check-in time, the interval and the owner's key share live there.
abstract class VaultStore {
  Future<List<VaultEntry>> entries();
  Future<VaultEntry> saveEntry(VaultEntry e);

  /// Soft delete.
  Future<void> deleteEntry(String id);
  Future<List<Nominee>> nominees();
  Future<Nominee> saveNominee(Nominee n);
  Future<void> deleteNominee(String id);

  Future<String?> setting(String key);
  Future<void> putSetting(String key, String value);
  Future<void> removeSetting(String key);
}

List<String> _paths(String json) {
  try {
    return [for (final p in jsonDecode(json) as List) p as String];
  } catch (_) {
    return const [];
  }
}

class LocalVaultStore implements VaultStore {
  LocalVaultStore(this.db);
  final PulseDatabase db;

  @override
  Future<List<VaultEntry>> entries() async => [
    for (final r
        in await (db.select(db.vaultEntries)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get())
      VaultEntry(
        id: r.id,
        type: VaultType.fromKey(r.type),
        institution: r.institution,
        title: r.title,
        whereToFind: r.whereToFind,
        nomineeName: r.nomineeName,
        contactPerson: r.contactPerson,
        estimatedValueMinor: r.estimatedValueMinor,
        photoPaths: _paths(r.photoPaths),
        sourceRef: r.sourceRef,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      ),
  ];

  @override
  Future<VaultEntry> saveEntry(VaultEntry e) async {
    await db
        .into(db.vaultEntries)
        .insertOnConflictUpdate(
          VaultEntriesCompanion(
            id: Value(e.id),
            type: Value(e.type.key),
            institution: Value(e.institution),
            title: Value(e.title),
            whereToFind: Value(e.whereToFind),
            nomineeName: Value(e.nomineeName),
            contactPerson: Value(e.contactPerson),
            estimatedValueMinor: Value(e.estimatedValueMinor),
            photoPaths: Value(jsonEncode(e.photoPaths)),
            sourceRef: Value(e.sourceRef),
            createdAt: Value(e.createdAt),
            updatedAt: Value(e.updatedAt),
            deletedAt: const Value(null),
          ),
        );
    return e;
  }

  @override
  Future<void> deleteEntry(String id) =>
      (db.update(db.vaultEntries)..where((t) => t.id.equals(id))).write(
        VaultEntriesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  @override
  Future<List<Nominee>> nominees() async => [
    for (final r
        in await (db.select(db.vaultNominees)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
            .get())
      Nominee(
        id: r.id,
        name: r.name,
        relationship: r.relationship,
        contact: r.contact,
        entryIds: Nominee.parseEntryIds(r.entryIds),
        createdAt: r.createdAt,
      ),
  ];

  @override
  Future<Nominee> saveNominee(Nominee n) async {
    await db
        .into(db.vaultNominees)
        .insertOnConflictUpdate(
          VaultNomineesCompanion(
            id: Value(n.id),
            name: Value(n.name),
            relationship: Value(n.relationship),
            contact: Value(n.contact),
            entryIds: Value(n.entryIdsStored),
            createdAt: Value(n.createdAt),
            deletedAt: const Value(null),
          ),
        );
    return n;
  }

  @override
  Future<void> deleteNominee(String id) =>
      (db.update(db.vaultNominees)..where((t) => t.id.equals(id))).write(
        VaultNomineesCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );

  @override
  Future<String?> setting(String key) => db.setting(key);

  @override
  Future<void> putSetting(String key, String value) =>
      db.putSetting(key, value);

  @override
  Future<void> removeSetting(String key) =>
      (db.delete(db.appSettings)..where((t) => t.key.equals(key))).go();
}

class MemoryVaultStore implements VaultStore {
  MemoryVaultStore({
    List<VaultEntry> entries = const [],
    List<Nominee> nominees = const [],
  }) : _entries = {for (final e in entries) e.id: e},
       _nominees = {for (final n in nominees) n.id: n};

  final Map<String, VaultEntry> _entries;
  final Map<String, Nominee> _nominees;
  final Map<String, String> settings = {};

  @override
  Future<List<VaultEntry>> entries() async =>
      _entries.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<VaultEntry> saveEntry(VaultEntry e) async => _entries[e.id] = e;

  @override
  Future<void> deleteEntry(String id) async => _entries.remove(id);

  @override
  Future<List<Nominee>> nominees() async =>
      _nominees.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<Nominee> saveNominee(Nominee n) async => _nominees[n.id] = n;

  @override
  Future<void> deleteNominee(String id) async => _nominees.remove(id);

  @override
  Future<String?> setting(String key) async => settings[key];

  @override
  Future<void> putSetting(String key, String value) async =>
      settings[key] = value;

  @override
  Future<void> removeSetting(String key) async => settings.remove(key);
}
