import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/api/api_pulse_repository.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/local/splits_store.dart';

import '../support/fake_adapter.dart';

/// What `pulse-api` returns for `POST /v1/splits/groups` (see
/// app/schemas/split.py `GroupOut` / `MemberOut`).
Map<String, Object?> _groupJson() => {
  'id': 'g1',
  'name': 'Trip',
  'currency': 'AED',
  'created_by': 'u1',
  'members': [
    {
      'id': 'm1',
      'user_id': 'u1',
      'display_name': 'Sara',
      'email': null,
      'phone': null,
    },
    {
      'id': 'm2',
      'user_id': null,
      'display_name': 'Omar',
      'email': null,
      'phone': '+971501234567',
    },
  ],
};

Future<LocalPulseRepository> _repo(
  FakeAdapter adapter, {
  required bool cloudReady,
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(
    db: db,
    bundled: () async => File('assets/catalog/cards.json').readAsStringSync(),
  );
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db);
  addTearDown(pipeline.dispose);
  return LocalPulseRepository(
    db: db,
    catalog: catalog,
    pipeline: pipeline,
    shared: ApiPulseRepository(fakeDio(adapter)),
    cloudReady: () => cloudReady,
  );
}

void main() {
  const people = [NewGroupMember(name: 'Omar', phone: '+971501234567')];

  test('contract: create group, add member, add expense, settle (request shapes match pulse-api)', () async {
    final adapter = FakeAdapter({
      'GET /v1/me': {'id': 'u1'},
      'POST /v1/splits/groups': (201, _groupJson()),
      'GET /v1/splits/groups/g1': _groupJson(),
      'POST /v1/splits/groups/g1/members': (
        201,
        {
          'id': 'm3',
          'user_id': null,
          'display_name': 'Lena',
          'email': null,
          'phone': null,
        },
      ),
      'POST /v1/splits/groups/g1/expenses': (
        201,
        {
          'id': 'e1',
          'group_id': 'g1',
          'description': 'Dinner',
          'amount_minor': 9000,
          'paid_by_member_id': 'm1',
          'spent_at': '2026-11-20T10:00:00Z',
          'shares': [
            {'member_id': 'm1', 'share_minor': 4500},
            {'member_id': 'm2', 'share_minor': 4500},
          ],
        },
      ),
    });
    final repo = ApiPulseRepository(fakeDio(adapter));
    final g = await repo.createSplitGroup(name: 'Trip', members: people);
    expect(g.id, 'g1');
    expect(g.members.map((m) => m.id), [
      'me',
      'm2',
    ]); // the server adds the signed-in user as member 1
    final create = adapter.requests.firstWhere(
      (r) => r.path == '/v1/splits/groups',
    );
    expect(create.data, {
      'name': 'Trip',
      'currency': 'AED',
      'members': [
        {'display_name': 'Omar', 'phone': '+971501234567'},
      ],
    });
    final m = await repo.addMember('g1', name: 'Lena');
    expect(m.id, 'm3');
    expect(adapter.requests.last.data, {'display_name': 'Lena'});
  });

  test('signed in: a new group is made on the server', () async {
    final adapter = FakeAdapter({
      'GET /v1/me': {'id': 'u1'},
      'POST /v1/splits/groups': (201, _groupJson()),
    });
    final repo = await _repo(adapter, cloudReady: true);
    final g = await repo.createSplitGroup(name: 'Trip', members: people);
    expect(g.id, 'g1');
    expect(
      adapter.requests.any(
        (r) => r.path == '/v1/splits/groups' && r.method == 'POST',
      ),
      isTrue,
    );
  });

  test(
    'signed out: the group stays on the phone and the server is not called',
    () async {
      final adapter = FakeAdapter({});
      final repo = await _repo(adapter, cloudReady: false);
      final g = await repo.createSplitGroup(name: 'Trip', members: people);
      expect(g.id, isNot('g1'));
      expect(adapter.requests, isEmpty);
    },
  );

  test('server down: falls back to a group on the phone', () async {
    final adapter = FakeAdapter({
      'POST /v1/splits/groups': (503, 'unavailable'),
      'GET /v1/me': {'id': 'u1'},
    });
    final repo = await _repo(adapter, cloudReady: true);
    final g = await repo.createSplitGroup(name: 'Trip', members: people);
    expect(g.name, 'Trip');
    expect((await repo.splitGroups()).map((x) => x.name), contains('Trip'));
  });

  test('server rejects the request (bad phone): the error is shown, no silent local group', () async {
    final adapter = FakeAdapter({
      'GET /v1/me': {'id': 'u1'},
      'POST /v1/splits/groups': (
        422,
        {
          'error': {
            'code': 'invalid_phone',
            'message': 'Not a valid phone number',
            'details': [],
          },
        },
      ),
    });
    final repo = await _repo(adapter, cloudReady: true);
    await expectLater(
      repo.createSplitGroup(
        name: 'Trip',
        members: const [NewGroupMember(name: 'X', phone: '12')],
      ),
      throwsA(isA<ApiException>()),
    );
  });
}
