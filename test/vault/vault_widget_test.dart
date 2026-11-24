import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/widgets/widgets.dart';
import 'package:pulse/core/vault/vault_models.dart';
import 'package:pulse/data/local/attachments.dart';
import 'package:pulse/data/local/vault_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/vault_service.dart';
import 'package:pulse/features/vault/entry_sheet.dart';
import 'package:pulse/features/vault/nominee_sheet.dart';
import 'package:pulse/features/vault/vault_screen.dart';

class Rec extends NoopAnalytics {
  final events = <AnalyticsEvent>[];
  @override
  void track(AnalyticsEvent event) => events.add(event);
}

final t0 = DateTime.utc(2026, 11, 1);
VaultEntry ent(String id, VaultType t, String inst, {String where = ''}) =>
    VaultEntry(
      id: id,
      type: t,
      institution: inst,
      whereToFind: where,
      createdAt: t0,
      updatedAt: t0,
    );

Future<void> pump(WidgetTester tester, List<Override> o, Widget home) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: o,
      child: MaterialApp(theme: PulseTheme.light, home: home),
    ),
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late MemoryVaultStore store;
  late Rec rec;
  List<Override> overrides() => [
    vaultStoreProvider.overrideWithValue(store),
    analyticsProvider.overrideWithValue(rec),
    repositoryProvider.overrideWithValue(
      MockPulseRepository(latency: Duration.zero),
    ),
    inactivityRelayProvider.overrideWithValue(
      const UnavailableInactivityRelay(),
    ),
  ];
  setUp(() {
    store = MemoryVaultStore();
    rec = Rec();
  });

  testWidgets('adding an item saves it and reports only its type', (
    tester,
  ) async {
    await pump(tester, overrides(), const Scaffold(body: EntrySheet()));
    await tester.enterText(
      find.byKey(const Key('vault_institution')),
      'Mashreq',
    );
    await tester.enterText(
      find.byKey(const Key('vault_where')),
      'Statements in the grey folder',
    );
    await tester.enterText(find.byKey(const Key('vault_value')), '12500');
    await tester.pump();
    final save = find.byKey(const Key('vault_save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump(const Duration(milliseconds: 200));
    final e = (await store.entries()).single;
    expect(e.institution, 'Mashreq');
    expect(e.estimatedValueMinor, 1250000);
    final ev = rec.events.single;
    expect(ev.name, 'vault_entry_added');
    expect(ev.properties, {'type': 'bank'});
    expect(AnalyticsSchema.clean(ev.name, ev.properties), ev.properties);
  });

  testWidgets(
    'a card number, an IBAN or a password blocks saving with a calm message',
    (tester) async {
      await pump(tester, overrides(), const Scaffold(body: EntrySheet()));
      await tester.enterText(
        find.byKey(const Key('vault_institution')),
        'ADCB',
      );
      final save = find.byKey(const Key('vault_save'));
      for (final bad in [
        'card 4111 1111 1111 1111',
        'AE070331234567890123456',
        'password: hunter2',
        'PIN 4821',
      ]) {
        await tester.enterText(find.byKey(const Key('vault_where')), bad);
        await tester.pump();
        expect(
          find.byKey(const Key('vault_guard_note')),
          findsWidgets,
          reason: bad,
        );
        expect(
          tester.widget<PrimaryButton>(save).onPressed,
          isNull,
          reason: bad,
        );
      }
      await tester.enterText(
        find.byKey(const Key('vault_where')),
        'Card ending 4242, statements in the app',
      );
      await tester.pump();
      expect(find.byKey(const Key('vault_guard_note')), findsNothing);
      expect(tester.widget<PrimaryButton>(save).onPressed, isNotNull);
      expect(await store.entries(), isEmpty);
      expect(rec.events, isEmpty);
    },
  );

  test('the service refuses secrets even if the UI is bypassed', () async {
    final svc = VaultService(
      store: store,
      storage: MemoryAttachmentStorageForTest(),
      relay: const UnavailableInactivityRelay(),
      sources: () async => const VaultSourceData(),
    );
    final bad = svc
        .blank(VaultType.bank)
        .copyWith(institution: 'X', whereToFind: 'pin is 1234');
    await expectLater(svc.saveEntry(bad), throwsA(isA<VaultGuardException>()));
    await expectLater(
      svc.saveNominee(
        svc.blankNominee().copyWith(name: 'Sara', contact: 'password: abc123'),
      ),
      throwsA(isA<VaultGuardException>()),
    );
    expect(await store.entries(), isEmpty);
  });

  testWidgets(
    'the screen shows the score, adds suggestions in one tap, and lists them',
    (tester) async {
      store = MemoryVaultStore(
        entries: [ent('e1', VaultType.bank, 'Mashreq', where: 'Grey folder')],
      );
      await pump(tester, overrides(), const VaultScreen());
      expect(find.text('Family vault'), findsOneWidget);
      expect(find.textContaining('Your family could find'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mashreq'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Mashreq'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('vault_relay_note')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('not switched on yet'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pump(const Duration(milliseconds: 500));
      final banner = find.byKey(const Key('vault_suggestions'));
      expect(
        banner,
        findsOneWidget,
        reason: 'the demo data has accounts, cards and loans',
      );
      await tester.tap(banner);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.ensureVisible(find.byKey(const Key('vault_sugg_add')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('vault_sugg_add')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect((await store.entries()).length, greaterThan(1));
      expect(rec.events.every((e) => e.name == 'vault_entry_added'), isTrue);
      expect(
        find.byKey(const Key('vault_suggestions')),
        findsNothing,
        reason: 'nothing left to suggest',
      );
    },
  );

  testWidgets(
    'a person with a subset: preview shows only what they would see',
    (tester) async {
      store = MemoryVaultStore(
        entries: [
          ent('e1', VaultType.bank, 'Mashreq', where: 'Grey folder'),
          ent('e2', VaultType.insurance, 'Sukoon', where: 'Policy in the safe'),
        ],
        nominees: [
          Nominee(id: 'n1', name: 'Sara', entryIds: {'e2'}, createdAt: t0),
        ],
      );
      await pump(tester, overrides(), const PreviewScreen(nomineeId: 'n1'));
      expect(find.text('What Sara would see'), findsOneWidget);
      expect(
        find.byKey(const Key('preview_count')).evaluate().isNotEmpty,
        isTrue,
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('preview_count'))).data,
        startsWith('1 of 2 items'),
      );
      final text = tester
          .widget<SelectableText>(find.byKey(const Key('preview_text')))
          .data!;
      expect(text, contains('Sukoon'));
      expect(text, isNot(contains('Mashreq')));
    },
  );

  testWidgets(
    'sealing a file shows three codes once, keeps only the owner share, and explains the missing server',
    (tester) async {
      final n = Nominee(id: 'n1', name: 'Sara', createdAt: t0);
      store = MemoryVaultStore(
        entries: [ent('e1', VaultType.bank, 'Mashreq')],
        nominees: [n],
      );
      await pump(tester, overrides(), Scaffold(body: KitSheet(nominee: n)));
      await tester.tap(find.byKey(const Key('kit_make')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      final share = tester
          .widget<SelectableText>(find.byKey(const Key('kit_nominee_share')))
          .data!;
      final escrow = tester
          .widget<SelectableText>(find.byKey(const Key('kit_escrow_share')))
          .data!;
      expect(share, startsWith('PVS1-2-02'));
      expect(find.byKey(const Key('kit_relay_note')), findsOneWidget);
      expect(store.settings['vault.share1.n1'], startsWith('PVS1-2-01'));
      expect(store.settings.values, isNot(contains(share)));
      expect(store.settings.values, isNot(contains(escrow)));
      expect(rec.events.map((e) => e.properties), [
        {'kind': 'sealed'},
      ]);
    },
  );

  test('check-in is recorded, the interval persists, entries leave a nominee list when removed', () async {
    var now = t0;
    final relay = InMemoryInactivityRelay();
    final svc = VaultService(
      store: store,
      storage: MemoryAttachmentStorageForTest(),
      relay: relay,
      sources: () async => const VaultSourceData(),
      clock: () => now,
    );
    final a = await svc.saveEntry(
      svc.blank(VaultType.bank).copyWith(institution: 'A'),
    );
    final b = await svc.saveEntry(
      svc.blank(VaultType.bank).copyWith(institution: 'B'),
    );
    final n = await svc.saveNominee(
      svc.blankNominee().copyWith(name: 'Sara', entryIds: {a.id, b.id}),
    );
    await svc.deleteEntry(a.id);
    expect((await svc.nominees()).single.entryIds, {b.id});
    await svc.setIntervalDays(180);
    expect(await svc.intervalDays(), 180);
    await svc.createKit(n);
    expect(relay.isArmed(n.id), isTrue);
    now = t0.add(const Duration(days: 100));
    expect(
      (await svc.status()).phase,
      CheckInPhase.ok,
      reason: 'no check-in yet counts from now',
    );
    await svc.checkIn();
    expect(await svc.lastCheckIn(), now);
    expect((await svc.status()).daysLeft, 180);
    await svc.deleteNominee(n.id);
    expect(relay.isArmed(n.id), isFalse);
    expect(await svc.ownerShare(n.id), isNull);
  });
}

typedef MemoryAttachmentStorageForTest = MemoryAttachmentStorage;
