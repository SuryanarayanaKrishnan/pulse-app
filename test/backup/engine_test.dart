import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/backup/archive_file.dart';
import 'package:pulse/backup/backup_crypto.dart';
import 'package:pulse/backup/backup_engine.dart';
import 'package:pulse/backup/backup_format.dart';
import 'package:pulse/backup/backup_provider.dart';
import 'package:pulse/backup/db_snapshot.dart';
import 'package:pulse/data/local/database.dart';

import 'support.dart';

void main() {
  late Directory tmp;
  late Directory restoreDir;
  late PulseDatabase db;
  late MemoryBackupProvider store;
  late Uint8List dataKey;
  late List<File> files;
  var now = DateTime.utc(2026, 3, 1, 10);

  BackupEngine engine({int chunkSize = 2048, BackupProvider? provider}) => BackupEngine(
    provider: provider ?? store,
    dataKey: dataKey,
    chunkSize: chunkSize,
    rowsPerChunk: 400,
    clock: () => now,
  );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('pulse_bk');
    restoreDir = Directory('${tmp.path}/restored');
    db = memoryDb();
    store = MemoryBackupProvider(clock: () => now);
    dataKey = BackupCrypto.randomBytes(32);
    files = await populate(db, tmp);
    now = DateTime.utc(2026, 3, 1, 10);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test('server side holds only ciphertext: no plaintext string appears in any object', () async {
    await engine().backup(db: db);
    expect(store.objects, isNotEmpty);
    for (final e in store.objects.entries) {
      final text = latin1.decode(e.value);
      for (final secret in ['Salary account', 'Gold ring', 'Title deed', 'Shop 5', 'sms']) {
        expect(text, isNot(contains(secret)), reason: '${e.key} leaks "$secret"');
      }
    }
    // Names are keyed hashes, not file names or content hashes.
    expect(store.objects.keys.where((k) => k.contains('ring') || k.contains('jpg')), isEmpty);
  });

  test('restore into a fresh database equals the original, files included', () async {
    final stats = await engine().backup(db: db);
    expect(stats.rows, greaterThan(1200));
    expect(stats.attachments, 3);
    expect(stats.skippedAttachments, 1, reason: 'gone.jpg was missing');

    final fresh = memoryDb();
    addTearDown(fresh.close);
    final r = await engine().restoreInto(target: fresh, manifestName: stats.manifestName, attachmentsDir: restoreDir);
    expect(r.attachments, 3);

    // Same rows, except the file paths that now point into the new folder.
    final restoredFiles = restoreDir.listSync().whereType<File>().toList();
    expect(restoredFiles, hasLength(3));
    final after = await fingerprint(fresh);
    final jewel = await fresh.select(fresh.jewelleryItems).getSingle();
    final newPaths = (jsonDecode(jewel.photoPaths) as List).cast<String>();
    expect(newPaths.first, startsWith(restoreDir.path));
    expect(newPaths.last, 'demo:ring');
    final remap = <String, String>{files[0].path: newPaths[0], files[1].path: newPaths[1]};
    final deed = await fresh.select(fresh.documentAttachments).getSingle();
    final deedPaths = (jsonDecode(deed.filePaths) as List).cast<String>();
    remap[files[2].path] = deedPaths.first;
    expect(await fingerprint(db, pathRemap: remap), after);
    // Bytes are identical.
    expect(File(newPaths[0]).readAsBytesSync(), files[0].readAsBytesSync());
    expect(File(deedPaths.first).readAsBytesSync(), files[2].readAsBytesSync());
    expect(await fresh.setting('theme'), 'dark');
  });

  test('chunk dedupe: an unchanged second backup uploads only the manifest', () async {
    final first = await engine().backup(db: db);
    expect(first.chunksUploaded, greaterThan(5));
    final writesAfterFirst = store.writes;
    now = now.add(const Duration(hours: 1));
    final second = await engine().backup(db: db);
    expect(second.chunksUploaded, 0);
    expect(second.chunksReused, first.chunksUploaded + first.chunksReused);
    expect(store.writes - writesAfterFirst, 1, reason: 'just the manifest');
  });

  test('chunk dedupe: one changed row re-uploads only its chunk', () async {
    final first = await engine().backup(db: db);
    await (db.update(db.transactions)..where((t) => t.id.equals('t5'))).write(const TransactionsCompanion(notes: Value('lunch')));
    now = now.add(const Duration(hours: 1));
    final second = await engine().backup(db: db);
    expect(second.chunksUploaded, 1);
    expect(second.chunksReused, first.chunksUploaded + first.chunksReused - 1);
  });

  test('identical photo content is stored once', () async {
    final copy = File('${tmp.path}/ring-copy.jpg')..writeAsBytesSync(files[0].readAsBytesSync());
    await db.into(db.jewelleryItems).insert(
      JewelleryItemsCompanion.insert(id: 'j2', name: 'Copy', weightGrams: 1, karat: 18, photoPaths: Value(jsonEncode([copy.path]))),
    );
    final s = await engine().backup(db: db);
    final eng = engine();
    final m = await eng.readManifest(s.manifestName);
    final ring = m.attachments.firstWhere((a) => a.name == 'ring.jpg');
    final dupe = m.attachments.firstWhere((a) => a.name == 'ring-copy.jpg');
    expect(dupe.chunks, ring.chunks);
    expect(dupe.fileId, ring.fileId);
  });

  test('manifest carries the schema version and format', () async {
    final s = await engine().backup(db: db);
    final m = await engine().readManifest(s.manifestName);
    expect(m.format, backupFormatVersion);
    expect(m.appSchemaVersion, PulseDatabase.currentSchemaVersion);
    expect(m.createdAt, DateTime.utc(2026, 3, 1, 10));
  });

  test('a backup from a newer schema is refused, an older one is upgraded through the hooks', () async {
    final s = await engine().backup(db: db);
    final fresh = memoryDb();
    addTearDown(fresh.close);

    // Pretend the app is older than the backup.
    final olderApp = _SchemaDb(1);
    addTearDown(olderApp.close);
    await expectLater(
      engine().restoreInto(target: olderApp, manifestName: s.manifestName, attachmentsDir: restoreDir),
      throwsA(isA<BackupTooNew>()),
    );

    // Pretend the backup is from schema 1 and the app is at 2: an upgrader runs.
    final eng = engine();
    final m = await eng.readManifest(s.manifestName);
    final old = BackupManifest(
      format: 1,
      appSchemaVersion: 1,
      createdAt: m.createdAt,
      id: m.id,
      tables: m.tables,
      attachments: m.attachments,
      skippedAttachments: 0,
      treeHash: m.treeHash,
    );
    final key = await BackupCrypto.subKey(dataKey, 'manifest');
    const name = 'manifests/000000000000001-oldold01.bin';
    store.objects[name] = await BackupCrypto.seal(key, old.encode(), aad: utf8.encode(name));
    var ran = 0;
    await eng.restoreInto(
      target: fresh,
      manifestName: name,
      attachmentsDir: restoreDir,
      upgraders: {
        1: (tables) {
          ran++;
          final acc = tables['accounts']!;
          acc.rows.first[acc.indexOfColumn('name')] = 'Upgraded';
        },
      },
    );
    expect(ran, 1);
    expect((await fresh.select(fresh.accounts).getSingle()).name, 'Upgraded');
  });

  test('columns missing from the target schema are dropped, not fatal', () async {
    final s = await engine().backup(db: db);
    final eng = engine();
    final m = await eng.readManifest(s.manifestName);
    // Re-write the accounts chunk with an extra column from a "future" schema.
    final tbl = m.tables.firstWhere((t) => t.name == 'accounts');
    final chunk = decodeChunk(await _plain(store, dataKey, tbl.chunks.single));
    expect(chunk.columns, contains('name'));
    final fresh = memoryDb();
    addTearDown(fresh.close);
    final extra = TableDump('accounts', [...chunk.columns, 'colour_from_the_future'], [
      [...chunk.rows.first, 'teal'],
    ]);
    final counts = await importTables(fresh, [extra]);
    expect(counts.rows, 1);
    expect((await fresh.select(fresh.accounts).getSingle()).name, 'Salary account');
  });

  test('tampered chunk, tampered manifest, swapped chunk and missing chunk are all rejected', () async {
    final s = await engine().backup(db: db);
    final fresh = memoryDb();
    addTearDown(fresh.close);
    Future<void> expectRejected(Object matcher) => expectLater(
      engine().restoreInto(target: fresh, manifestName: s.manifestName, attachmentsDir: restoreDir),
      throwsA(matcher),
    );
    final chunkNames = store.objects.keys.where((k) => k.startsWith('chunks/')).toList()..sort();

    // flip a bit in one chunk
    final victim = chunkNames.first;
    final original = Uint8List.fromList(store.objects[victim]!);
    store.objects[victim] = Uint8List.fromList(original)..[original.length ~/ 2] ^= 0x10;
    await expectRejected(isA<BackupIntegrityError>());
    store.objects[victim] = original;

    // swap two chunks' contents (the server moves objects around)
    final other = chunkNames.last;
    final otherBytes = store.objects[other]!;
    store.objects[victim] = otherBytes;
    await expectRejected(isA<BackupIntegrityError>());
    store.objects[victim] = original;

    // delete one chunk: partial backup
    store.objects.remove(victim);
    await expectRejected(isA<BackupIncomplete>());
    store.objects[victim] = original;

    // tamper with the manifest
    final m = store.objects[s.manifestName]!;
    store.objects[s.manifestName] = Uint8List.fromList(m)..[m.length - 3] ^= 1;
    await expectRejected(isA<BackupIntegrityError>());
    store.objects[s.manifestName] = m;

    // a manifest renamed on the server no longer authenticates
    store.objects['manifests/999999999999999-ffffffff.bin'] = m;
    await expectLater(
      engine().restoreInto(target: fresh, manifestName: 'manifests/999999999999999-ffffffff.bin', attachmentsDir: restoreDir),
      throwsA(isA<BackupIntegrityError>()),
    );
    store.objects.remove('manifests/999999999999999-ffffffff.bin');

    // nothing was written to the target or the files folder by any attempt
    expect(await fresh.select(fresh.transactions).get(), isEmpty);
    expect(restoreDir.existsSync() ? restoreDir.listSync() : [], isEmpty);

    // and the untouched backup still restores
    final ok = await engine().restoreInto(target: fresh, manifestName: s.manifestName, attachmentsDir: restoreDir);
    expect(ok.rows, greaterThan(1200));
  });

  test('the wrong data key cannot read anything', () async {
    final s = await engine().backup(db: db);
    final wrong = BackupEngine(provider: store, dataKey: BackupCrypto.randomBytes(32));
    await expectLater(wrong.readManifest(s.manifestName), throwsA(isA<BackupIntegrityError>()));
    expect(await wrong.versions(), isEmpty);
    expect(wrong.corruptManifests, 1);
  });

  test('retention keeps the last N versions and collects orphaned chunks', () async {
    for (var i = 0; i < 4; i++) {
      await (db.update(db.transactions)..where((t) => t.id.equals('t${i * 450}'))).write(TransactionsCompanion(notes: Value('v$i')));
      now = now.add(const Duration(days: 1));
      await engine().backup(db: db, keep: 2);
    }
    final versions = await engine().versions();
    expect(versions, hasLength(2));
    expect(versions.first.manifest.createdAt.isAfter(versions.last.manifest.createdAt), isTrue);
    final live = {for (final v in versions) ...v.manifest.allChunks};
    final stored = store.objects.keys.where((k) => k.startsWith('chunks/')).map((k) => k.substring(7)).toSet();
    expect(stored, live, reason: 'no orphans, nothing missing');
    // The older kept version still restores.
    final fresh = memoryDb();
    addTearDown(fresh.close);
    await engine().restoreInto(target: fresh, manifestName: versions.last.objectName, attachmentsDir: restoreDir);
  });

  test('garbage collection leaves very recent chunks alone', () async {
    await engine().backup(db: db, prune: false);
    await store.write('chunks/${'a' * 64}', Uint8List(10)); // another device, uploading right now
    await engine().pruneOld(keep: 5);
    expect(store.objects.containsKey('chunks/${'a' * 64}'), isTrue);
    now = now.add(const Duration(hours: 3));
    await engine().pruneOld(keep: 5);
    expect(store.objects.containsKey('chunks/${'a' * 64}'), isFalse);
  });

  test('a failing provider surfaces the error and leaves no manifest behind', () async {
    store.failWith = const SocketException('offline');
    await expectLater(engine().backup(db: db), throwsA(isA<SocketException>()));
    store.failWith = null;
    expect(store.objects.keys.where((k) => k.startsWith('manifests/')), isEmpty);
    expect(await engine().versions(), isEmpty);
  });

  group('archive file (export/import)', () {
    test('exports to one file and restores from it', () async {
      final path = '${tmp.path}/out.pulsebak';
      final sink = ArchiveWriterProvider(path);
      final stats = await engine(provider: sink).backup(db: db, prune: false);
      await sink.close();
      expect(File(path).lengthSync(), greaterThan(1000));
      expect(latin1.decode(File(path).readAsBytesSync()), isNot(contains('Salary account')));

      final reader = await ArchiveReaderProvider.open(path);
      final fresh = memoryDb();
      addTearDown(fresh.close);
      final r = await engine(provider: reader).restoreInto(target: fresh, manifestName: stats.manifestName, attachmentsDir: restoreDir);
      expect(r.rows, stats.rows);
      expect(await fresh.select(fresh.transactions).get(), hasLength(1200));
    });

    test('a truncated or foreign file is rejected before anything is read', () async {
      final path = '${tmp.path}/x.pulsebak';
      final sink = ArchiveWriterProvider(path);
      await engine(provider: sink).backup(db: db, prune: false);
      await sink.close();
      final bytes = File(path).readAsBytesSync();
      File('${tmp.path}/cut.pulsebak').writeAsBytesSync(bytes.sublist(0, bytes.length - 50));
      await expectLater(ArchiveReaderProvider.open('${tmp.path}/cut.pulsebak'), throwsA(isA<ArchiveFormatError>()));
      File('${tmp.path}/pic.pulsebak').writeAsBytesSync(List.filled(64, 7));
      await expectLater(ArchiveReaderProvider.open('${tmp.path}/pic.pulsebak'), throwsA(isA<ArchiveFormatError>()));
    });
  });

  test('stub providers say why they are unavailable', () async {
    await expectLater(googleDriveProvider().ensureReady(), throwsA(isA<BackupProviderUnavailable>()));
    await expectLater(iCloudProvider().list(''), throwsA(isA<BackupProviderUnavailable>()));
  });
}

class _SchemaDb extends PulseDatabase {
  _SchemaDb(this.v) : super(memoryDb().executor);
  final int v;
  @override
  int get schemaVersion => v;
}

Future<Uint8List> _plain(MemoryBackupProvider store, Uint8List dataKey, String id) async {
  final ck = await BackupCrypto.subKey(dataKey, 'chunk');
  return BackupCrypto.open(ck, store.objects['chunks/$id']!, aad: utf8.encode(id));
}
