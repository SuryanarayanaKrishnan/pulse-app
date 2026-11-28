@TestOn('vm')
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_pulse_repository.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

/// Runs only against a local pulse-api (never in CI): start the server with
/// ALLOW_DEV_AUTH, then
///   PULSE_LIVE_API=http://localhost:8765 PULSE_TOKEN_A=... PULSE_TOKEN_B=... \
///   PULSE_USER_B=B_UUID flutter test test/splits/live_server_test.dart
void main() {
  final env = Platform.environment;
  final base = env['PULSE_LIVE_API'];
  final skip = base == null
      ? 'set PULSE_LIVE_API to run against a server'
      : null;

  Dio dio(String token) => Dio(
    BaseOptions(
      baseUrl: base ?? '',
      headers: {'Authorization': 'Bearer $token'},
      validateStatus: (_) => true,
    ),
  );

  test('someone adds me to a split on the server: my share lands in my '
      'transactions, once', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final a = dio(env['PULSE_TOKEN_A']!);
    final userB = env['PULSE_USER_B']!;

    // A makes a group with B in it and logs a 300 hotel that A paid.
    final g = (await a.post<Map<String, Object?>>(
      '/v1/splits/groups',
      data: {
        'name': 'Live trip',
        'members': [
          {'display_name': 'Bee', 'user_id': userB},
        ],
      },
    )).data!;
    final members = (g['members'] as List).cast<Map>();
    final memA = members.firstWhere((m) => m['user_id'] != userB)['id'];
    final memB = members.firstWhere((m) => m['user_id'] == userB)['id'];
    final r = await a.post<Map<String, Object?>>(
      '/v1/splits/groups/${g['id']}/expenses',
      data: {
        'description': 'Hotel',
        'amount_minor': 30000,
        'paid_by_member_id': memA,
        'split_type': 'equal',
        'participants': [
          {'member_id': memA},
          {'member_id': memB},
        ],
      },
    );
    expect(r.statusCode, 201, reason: '${r.data}');

    // B's phone, signed in, with an empty ledger.
    final db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogService(
      db: db,
      bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
    );
    await catalog.loadBundled();
    final pipeline = IngestPipeline(db);
    addTearDown(pipeline.dispose);
    final repo = LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      shared: ApiPulseRepository(dio(env['PULSE_TOKEN_B']!)),
      cloudReady: () => true,
    );

    final groups = await repo.splitGroups();
    final mine = groups.firstWhere((x) => x.id == g['id']);
    expect(mine.expenses.single.title, 'Hotel');
    expect(mine.expenses.single.paidBy, isNot('me'));

    await repo.splitGroups(); // a second sync adds nothing
    final txs = await repo.transactions();
    expect(txs.length, 1);
    expect(txs.single.merchant, 'Hotel');
    expect(txs.single.amount, 150);
  }, skip: skip);
}
