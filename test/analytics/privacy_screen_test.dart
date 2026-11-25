import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/analytics/event_schema.dart';
import 'package:pulse/core/analytics/privacy_controller.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/features/privacy/privacy_screen.dart';

Future<PrivacyController> _pump(WidgetTester tester, {bool on = false}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final privacy = PrivacyController(MemoryKvStore());
  if (on) await privacy.setSharing(true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [privacyControllerProvider.overrideWithValue(privacy)],
      child: MaterialApp(theme: PulseTheme.light, home: const PrivacyScreen()),
    ),
  );
  await tester.pump();
  return privacy;
}

void main() {
  testWidgets('toggle is off by default and turns sharing on and off', (tester) async {
    final p = await _pump(tester);
    expect(find.text('Share anonymous usage'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isFalse);
    expect(find.text('Reset anonymous id'), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(p.sharing, isTrue);
    expect(find.text('Reset anonymous id'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(p.sharing, isFalse);
    expect(p.installId, isNull);
  });

  testWidgets('says what is never collected and where data lives', (tester) async {
    await _pump(tester);
    final list = find.byType(Scrollable).first;
    for (final t in ['On this phone', 'Synced, encrypted']) {
      await tester.scrollUntilVisible(find.text(t), 300, scrollable: list);
      expect(find.text(t), findsOneWidget);
    }
    await tester.scrollUntilVisible(find.textContaining('Amounts, merchants, names, contacts or message text'), -300, scrollable: list);
    expect(find.textContaining('Amounts, merchants, names, contacts or message text'), findsOneWidget);
  });

  testWidgets('lists every event in the schema, generated from it', (tester) async {
    await _pump(tester);
    final list = find.byType(Scrollable).first;
    for (final e in AnalyticsSchema.events) {
      await tester.scrollUntilVisible(find.text(e.name), 400, scrollable: list);
      expect(find.text(e.name), findsOneWidget, reason: e.name);
    }
  });

  testWidgets('Reset anonymous id replaces the id', (tester) async {
    final p = await _pump(tester, on: true);
    final before = p.installId;
    await tester.tap(find.text('Reset anonymous id'));
    await tester.pump();
    expect(p.installId, isNot(before));
  });
}
