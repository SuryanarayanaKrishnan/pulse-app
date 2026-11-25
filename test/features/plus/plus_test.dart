import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/entitlement/entitlement.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/card_combos.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoCards extends MockPulseRepository {
  _NoCards() : super(latency: Duration.zero);
  @override
  Future<List<CreditCard>> myCards() async => const [];
}

final _combos = parseCombos(File('assets/catalog/combos.json').readAsStringSync(), now: DateTime(2026, 11, 30));

Future<ProviderContainer> _pump(WidgetTester tester, String location) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      repositoryProvider.overrideWithValue(_NoCards()),
      analyticsProvider.overrideWithValue(NoopAnalytics()),
      cardCombosProvider.overrideWith((ref) async => _combos),
      entitlementServiceProvider.overrideWithValue(MockEntitlementService(delay: Duration.zero)),
      sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: PulseApp(initialLocation: location)));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
  return container;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('shipped bundle has free combos for new users and locked niche items', () {
    final free = _combos.where((c) => !c.isPlus && c.kind == 'combo');
    expect(free.length, greaterThanOrEqualTo(3));
    expect(_combos.any((c) => c.isPlus), isTrue);
    expect(_combos.indexWhere((c) => c.isPlus), greaterThan(_combos.lastIndexWhere((c) => !c.isPlus)));
  });

  test('expired items are dropped and a missing tier means plus', () {
    final src = jsonEncode({
      'items': [
        {'id': 'a', 'title': 'a', 'valid_until': '2026-01-01'},
        {'id': 'b', 'title': 'b'},
      ],
    });
    final out = parseCombos(src, now: DateTime(2026, 11, 30));
    expect(out.map((c) => c.id), ['b']);
    expect(out.single.isPlus, isTrue);
  });

  test('mock billing flips the entitlement and cancel reverts it', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer(
      overrides: [entitlementServiceProvider.overrideWithValue(MockEntitlementService(delay: Duration.zero))],
    );
    addTearDown(c.dispose);
    expect(c.read(canUseProvider(PlusFeature.aiSummaries)), isFalse);
    await c.read(entitlementProvider.notifier).purchase(plusOffers.first);
    expect(c.read(canUseProvider(PlusFeature.aiSummaries)), isTrue);
    expect(c.read(canUseProvider(PlusFeature.nicheIntel)), isTrue);
    // A fresh container (app restart) still sees Plus.
    final again = ProviderContainer(
      overrides: [entitlementServiceProvider.overrideWithValue(MockEntitlementService(delay: Duration.zero))],
    );
    addTearDown(again.dispose);
    again.read(entitlementProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(again.read(entitlementProvider).isPlus, isTrue);
    await again.read(entitlementProvider.notifier).cancel();
    expect(again.read(entitlementProvider).isPlus, isFalse);
  });

  testWidgets('a user with no cards sees free combos and locked Plus rows', (tester) async {
    await _pump(tester, '/cards');
    expect(find.text('No cards yet'), findsOneWidget);
    expect(find.text('Card combos'), findsOneWidget);
    final free = _combos.firstWhere((c) => !c.isPlus);
    expect(find.text(free.title), findsOneWidget);
    expect(find.text('Niche detail with Plus'), findsWidgets);
  });

  testWidgets('tapping a locked row opens the paywall, billing unlocks Plus', (tester) async {
    final container = await _pump(tester, '/cards');
    await tester.dragUntilVisible(find.text('Niche detail with Plus').first, find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Niche detail with Plus').first);
    await tester.pumpAndSettle();
    expect(find.text('The detail that saves you money'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Test mode'), findsOneWidget);
    await tester.tap(find.text('Confirm test purchase'));
    await tester.pumpAndSettle();
    expect(find.text('Plus is on'), findsOneWidget);
    expect(container.read(entitlementProvider).isPlus, isTrue);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Niche detail with Plus'), findsNothing);
  });
}
