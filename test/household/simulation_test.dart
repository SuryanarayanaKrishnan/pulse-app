import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/household/household_engine.dart';
import 'package:pulse/core/household/household_keys.dart';
import 'package:pulse/core/household/household_models.dart';
import 'package:pulse/core/household/household_scope.dart';
import 'package:pulse/core/household/household_store.dart';
import 'package:pulse/core/sync/segment_codec.dart';
import 'package:pulse/core/sync/sync_engine.dart';
import 'package:pulse/core/sync/sync_state.dart';
import 'package:pulse/core/sync/sync_transport.dart';
import 'package:pulse/data/household_service.dart';

class SpyAnalytics extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

/// One phone: its own store, keystore, sync state and analytics, sharing the
/// "server" with the other.
class Phone {
  Phone(
    this.name,
    MemorySyncTransport server,
    int Function() clock, {
    List<HRow>? own,
  }) : store = MemoryHouseholdStore(own: own),
       keys = MemoryHouseholdKeyStore(),
       stateStore = MemorySyncStateStore(),
       analytics = SpyAnalytics() {
    var n = 0;
    service = HouseholdService(
      store: store,
      keys: keys,
      analytics: analytics,
      transportFor: (_) => server,
      stateStoreFor: (_) => stateStore,
      newId: () => name.padRight(8, '0') + (n++).toString().padLeft(8, '0'),
      nowMs: clock,
      clock: () => DateTime.utc(2026, 11, 20),
    );
  }
  final String name;
  final MemoryHouseholdStore store;
  final MemoryHouseholdKeyStore keys;
  final MemorySyncStateStore stateStore;
  final SpyAnalytics analytics;
  late final HouseholdService service;

  Future<HouseholdConfig> get cfg async => (await store.config())!;
  Future<String> get me async => (await cfg).myMemberId;

  Future<JointData> joint() async => (await service.joint())!;
}

HRow tx(
  String id,
  String merchant,
  int amount, {
  String owner = 'me',
  bool priv = false,
  String cat = 'groceries',
}) => HRow(
  table: HTable.transactions,
  id: id,
  owner: owner,
  isPrivate: priv,
  values: {
    'category_id': cat,
    'amount_minor': amount,
    'currency': 'AED',
    'direction': 'debit',
    'merchant': merchant,
    'posted_at': '2026-11-10T08:00:00.000Z',
    'excluded': false,
  },
);

HRow line(
  String id,
  String name,
  int value, {
  String owner = 'me',
  bool priv = false,
  bool liability = false,
}) => HRow(
  table: HTable.lines,
  id: id,
  owner: owner,
  isPrivate: priv,
  values: {
    'name': name,
    'liability': liability,
    'value_minor': value,
    'currency': 'AED',
  },
);

HRow goal(String id, String name, {String owner = 'me', bool priv = false}) =>
    HRow(
      table: HTable.goals,
      id: id,
      owner: owner,
      isPrivate: priv,
      values: {
        'name': name,
        'kind': 'save',
        'target_minor': 1000000,
        'current_minor': 250000,
        'progress_bps': 2500,
        'paused': false,
      },
    );

void main() {
  late MemorySyncTransport server;
  late int t;
  late Phone alice, sam;

  int clock() => t += 7;

  setUp(() {
    t = 1800000000000;
    server = MemorySyncTransport();
    alice = Phone(
      'alice',
      server,
      clock,
      own: [
        tx('t_milk', 'Carrefour milk', 12000),
        tx('t_gift', 'Surprise ring SECRET', 450000, priv: true),
        tx('t_rent', 'Rent', 650000, owner: Owner.shared, cat: 'rent'),
        line('account:a1', 'Alice current', 20000000),
        line('account:a2', 'Alice hidden savings', 9000000, priv: true),
        line('home', 'Apartment', 90000000, owner: Owner.shared),
        line(
          'mortgage',
          'Mortgage',
          60000000,
          owner: Owner.shared,
          liability: true,
        ),
        goal('g_trip', 'Japan trip', owner: Owner.shared),
        goal('g_secret', 'Anniversary surprise', priv: true),
      ],
    );
    sam = Phone(
      'sam',
      server,
      clock,
      own: [
        tx('s_fuel', 'ENOC fuel', 21000),
        tx('s_cafe', 'Cafe', 3000, cat: 'dining'),
        line('account:s1', 'Sam current', 15000000),
      ],
    );
  });

  Future<void> settle() async {
    for (var i = 0; i < 4; i++) {
      await alice.service.sync();
      await sam.service.sync();
    }
  }

  Future<void> pair() async {
    await alice.service.create(householdName: 'Our home', myName: 'Alice');
    await settle();
    final code = (await alice.service.inviteCode())!;
    await sam.service.join(code: code, myName: 'Sam');
    await settle();
  }

  group('joining', () {
    test('create, invite code, join: both see both members', () async {
      await pair();
      for (final p in [alice, sam]) {
        final names = [for (final m in await p.service.members()) m.name]
          ..sort();
        expect(names, ['Alice', 'Sam']);
      }
      expect((await alice.cfg).id, (await sam.cfg).id);
      expect(await alice.me, isNot(await sam.me));
    });

    test('analytics: one created event, one joined event, nothing else, no content', () async {
      await pair();
      expect(
        [for (final e in alice.analytics.events) e.name],
        ['household_created'],
      );
      expect(
        [for (final e in sam.analytics.events) e.name],
        ['household_member_joined'],
      );
      for (final e in [...alice.analytics.events, ...sam.analytics.events]) {
        expect(e.properties, isEmpty);
      }
    });

    test('a bad code does not create anything', () async {
      await expectLater(
        sam.service.join(code: 'PULSE-HH1-AAAAA', myName: 'Sam'),
        throwsFormatException,
      );
      expect(await sam.store.config(), isNull);
      expect(await sam.keys.load(), isNull);
    });

    test('only one household per phone', () async {
      await pair();
      await expectLater(
        alice.service.create(householdName: 'x', myName: 'y'),
        throwsStateError,
      );
    });
  });

  group('what is shared', () {
    test(
      'the other phone gets shared and non-private items, never private ones',
      () async {
        await pair();
        final j = await sam.joint();
        final ids = {
          for (final x in j.txs) x.id,
          for (final x in j.lines) x.id,
          for (final x in j.goals) x.id,
        };
        expect(
          ids,
          containsAll([
            't_milk',
            't_rent',
            'account:a1',
            'home',
            'mortgage',
            'g_trip',
            's_fuel',
            'account:s1',
          ]),
        );
        expect(ids, isNot(contains('t_gift')));
        expect(ids, isNot(contains('account:a2')));
        expect(ids, isNot(contains('g_secret')));
        expect(
          (await sam.store.mirror()).toString(),
          isNot(contains('SECRET')),
        );
      },
    );

    test(
      'the server never holds a private value, or any plaintext at all',
      () async {
        await pair();
        expect(server.objects, isNotEmpty);
        for (final e in server.objects.entries) {
          expect(e.key, startsWith('household/${(await alice.cfg).id}/'));
          final raw = utf8.decode(e.value, allowMalformed: true);
          for (final needle in [
            'SECRET',
            'Carrefour',
            'Alice',
            'Sam',
            'hidden savings',
            'Anniversary',
            'merchant',
            'amount_minor',
          ]) {
            expect(raw, isNot(contains(needle)), reason: e.key);
          }
        }
      },
    );

    test(
      'decrypted with the household key, the log holds no private row',
      () async {
        await pair();
        final key = (await alice.keys.load())!;
        final cfg = await alice.cfg;
        final codec = await SegmentCodec.forDataKey(
          key,
          purpose: householdKeyPurpose,
          ns: householdNamespace(cfg.id),
        );
        var seen = 0;
        for (final e in server.objects.entries) {
          final seg = await codec.decode(e.key, e.value);
          for (final c in seg.changes) {
            seen++;
            expect(c.row, isNot(anyOf('t_gift', 'account:a2', 'g_secret')));
            expect('${c.value}', isNot(contains('SECRET')));
            expect('${c.value}', isNot(contains('hidden savings')));
          }
        }
        expect(seen, greaterThan(20));
      },
    );

    test(
      'the log cannot be read with the personal sync purpose or another key',
      () async {
        await pair();
        final key = (await alice.keys.load())!;
        final cfg = await alice.cfg;
        final wrongPurpose = await SegmentCodec.forDataKey(
          key,
          ns: householdNamespace(cfg.id),
        );
        final wrongKey = await SegmentCodec.forDataKey(
          Uint8List(32),
          purpose: householdKeyPurpose,
          ns: householdNamespace(cfg.id),
        );
        final e = server.objects.entries.first;
        await expectLater(
          wrongPurpose.decode(e.key, e.value),
          throwsA(anything),
        );
        await expectLater(wrongKey.decode(e.key, e.value), throwsA(anything));
      },
    );

    test('marking an item private later withdraws it from the other phone; unmarking returns it', () async {
      await pair();
      expect((await sam.joint()).txs.map((e) => e.id), contains('t_milk'));
      await alice.service.setOwnership(
        HTable.transactions,
        't_milk',
        isPrivate: true,
      );
      await settle();
      expect(
        (await sam.joint()).txs.map((e) => e.id),
        isNot(contains('t_milk')),
      );
      expect(
        ((await sam.store.mirror())[HTable.transactions] ?? {}).containsKey(
          't_milk',
        ),
        isFalse,
      );
      await alice.service.setOwnership(
        HTable.transactions,
        't_milk',
        isPrivate: false,
      );
      await settle();
      expect((await sam.joint()).txs.map((e) => e.id), contains('t_milk'));
    });

    test('assigning a transaction to the partner shows it as theirs on both phones', () async {
      await pair();
      final samId = await sam.me, aliceId = await alice.me;
      await alice.service.setOwnership(
        HTable.transactions,
        't_milk',
        owner: samId,
      );
      await settle();
      final onSam = (await sam.joint()).txs.firstWhere((x) => x.id == 't_milk');
      expect(onSam.owner, samId);
      final onAlice = (await alice.joint()).txs.firstWhere(
        (x) => x.id == 't_milk',
      );
      expect(onAlice.owner, samId);
      expect(onAlice.owner, isNot(aliceId));
    });

    test(
      'turning off sharing of mine hides my own items but keeps shared ones',
      () async {
        await pair();
        await alice.service.setShareMine(false);
        await settle();
        final ids = {for (final x in (await sam.joint()).txs) x.id};
        expect(ids, isNot(contains('t_milk')));
        expect(ids, contains('t_rent'));
        await alice.service.setShareMine(true);
        await settle();
        expect({
          for (final x in (await sam.joint()).txs) x.id,
        }, contains('t_milk'));
      },
    );

    test(
      'a partner cannot change my items: their edits stay in their mirror',
      () async {
        await pair();
        final before = await alice.store.ownRows();
        await sam.store.putMirror(HTable.transactions, 't_milk', {
          'owner': 'x',
          'amount_minor': 1,
        });
        await settle();
        expect(await alice.store.ownRows(), before);
        expect(
          (await alice.joint()).txs
              .firstWhere((x) => x.id == 't_milk')
              .amountMinor,
          12000,
        );
      },
    );
  });

  group('joint views agree', () {
    test(
      'joint net worth is identical on both phones and excludes private lines',
      () async {
        await pair();
        final a = (await alice.joint()).netWorth(NwScope.joint);
        final s = (await sam.joint()).netWorth(NwScope.joint);
        expect(a.netMinor, s.netMinor);
        expect(a.netMinor, 20000000 + 15000000 + 90000000 - 60000000);
        // Alice's Mine includes her private savings and half of the shared net.
        final mine = (await alice.joint()).netWorth(NwScope.mine);
        expect(mine.netMinor, 20000000 + 9000000 + 15000000);
      },
    );

    test(
      'by-member spending matches on both phones and has no private spend',
      () async {
        await pair();
        final from = DateTime.utc(2026, 11, 1), to = DateTime.utc(2026, 12, 1);
        for (final p in [alice, sam]) {
          final j = await p.joint();
          final r = spendByMember(
            j.txs,
            from: from,
            to: to,
            me: j.me,
            shareMine: j.shareMine,
          );
          final by = {for (final x in r) j.nameOf(x.owner): x.spentMinor};
          expect(by, {'Shared': 650000, 'Alice': 12000, 'Sam': 24000});
        }
      },
    );

    test(
      'shared bills and joint limits are edited by either member and converge',
      () async {
        await pair();
        final a = await alice.me, s = await sam.me;
        await alice.service.saveBill(
          HBill(
            id: 'b1',
            name: 'Rent',
            amountMinor: 650000,
            dueDay: 1,
            split: {a: 6000, s: 4000},
          ),
        );
        await alice.service.saveLimit(
          const HLimit(id: 'l1', categoryId: 'groceries', limitMinor: 300000),
        );
        await settle();
        expect((await sam.joint()).bills.single.name, 'Rent');
        expect((await sam.joint()).limits.single.limitMinor, 300000);
        await sam.service.saveBill(
          HBill(
            id: 'b1',
            name: 'Rent',
            amountMinor: 700000,
            dueDay: 1,
            split: {a: 5000, s: 5000},
          ),
        );
        await sam.service.deleteLimit('l1');
        await settle();
        expect((await alice.joint()).bills.single.amountMinor, 700000);
        expect((await alice.joint()).limits, isEmpty);
      },
    );
  });

  group('leaving', () {
    test(
      'leaving withdraws my rows and membership; the other keeps theirs',
      () async {
        await pair();
        await alice.service.leave();
        expect(await alice.store.config(), isNull);
        expect(await alice.keys.load(), isNull);
        await sam.service.sync();
        final j = await sam.joint();
        expect([for (final m in j.members) m.name], ['Sam']);
        expect({for (final x in j.txs) x.id}, {'s_fuel', 's_cafe'});
        expect({for (final x in j.lines) x.id}, {'account:s1'});
        expect(j.goals, isEmpty);
      },
    );

    test('leaving puts partner-assigned items back to mine and keeps private flags', () async {
      await pair();
      final samId = await sam.me;
      await alice.service.setOwnership(
        HTable.transactions,
        't_milk',
        owner: samId,
      );
      await alice.service.leave();
      final rows = {for (final r in await alice.store.ownRows()) r.id: r};
      expect(rows['t_milk']!.owner, Owner.me);
      expect(rows['t_rent']!.owner, Owner.me);
      expect(rows['t_gift']!.isPrivate, isTrue);
    });

    test('someone with the wrong key cannot read or write the log', () async {
      await pair();
      final stranger = Phone('eve', server, clock);
      await stranger.keys.save(Uint8List(32));
      await stranger.store.saveConfig(
        HouseholdConfig(
          id: (await alice.cfg).id,
          name: 'x',
          myMemberId: 'e',
          createdAt: DateTime.utc(2026),
        ),
      );
      await stranger.store.saveMember(HMember(id: 'e', name: 'Eve'));
      await expectLater(stranger.service.sync(), throwsA(isA<SyncException>()));
      expect(await stranger.store.mirror(), isEmpty);
    });
  });

  group('offline and resumable', () {
    test('a failed upload leaves nothing half-applied and the next sync catches up', () async {
      await alice.service.create(householdName: 'Our home', myName: 'Alice');
      server.failWrites = Exception('offline');
      await expectLater(alice.service.sync(), throwsA(anything));
      expect(alice.service.status.error, isNotNull);
      server.failWrites = null;
      await settle();
      final code = (await alice.service.inviteCode())!;
      await sam.service.join(code: code, myName: 'Sam');
      await settle();
      expect({
        for (final x in (await sam.joint()).txs) x.id,
      }, contains('t_rent'));
    });

    test('no key (phone restored from a backup): not an error, a prompt for a new invite', () async {
      await pair();
      await alice.keys.clear();
      expect(await alice.service.inviteCode(), isNull);
      await alice.service.sync();
      expect(alice.service.status.keyMissing, isTrue);
    });
  });
}
