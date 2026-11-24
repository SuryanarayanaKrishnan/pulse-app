import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/backup/backup_controller.dart';
import 'package:pulse/backup/backup_crypto.dart';
import 'package:pulse/backup/backup_engine.dart';
import 'package:pulse/backup/backup_format.dart';
import 'package:pulse/backup/backup_keystore.dart';
import 'package:pulse/backup/backup_provider.dart';
import 'package:pulse/backup/backup_state.dart';
import 'package:pulse/backup/key_envelope.dart';
import 'package:pulse/backup/recovery_phrase.dart';
import 'package:pulse/backup/restore_service.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/db_key.dart';
import 'package:pulse/data/local/open.dart';

import 'support.dart';

/// Old phone -> cloud -> new phone, with real encrypted database files.
void main() {
  late Directory root;
  late MemoryBackupProvider cloud;
  late String phrase;
  late RecordingAnalytics analytics;
  var now = DateTime.utc(2026, 6, 1, 9);

  Future<PulseDatabase> openAt(Directory dir, DatabaseKeyStore keys) =>
      openEncryptedDatabase(keys: keys, directory: dir, background: false);

  // The "old phone": data, backup.
  late Map<String, List<List<Object?>>> originalFingerprint;
  late List<File> originalFiles;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pulse_restore');
    cloud = MemoryBackupProvider(id: 'supabase', clock: () => now);
    analytics = RecordingAnalytics();
    phrase = RecoveryPhrase.generate().join(' ');
    final oldDir = Directory('${root.path}/old')..createSync();
    final oldDb = await openAt(oldDir, MemoryKeyStore());
    originalFiles = await populate(oldDb, oldDir, transactions: 300);
    originalFingerprint = await fingerprint(oldDb);
    final svc = await BackupService(
      db: oldDb,
      kv: MemoryKvStore(),
      keys: MemoryBackupKeyStore(),
      cloud: cloud,
      analytics: analytics,
      exportDir: () async => oldDir,
      kdf: KdfParams.testing,
      chunkSize: 2048,
      clock: () => now,
    ).load();
    await svc.enable(
      secret: phrase,
      secretKind: 'phrase',
      destination: BackupDestination.cloud,
    );
    expect(svc.state.lastError, isNull);
    await oldDb.close();
  });

  tearDown(() => root.delete(recursive: true));

  Future<
    ({
      DeviceRestoreHost host,
      Directory dir,
      MemoryKeyStore keys,
      PulseDatabase live,
      RestoreService svc,
      List<KeyEnvelope> adopted,
    })
  >
  newPhone() async {
    final dir = Directory('${root.path}/new')..createSync(recursive: true);
    final keys = MemoryKeyStore();
    final live = await openAt(dir, keys);
    final host = DeviceRestoreHost(
      supportDir: dir,
      attachmentsDir: Directory('${dir.path}/attachments'),
      keys: keys,
      live: live,
    );
    final adopted = <KeyEnvelope>[];
    final svc = RestoreService(
      host: host,
      analytics: analytics,
      adopt: (env, dk, dest) async {
        adopted.add(env);
        expect(dest, BackupDestination.cloud);
        expect(dk, hasLength(32));
      },
    );
    return (
      host: host,
      dir: dir,
      keys: keys,
      live: live,
      svc: svc,
      adopted: adopted,
    );
  }

  test('new phone restores everything, re-keys its own database, and keeps a safety copy', () async {
    final p = await newPhone();
    expect(
      await p.host.hasExistingData(),
      isFalse,
      reason: 'a fresh install has nothing to lose',
    );
    final oldKey = await p.keys.loadOrCreate();

    // recovery phrase typed in capitals with odd spacing still works
    final u = await p.svc.unlock(
      cloud,
      '  ${phrase.toUpperCase().replaceAll(' ', '  ')} ',
      source: 'cloud',
    );
    expect(u.versions, hasLength(1));
    final stats = await p.svc.restore(u, u.versions.first);
    expect(stats.attachments, 3);
    expect(p.adopted, hasLength(1));

    // The database file on disk is now a different encrypted database under a NEW key.
    final newKey = await p.keys.loadOrCreate();
    expect(newKey, isNot(oldKey));
    final reopened = await openAt(p.dir, p.keys);
    addTearDown(reopened.close);
    final restored = await fingerprint(reopened);
    expect(restored.keys, originalFingerprint.keys);
    expect(restored['transactions'], originalFingerprint['transactions']);
    expect(restored['accounts'], originalFingerprint['accounts']);
    expect(restored['app_settings'], originalFingerprint['app_settings']);
    // Photos came along and the rows point at them.
    final jewel = await reopened.select(reopened.jewelleryItems).getSingle();
    expect(jewel.photoPaths, contains('${p.dir.path}/attachments'));
    final restoredFiles = Directory('${p.dir.path}/attachments')
        .listSync()
        .whereType<File>()
        .toList();
    expect(restoredFiles, hasLength(3));
    expect(
      restoredFiles.map((f) => f.lengthSync()).toList()..sort(),
      originalFiles.map((f) => f.lengthSync()).toList()..sort(),
    );
    // The file is not readable with the old key.
    await expectLater(
      openAt(
        p.dir,
        MemoryKeyStore(oldKey),
      ).then((d) => d.select(d.accounts).get()),
      throwsA(anything),
    );
    expect(File('${p.dir.path}/pulse.db.before-restore').existsSync(), isTrue);
    expect(
      analytics.names,
      containsAll(['restore_started', 'restore_completed']),
    );
  });

  test('existing data on the phone is detected so the UI can ask before replacing it', () async {
    final p = await newPhone();
    await p.live
        .into(p.live.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'mine',
            type: 'bank',
            name: 'My account',
          ),
        );
    expect(await p.host.hasExistingData(), isTrue);
  });

  test(
    'wrong secret: nothing is touched, nothing is leaked about why',
    () async {
      final p = await newPhone();
      await expectLater(
        p.svc.unlock(cloud, 'wrong wrong wrong', source: 'cloud'),
        throwsA(isA<WrongPassphrase>()),
      );
      await expectLater(
        p.svc.unlock(
          cloud,
          RecoveryPhrase.generate().join(' '),
          source: 'cloud',
        ),
        throwsA(isA<WrongPassphrase>()),
      );
      expect(
        describeRestoreError(const WrongPassphrase()),
        contains('not right'),
      );
      expect(
        File('${p.dir.path}/pulse.db.before-restore').existsSync(),
        isFalse,
      );
    },
  );

  test('empty account: nothing found', () async {
    final p = await newPhone();
    await expectLater(
      p.svc.unlock(MemoryBackupProvider(), phrase, source: 'cloud'),
      throwsA(isA<NoBackupFound>()),
    );
  });

  test('a corrupt backup is rejected before the swap and the phone is exactly as it was', () async {
    final p = await newPhone();
    await p.live
        .into(p.live.accounts)
        .insert(
          AccountsCompanion.insert(id: 'mine', type: 'bank', name: 'Keep me'),
        );
    final u = await p.svc.unlock(cloud, phrase, source: 'cloud');
    final victim = cloud.objects.keys.firstWhere(
      (k) => k.startsWith('chunks/'),
    );
    cloud.objects[victim] = Uint8List.fromList(cloud.objects[victim]!)
      ..[30] ^= 1;
    await expectLater(
      p.svc.restore(u, u.versions.first),
      throwsA(isA<BackupIntegrityError>()),
    );
    expect(analytics.events.last.properties['reason'], 'corrupt');

    // live database untouched, leftovers cleaned
    expect((await p.live.select(p.live.accounts).getSingle()).name, 'Keep me');
    expect(File('${p.dir.path}/pulse.db.restore').existsSync(), isFalse);
    expect(File('${p.dir.path}/pulse.db.before-restore').existsSync(), isFalse);
    final att = Directory('${p.dir.path}/attachments');
    expect(
      att.existsSync() ? att.listSync() : [],
      isEmpty,
      reason: 'half-restored photos removed',
    );
    expect(p.adopted, isEmpty);
  });

  test(
    'a partial backup (missing chunk) is refused with a clear message',
    () async {
      final p = await newPhone();
      final u = await p.svc.unlock(cloud, phrase, source: 'cloud');
      cloud.objects.remove(
        cloud.objects.keys.firstWhere((k) => k.startsWith('chunks/')),
      );
      final err = await p.svc
          .restore(u, u.versions.first)
          .then<Object?>((_) => null, onError: (Object e) => e);
      expect(err, isA<BackupIncomplete>());
      expect(describeRestoreError(err!), contains('incomplete'));
      expect(File('${p.dir.path}/pulse.db.restore').existsSync(), isFalse);
    },
  );

  test('a damaged snapshot is skipped in the list and the older good one is offered', () async {
    // Second, later snapshot, then damage it.
    final dk = await (await BackupEngine.readEnvelope(cloud))!
        .unwrap(RecoveryPhrase.secretFrom(phrase));
    final db = memoryDb();
    addTearDown(db.close);
    now = now.add(const Duration(days: 1));
    await BackupEngine(
      provider: cloud,
      dataKey: dk,
      clock: () => now,
    ).backup(db: db);
    final newest =
        (cloud.objects.keys.where((k) => k.startsWith('manifests/')).toList()
              ..sort())
            .last;
    cloud.objects[newest] = Uint8List.fromList(cloud.objects[newest]!)
      ..[20] ^= 1;
    final p = await newPhone();
    final u = await p.svc.unlock(cloud, phrase, source: 'cloud');
    expect(u.versions, hasLength(1));
    expect(u.corrupt, 1);
  });

  test('a backup from a newer app is refused with an update message', () async {
    final p = await newPhone();
    final u = await p.svc.unlock(cloud, phrase, source: 'cloud');
    expect(describeRestoreError(const BackupTooNew()), contains('Update'));
    expect(
      u.versions.first.manifest.appSchemaVersion,
      PulseDatabase.currentSchemaVersion,
    );
  });
}
