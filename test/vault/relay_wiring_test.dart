import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/engine/valuation.dart' show notificationIdFor;
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/vault_models.dart';
import 'package:pulse/data/http_relay.dart';
import 'package:pulse/data/local/reminders.dart';
import 'package:pulse/data/local/vault_store.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/vault_service.dart';
import 'package:pulse/features/vault/open_file_sheet.dart';

import 'vault_widget_test.dart' show MemoryAttachmentStorageForTest;

/// A Dio that answers from a function and records what it was sent.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.reply);
  final (int, Object?) Function(RequestOptions) reply;
  final seen = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    final (code, body) = reply(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      code,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioFor(FakeAdapter a) =>
    Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = a;

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  group('HttpInactivityRelay', () {
    test('arm sends ciphertext and a hash only, heartbeat and interval hit their routes', () async {
      final a = FakeAdapter((_) => (200, <String, Object?>{}));
      final relay = HttpInactivityRelay(dioFor(a));
      await relay.arm(
        nomineeId: 'n 1',
        sealedFile: '{"ct":"AA"}',
        claimCodeHash: hashClaimCode('ABCD-EFGH-JKMN'),
        intervalDays: 90,
        now: t0,
      );
      await relay.heartbeat(t0);
      await relay.setInterval(180);
      expect(a.seen.map((r) => '${r.method} ${r.path}'), [
        'PUT /v1/vault/relay/n%201',
        'POST /v1/vault/relay/heartbeat',
        'PUT /v1/vault/relay',
      ]);
      final body = jsonEncode(a.seen.first.data);
      expect(body, isNot(contains('ABCD')));
      expect((a.seen.first.data as Map).keys, {
        'sealed_file',
        'claim_code_hash',
        'interval_days',
      });
    });

    test('disarm treats a missing relay as done', () async {
      final relay = HttpInactivityRelay(
        dioFor(FakeAdapter((_) => (404, {'error': 'x'}))),
      );
      await relay.disarm('n1');
    });

    test('claim maps every server answer', () async {
      Future<ClaimResult> ask(int code, Object? body) =>
          HttpInactivityRelay(dioFor(FakeAdapter((_) => (code, body))))
              .claim(nomineeId: '', claimCode: 'ABCD-EFGH-JKMN', now: t0);

      expect(
        await ask(200, {'status': 'released', 'sealed_file': 'FILE'}),
        isA<ClaimReleased>().having((r) => r.sealedFile, 'file', 'FILE'),
      );
      expect(
        await ask(200, {
          'status': 'pending',
          'release_at': '2026-02-01T00:00:00Z',
        }),
        isA<ClaimPending>(),
      );
      expect(
        await ask(200, {'status': 'not_yet', 'days_left': 12}),
        isA<ClaimNotYet>().having((r) => r.daysLeft, 'days', 12),
      );
      expect(await ask(200, {'status': 'wrong_code'}), isA<ClaimWrongCode>());
      expect(
        await ask(429, {'error': {}}),
        isA<ClaimWrongCode>().having((r) => r.locked, 'locked', isTrue),
      );
      expect(await ask(500, {}), isA<ClaimUnavailable>());
      expect(await ask(200, {'status': 'surprise'}), isA<ClaimUnavailable>());
    });

    test('the hash sent for a claim is of the normalised code', () async {
      final a = FakeAdapter((_) => (200, {'status': 'wrong_code'}));
      await HttpInactivityRelay(dioFor(a))
          .claim(nomineeId: '', claimCode: 'abcd efgh-jkmn', now: t0);
      expect(
        (a.seen.single.data as Map)['claim_code_hash'],
        hashClaimCode('ABCD-EFGH-JKMN'),
      );
    });
  });

  group('owner warnings (local notifications)', () {
    late MemoryVaultStore store;
    late RecordingReminders reminders;
    var now = t0;
    VaultService make(InactivityRelay relay) => VaultService(
      store: store,
      storage: MemoryAttachmentStorageForTest(),
      relay: relay,
      reminders: reminders,
      sources: () async => const VaultSourceData(),
      clock: () => now,
    );
    final soon = notificationIdFor('vault-release:soon');
    final last = notificationIdFor('vault-release:last');

    setUp(() {
      store = MemoryVaultStore();
      reminders = RecordingReminders();
      now = t0;
    });

    test('nothing is scheduled until a file is sealed; then a heads-up and an eve warning, moved by each check-in', () async {
      final svc = make(InMemoryInactivityRelay());
      await svc.checkIn();
      expect(reminders.scheduled, isEmpty);

      final n = await svc.saveNominee(
        svc.blankNominee().copyWith(name: 'Sara'),
      );
      final kit = await svc.createKit(n);
      expect(kit.relayArmed, isTrue);
      expect(reminders.scheduled[soon]!.$3, now.add(const Duration(days: 76)));
      expect(reminders.scheduled[last]!.$3, now.add(const Duration(days: 89)));

      now = t0.add(const Duration(days: 30));
      await svc.checkIn();
      expect(reminders.scheduled[soon]!.$3, now.add(const Duration(days: 76)));
      expect(reminders.scheduled[last]!.$3, now.add(const Duration(days: 89)));
    });

    test('an unreachable server does not break sealing; the owner is told it is not armed', () async {
      final svc = make(
        HttpInactivityRelay(dioFor(FakeAdapter((_) => (500, {})))),
      );
      final n = await svc.saveNominee(
        svc.blankNominee().copyWith(name: 'Sara'),
      );
      final kit = await svc.createKit(n);
      expect(kit.relayArmed, isFalse);
      expect(kit.sealedFile, isNotEmpty);
      expect(reminders.scheduled.containsKey(soon), isTrue);
    });

    test(
      'the local timer still follows a new interval when the server is offline',
      () async {
        final svc = make(
          HttpInactivityRelay(dioFor(FakeAdapter((_) => (500, {})))),
        );
        final n = await svc.saveNominee(
          svc.blankNominee().copyWith(name: 'Sara'),
        );
        await svc.createKit(n);
        await svc.setIntervalDays(180);
        expect(
          reminders.scheduled[soon]!.$3,
          now.add(const Duration(days: 166)),
        );
      },
    );
  });

  testWidgets(
    'a nominee asks Pulse for the file with the release code, then opens it',
    (tester) async {
      final relay = InMemoryInactivityRelay();
      final nominee = Nominee(id: 'n1', name: 'Karim', createdAt: t0);
      final kit = await VaultSeal.createKit(
        ownerName: 'Leila',
        nominee: nominee,
        entries: [
          VaultEntry(
            id: 'e1',
            type: VaultType.bank,
            institution: 'Mashreq',
            createdAt: t0,
            updatedAt: t0,
          ),
        ],
        now: t0,
      );
      await relay.arm(
        nomineeId: nominee.id,
        sealedFile: kit.sealedFile,
        claimCodeHash: kit.claimCodeHash,
        intervalDays: 90,
        now: DateTime.now().toUtc().subtract(const Duration(days: 200)),
      );
      final List<Override> overrides = [
        inactivityRelayProvider.overrideWithValue(relay),
      ];
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: PulseTheme.light,
            home: const Scaffold(body: OpenFileSheet()),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('open_claim_code')),
        'WRONG-CODE-HERE',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_claim_go')));
      await tester.pumpAndSettle();
      expect(find.textContaining('not recognised'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('open_claim_code')),
        kit.claimCode,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('open_claim_go')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Got the file'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('open_file_text')))
            .controller!
            .text,
        kit.sealedFile,
      );
    },
  );
}
