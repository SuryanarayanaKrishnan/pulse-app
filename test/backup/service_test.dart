import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/backup/archive_file.dart';
import 'package:pulse/backup/backup_controller.dart';
import 'package:pulse/backup/backup_crypto.dart';
import 'package:pulse/backup/backup_engine.dart';
import 'package:pulse/backup/backup_keystore.dart';
import 'package:pulse/backup/backup_provider.dart';
import 'package:pulse/backup/backup_scheduler.dart';
import 'package:pulse/backup/backup_state.dart';
import 'package:pulse/backup/recovery_phrase.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/data/local/database.dart';
import 'package:drift/drift.dart' show Value;

import 'support.dart';

void main() {
  late Directory tmp;
  late PulseDatabase db;
  late MemoryBackupProvider cloud;
  late MemoryKvStore kv;
  late MemoryBackupKeyStore keys;
  late RecordingAnalytics analytics;
  var now = DateTime.utc(2026, 5, 1, 9);

  Future<BackupService> service({BackupProvider? provider, bool noCloud = false}) async => BackupService(
    db: db,
    kv: kv,
    keys: keys,
    cloud: noCloud ? null : (provider ?? cloud),
    analytics: analytics,
    exportDir: () async => Directory('${tmp.path}/exports'),
    kdf: KdfParams.testing,
    chunkSize: 2048,
    clock: () => now,
  ).load();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pulse_svc');
    db = memoryDb();
    cloud = MemoryBackupProvider(id: 'supabase', clock: () => now);
    kv = MemoryKvStore();
    keys = MemoryBackupKeyStore();
    analytics = RecordingAnalytics();
    now = DateTime.utc(2026, 5, 1, 9);
    await populate(db, tmp, transactions: 50);
  });
  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('enable: key envelope and first backup land in the cloud, keys stay on the phone', () async {
    final svc = await service();
    final phrase = RecoveryPhrase.generate().join(' ');
    await svc.enable(secret: phrase, secretKind: 'phrase', destination: BackupDestination.cloud);
    expect(svc.state.enabled, isTrue);
    expect(svc.state.lastSuccess, now);
    expect(svc.state.lastError, isNull);
    expect(cloud.objects.keys, containsAll(['key.json']));
    expect(cloud.objects.keys.where((k) => k.startsWith('manifests/')), hasLength(1));
    // The phrase and the data key appear nowhere in what the server holds.
    final all = cloud.objects.values.map((b) => latin1.decode(b)).join();
    expect(all, isNot(contains(phrase.split(' ').first + ' ')));
    final dk = await keys.load();
    expect(dk, isNotNull);
    expect(all.contains(base64.encode(dk!)), isFalse);
    expect(analytics.names, containsAll(['backup_enabled', 'backup_completed']));
    // Analytics carries no personal data.
    for (final e in analytics.events) {
      expect(jsonEncode(e.properties), isNot(contains(phrase.split(' ').first)));
    }
  });

  test('settings and "last backed up" survive a restart', () async {
    var svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    await svc.setWifiOnly(false);
    now = now.add(const Duration(hours: 3));
    svc.dispose();
    svc = await service();
    expect(svc.state.enabled, isTrue);
    expect(svc.state.wifiOnly, isFalse);
    expect(backedUpAgo(svc.state.lastSuccess, now), 'Last backed up 3 hours ago');
  });

  test('a failed backup is calm, counted, and recovers on the next success', () async {
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    cloud.failWith = const SocketException('offline');
    now = now.add(const Duration(hours: 1));
    expect(await svc.backupNow(), isNull);
    expect(svc.state.lastError, contains('No connection'));
    expect(svc.state.lastError, isNot(contains('SocketException')));
    expect(svc.state.failures, 1);
    expect(svc.state.running, isFalse);
    expect(svc.state.needsAttention(now), isFalse, reason: 'one failure is not worth alarming anyone');
    for (var i = 0; i < 2; i++) {
      await svc.backupNow();
    }
    expect(svc.state.needsAttention(now), isTrue);
    cloud.failWith = null;
    expect(await svc.backupNow(), isNotNull);
    expect(svc.state.lastError, isNull);
    expect(svc.state.failures, 0);
    expect(analytics.events.where((e) => e.name == 'backup_failed').first.properties['reason'], 'offline');
  });

  test('concurrent backupNow calls share one run', () async {
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    final before = analytics.events.where((e) => e.name == 'backup_completed').length;
    await Future.wait([svc.backupNow(), svc.backupNow(), svc.backupNow()]);
    expect(analytics.events.where((e) => e.name == 'backup_completed').length, before + 1);
  });

  test('enabling over an existing cloud backup asks first and never overwrites silently', () async {
    final first = await service();
    await first.enable(secret: 'first passphrase 1', secretKind: 'passphrase', destination: BackupDestination.cloud);
    final manifestsBefore = cloud.objects.keys.where((k) => k.startsWith('manifests/')).toList();

    keys = MemoryBackupKeyStore();
    kv = MemoryKvStore();
    final second = await service();
    await expectLater(
      second.enable(secret: 'second passphrase 2', secretKind: 'passphrase', destination: BackupDestination.cloud),
      throwsA(isA<BackupAlreadyExists>()),
    );
    expect(cloud.objects.keys.where((k) => k.startsWith('manifests/')), manifestsBefore);
    await second.enable(
      secret: 'second passphrase 2',
      secretKind: 'passphrase',
      destination: BackupDestination.cloud,
      replaceExisting: true,
    );
    expect(cloud.objects.keys.where((k) => k.startsWith('manifests/')).length, 1);
  });

  test('change passphrase re-wraps the data key: old backups open with the new one only', () async {
    final svc = await service();
    await svc.enable(secret: 'old passphrase 123', secretKind: 'passphrase', destination: BackupDestination.cloud);
    final chunksBefore = cloud.objects.keys.where((k) => k.startsWith('chunks/')).toSet();
    await expectLater(
      svc.changePassphrase(current: 'not my passphrase', next: 'brand new passphrase', nextKind: 'passphrase'),
      throwsA(isA<WrongPassphrase>()),
    );
    await svc.changePassphrase(current: 'old passphrase 123', next: 'brand new passphrase', nextKind: 'passphrase');
    expect(cloud.objects.keys.where((k) => k.startsWith('chunks/')).toSet(), chunksBefore, reason: 'no re-upload');
    final env = (await BackupEngine.readEnvelope(cloud))!;
    await expectLater(env.unwrap('old passphrase 123'), throwsA(isA<WrongPassphrase>()));
    final dk = await env.unwrap('brand new passphrase');
    expect(dk, await keys.load());
    expect(await BackupEngine(provider: cloud, dataKey: dk).versions(), hasLength(1));
  });

  test('export produces a self-contained encrypted file that unlocks with the same secret', () async {
    final svc = await service(noCloud: true);
    await svc.enable(secret: 'file only passphrase', secretKind: 'passphrase', destination: BackupDestination.file);
    expect(await svc.backupNow(), isNull, reason: 'file-only never uploads');
    final path = await svc.exportArchive();
    expect(path, endsWith('.$archiveExtension'));
    final reader = await ArchiveReaderProvider.open(path);
    final env = (await BackupEngine.readEnvelope(reader))!;
    final dk = await env.unwrap('file only passphrase');
    final v = await BackupEngine(provider: reader, dataKey: dk).versions();
    expect(v.single.manifest.rowCount, greaterThan(50));
    expect(analytics.names, contains('backup_exported'));
  });

  test('delete cloud backup removes every object and turns backup off', () async {
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    await svc.deleteCloudBackup();
    expect(cloud.objects, isEmpty);
    expect(svc.state.enabled, isFalse);
    expect(await keys.load(), isNull);
  });

  test('switching a file-only backup to the cloud publishes the same key, and refuses a different lineage', () async {
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.file);
    await svc.setDestination(BackupDestination.cloud);
    expect(cloud.objects.containsKey('key.json'), isTrue);
    await svc.setDestination(BackupDestination.file);

    // Someone else's backup in the account.
    final other = MemoryBackupProvider();
    final otherSvc = BackupService(
      db: db,
      kv: MemoryKvStore(),
      keys: MemoryBackupKeyStore(),
      cloud: other,
      analytics: analytics,
      exportDir: () async => tmp,
      kdf: KdfParams.testing,
    );
    await otherSvc.enable(secret: 'a different passphrase', secretKind: 'passphrase', destination: BackupDestination.cloud);
    cloud.objects['key.json'] = other.objects['key.json']!;
    await expectLater(svc.setDestination(BackupDestination.cloud), throwsA(isA<BackupAlreadyExists>()));
  });

  test('missing keys on the phone are reported plainly, not as a crash', () async {
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    await keys.clear();
    expect(await svc.backupNow(), isNull);
    expect(svc.state.lastError, contains('backup key'));
  });

  group('scheduler', () {
    Future<(BackupService, BackupScheduler)> rig({bool wifi = true, Duration debounce = const Duration(milliseconds: 60)}) async {
      final svc = await service();
      await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
      final s = BackupScheduler(
        service: svc,
        db: db,
        debounce: debounce,
        retryBase: const Duration(hours: 1),
        isUnmetered: () async => wifi,
        networkChanges: const Stream<void>.empty(),
        clock: () => now,
      )..start();
      addTearDown(s.dispose);
      return (svc, s);
    }

    int completed() => analytics.events.where((e) => e.name == 'backup_completed').length;

    test('a burst of changes causes exactly one backup after the quiet period', () async {
      final (svc, _) = await rig();
      final base = completed();
      for (var i = 0; i < 5; i++) {
        await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'x$i', type: 'cash', name: 'Cash $i'));
        await Future<void>.delayed(const Duration(milliseconds: 15));
      }
      expect(svc.state.dirty, isTrue);
      expect(completed(), base, reason: 'still inside the debounce window');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(completed(), base + 1);
      expect(svc.state.dirty, isFalse);
    });

    test('cache-only writes (prices, settings) do not trigger anything', () async {
      final (svc, _) = await rig();
      final base = completed();
      await db.putSetting('theme', 'light');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(completed(), base);
      expect(svc.state.dirty, isFalse);
    });

    test('on a metered network with Wi-Fi only on, the change waits', () async {
      final (svc, _) = await rig(wifi: false);
      final base = completed();
      await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'y', type: 'cash', name: 'Cash'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(completed(), base);
      expect(svc.state.dirty, isTrue);
    });

    test('auto off means no automatic backups, but manual still works', () async {
      final (svc, s) = await rig();
      await svc.setAuto(false);
      final base = completed();
      await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'z', type: 'cash', name: 'Cash'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(completed(), base);
      expect(await s.fire(), isFalse);
      expect(await svc.backupNow(), isNotNull);
    });

    test('a failure schedules a spaced retry, not a tight loop', () async {
      final (svc, s) = await rig();
      cloud.failWith = const SocketException('offline');
      await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'w', type: 'cash', name: 'Cash'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(svc.state.failures, 1);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(svc.state.failures, 1, reason: 'next try is an hour away');
      cloud.failWith = null;
      expect(await s.fire(), isTrue);
    });

    test('resume after a day triggers a catch-up backup', () async {
      final (svc, s) = await rig(debounce: const Duration(hours: 1));
      final base = completed();
      now = now.add(const Duration(days: 2));
      // staleAfter default is 24h; resume arms a 10 s timer, so fire directly.
      s.onResumed();
      expect(svc.state.lastSuccess!.isBefore(now.subtract(const Duration(hours: 24))), isTrue);
      expect(await s.fire(), isTrue);
      expect(completed(), base + 1);
    });
  });

  test('a backup includes writes made through drift companions (smoke)', () async {
    await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'q', type: 'cash', name: 'Late', institution: const Value('Bank')));
    final svc = await service();
    await svc.enable(secret: 'a passphrase of mine', secretKind: 'passphrase', destination: BackupDestination.cloud);
    final dk = (await keys.load())!;
    final v = (await BackupEngine(provider: cloud, dataKey: dk).versions()).single;
    expect(v.manifest.tables.firstWhere((t) => t.name == 'accounts').rows, 2);
  });
}
