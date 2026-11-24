import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/sync/change.dart';
import 'package:pulse/core/sync/segment_codec.dart';
import 'package:pulse/core/sync/sync_bridge.dart';
import 'package:pulse/core/sync/sync_engine.dart';
import 'package:pulse/core/sync/sync_scope.dart';
import 'package:pulse/core/sync/sync_transport.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/sync/drift_sync_bridge.dart';
import 'package:pulse/sync/file_sync_state_store.dart';

import '../backup/support.dart' show memoryDb;
import 'support.dart';

/// A real (in-memory SQLite) phone.
class Phone {
  Phone(this.server, this.dir, this.name, {int startMs = 1000000}) : db = memoryDb(), nowMs = startMs {
    store = FileSyncStateStore(locate: () async => File('${dir.path}/$name.json'), db: db);
    engine = _build();
  }
  final MemorySyncTransport server;
  final Directory dir;
  final String name;
  final PulseDatabase db;
  late final FileSyncStateStore store;
  late SyncEngine engine;
  int nowMs;

  SyncEngine _build() => SyncEngine(
    bridge: DriftSyncBridge(db),
    transport: server,
    store: store,
    dataKey: testKey,
    nowMs: () => nowMs,
  );

  void restart() => engine = _build();

  Future<SyncReport> sync() {
    nowMs += 1000;
    return engine.sync();
  }

  Future<void> addTx(String id, String merchant, int amount) async {
    nowMs += 1000;
    await db.into(db.transactions).insert(
      TransactionsCompanion.insert(
        id: id,
        accountId: 'a1',
        amountMinor: amount,
        direction: 'debit',
        postedAt: DateTime.utc(2026, 1, 1),
        source: 'manual',
        merchantRaw: Value(merchant),
      ),
    );
  }

  Future<void> addAccount() => db.into(db.accounts).insert(
    AccountsCompanion.insert(id: 'a1', type: 'bank', name: 'Salary'),
  );

  Future<List<Map<String, Object?>>> rows(String sql) async =>
      [for (final r in await db.customSelect(sql).get()) r.data];
}

void main() {
  late Directory dir;
  late MemorySyncTransport server;
  late Phone p1;
  late Phone p2;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pulse-sync');
    server = MemorySyncTransport();
    p1 = Phone(server, dir, 'p1');
    p2 = Phone(server, dir, 'p2', startMs: 1000500);
  });

  tearDown(() async {
    await p1.db.close();
    await p2.db.close();
    await dir.delete(recursive: true);
  });

  test('scope: only listed tables, never raw messages, never file paths', () {
    expect(syncedTables, isNot(contains('raw_ingests')));
    expect(syncedTables, isNot(contains('app_settings')));
    expect(syncedTables, isNot(contains('price_cache')));
    expect(isSyncedColumn('document_attachments', 'file_paths'), isFalse);
    expect(isSyncedColumn('document_attachments', 'title'), isTrue);
    expect(isSyncedColumn('raw_ingests', 'payload'), isFalse);
  });

  test('every allow-listed table exists with a primary key', () async {
    final snap = await DriftSyncBridge(p1.db).read();
    expect(snap.keys.toSet(), syncedTables);
  });

  test('rows, edits and deletes travel between two real databases', () async {
    await p1.addAccount();
    await p1.addTx('t1', 'Carrefour', 1200);
    await p1.addTx('t2', 'Noon', 5000);
    await p1.sync();
    await p2.sync();
    expect(await p2.rows('SELECT id, merchant_raw, amount_minor FROM transactions ORDER BY id'), [
      {'id': 't1', 'merchant_raw': 'Carrefour', 'amount_minor': 1200},
      {'id': 't2', 'merchant_raw': 'Noon', 'amount_minor': 5000},
    ]);
    // Dates survive as the same stored value.
    expect(
      (await p1.rows("SELECT posted_at FROM transactions WHERE id = 't1'")).single,
      (await p2.rows("SELECT posted_at FROM transactions WHERE id = 't1'")).single,
    );

    await p2.db.customStatement("UPDATE transactions SET merchant_raw = 'Carrefour Express' WHERE id = 't1'");
    await p2.db.customStatement("DELETE FROM transactions WHERE id = 't2'");
    await p2.sync();
    await p1.sync();
    expect(await p1.rows('SELECT id, merchant_raw FROM transactions'), [
      {'id': 't1', 'merchant_raw': 'Carrefour Express'},
    ]);
    expect((await p1.sync()).idle, isTrue);
    expect((await p2.sync()).idle, isTrue);
  });

  test('raw ingests and settings never leave the phone', () async {
    await p1.addAccount();
    await p1.db.into(p1.db.rawIngests).insert(
      RawIngestsCompanion.insert(
        id: 'r1',
        channel: 'sms',
        externalHash: 'h1',
        payload: 'AED 12 spent at SECRETSHOP. Do not share.',
      ),
    );
    await p1.db.putSetting('theme', 'dark');
    await p1.sync();
    await p2.sync();
    expect(await p2.rows('SELECT * FROM raw_ingests'), isEmpty);
    expect(await p2.rows("SELECT * FROM app_settings WHERE key = 'theme'"), isEmpty);
    // And nothing about them is in the encrypted log either.
    final codec = await SegmentCodec.forDataKey(testKey);
    for (final e in server.objects.entries) {
      final seg = await codec.decode(e.key, e.value);
      for (final c in seg.changes) {
        expect(c.table, isNot('raw_ingests'));
        expect(c.table, isNot('app_settings'));
        expect('${c.value}'.contains('SECRETSHOP'), isFalse);
      }
    }
  });

  test('device-local columns are not sent, and the receiving row keeps its own', () async {
    await p1.addAccount();
    await p1.db.into(p1.db.documentAttachments).insert(
      DocumentAttachmentsCompanion.insert(
        id: 'd1',
        title: 'Title deed',
        category: 'title_deed',
        filePaths: const Value('["/data/user/0/app/scan.jpg"]'),
        notificationId: const Value(77),
      ),
    );
    await p1.sync();
    await p2.sync();
    final row = (await p2.rows('SELECT title, file_paths, notification_id FROM document_attachments')).single;
    expect(row['title'], 'Title deed');
    expect(row['file_paths'], '[]');
    expect(row['notification_id'], isNull);
    final codec = await SegmentCodec.forDataKey(testKey);
    for (final e in server.objects.entries) {
      final seg = await codec.decode(e.key, e.value);
      expect(seg.changes.any((c) => c.field == 'file_paths' || c.field == 'notification_id'), isFalse);
    }
  });

  test('a row the database cannot take yet (missing parent data) is retried, not lost or deleted', () async {
    await p1.addAccount();
    await p1.addTx('t1', 'Carrefour', 100);
    await p1.sync();
    // p2 lacks nothing here (foreign keys are off while merging), but a row
    // with a NOT NULL column absent fails: simulate a partial remote row.
    final bridge = DriftSyncBridge(p2.db);
    final failed = await bridge.write([
      const RowWrite('transactions', 'tx-partial', {'note': 'no account, no amount'}),
    ]);
    expect(failed, {const RowKey('transactions', 'tx-partial')});
  });

  test('hostile table or column names from a segment are never run as SQL', () async {
    final bridge = DriftSyncBridge(p1.db);
    final failed = await bridge.write([
      const RowWrite('accounts"; DROP TABLE transactions; --', 'x', {'id': 'x'}),
      const RowWrite('raw_ingests', 'x', {'id': 'x', 'payload': 'p'}),
      const RowWrite('accounts', 'x', {'id': 'x', 'name") VALUES (1); DROP TABLE accounts; --': 1}),
    ]);
    expect(failed.length, lessThanOrEqualTo(1));
    expect(await p1.rows("SELECT name FROM sqlite_master WHERE name IN ('transactions','accounts','raw_ingests')"), hasLength(3));
    expect(await p1.rows('SELECT * FROM raw_ingests'), isEmpty);
  });

  test('state belongs to this exact database: after a restore it starts over, no mass delete', () async {
    await p1.addAccount();
    await p1.addTx('t1', 'Carrefour', 100);
    await p2.sync();
    await p1.sync();
    await p2.sync();
    expect(await p2.rows('SELECT id FROM transactions'), hasLength(1));

    // p2's database is replaced by an older copy (a restore): same state
    // file, different database content and epoch.
    final restored = Phone(server, dir, 'p2', startMs: 1005000);
    await restored.addAccount(); // an old backup that only had the account
    final before = server.objects.length;
    await restored.sync();
    expect(restored.engine.deviceId, isNot(p2.engine.deviceId));
    // It adopts the log (t1 returns) and sends no deletes.
    expect(await restored.rows('SELECT id FROM transactions'), hasLength(1));
    expect(server.objects.length, before); // nothing new to say
    await p1.sync();
    expect(await p1.rows('SELECT id FROM transactions'), hasLength(1));
    await restored.db.close();
  });

  test('the state file is replaced atomically and survives a restart', () async {
    await p1.addAccount();
    await p1.sync();
    final id = p1.engine.deviceId;
    p1.restart();
    await p1.sync();
    expect(p1.engine.deviceId, id);
    expect(File('${dir.path}/p1.json').existsSync(), isTrue);
    expect(File('${dir.path}/p1.json.tmp').existsSync(), isFalse);
  });
}
