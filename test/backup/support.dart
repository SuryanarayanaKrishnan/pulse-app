import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/backup/db_snapshot.dart';
import 'package:pulse/data/local/database.dart';

PulseDatabase memoryDb() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  return PulseDatabase(NativeDatabase.memory());
}

/// A ledger with accounts, 1200 transactions (several chunks), jewellery and a
/// document with real files on disk.
Future<List<File>> populate(PulseDatabase db, Directory dir, {int transactions = 1200, int photoBytes = 5000}) async {
  await db.into(db.accounts).insert(AccountsCompanion.insert(id: 'a1', type: 'bank', name: 'Salary account'));
  await db.batch((b) {
    for (var i = 0; i < transactions; i++) {
      b.insert(
        db.transactions,
        TransactionsCompanion.insert(
          id: 't$i',
          accountId: 'a1',
          amountMinor: 1000 + i,
          direction: 'debit',
          postedAt: DateTime.utc(2026, 1, 1).add(Duration(hours: i)),
          source: 'sms',
          merchantRaw: Value('Shop $i'),
        ),
      );
    }
  });
  final rng = Random(7);
  final files = <File>[];
  for (final name in ['ring.jpg', 'chain.jpg', 'deed.jpg']) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(List.generate(photoBytes, (_) => rng.nextInt(256)));
    files.add(f);
  }
  await db.into(db.jewelleryItems).insert(
    JewelleryItemsCompanion.insert(
      id: 'j1',
      name: 'Gold ring',
      weightGrams: 12.5,
      karat: 22,
      photoPaths: Value(jsonEncode([files[0].path, files[1].path, 'demo:ring'])),
    ),
  );
  await db.into(db.documentAttachments).insert(
    DocumentAttachmentsCompanion.insert(
      id: 'd1',
      title: 'Title deed',
      category: 'title_deed',
      filePaths: Value(jsonEncode([files[2].path, '${dir.path}/gone.jpg'])),
    ),
  );
  await db.putSetting('theme', 'dark');
  return files;
}

/// Everything in the database, minus nothing: used to prove a restore is
/// identical to the original.
Future<Map<String, List<List<Object?>>>> fingerprint(PulseDatabase db, {Map<String, String> pathRemap = const {}}) async {
  final out = <String, List<List<Object?>>>{};
  for (final t in await dumpTables(db)) {
    out[t.name] = [
      for (final r in t.rows)
        [for (final v in r) v is String ? pathRemap.entries.fold<String>(v, (s, e) => s.replaceAll(e.key, e.value)) : v],
    ];
  }
  return out;
}

class RecordingAnalytics implements Analytics {
  final events = <AnalyticsEvent>[];
  @override
  Future<void> init() async {}
  @override
  void track(AnalyticsEvent e) => events.add(e);
  @override
  void screen(String name) {}
  @override
  void identify(String userId) {}
  @override
  void reset() {}
  List<String> get names => [for (final e in events) e.name];
}
