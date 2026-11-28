import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'household/household_widget_test.dart' show Rig, pumpApp;

void main() {
  testWidgets('Settings top level is seven rows, Connections first', (
    tester,
  ) async {
    await pumpApp(tester, Rig(), '/settings');
    await tester.pump(const Duration(milliseconds: 600));
    for (final t in [
      'Connections',
      'Money',
      'Family and household',
      'Backup and devices',
      'Privacy and security',
      'Look and notifications',
      'Help and about',
    ]) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    // The old sprawl is gone from the top level.
    expect(find.text('Automatic capture'), findsNothing);
    expect(find.text('Connected sources'), findsNothing);
    expect(find.text('Beta tools'), findsNothing);
  });

  testWidgets('Gmail is one tap from Settings: Connections has the switch', (
    tester,
  ) async {
    await pumpApp(tester, Rig(), '/settings');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('settings_connections')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Read statement emails'), findsOneWidget);
    expect(find.byKey(const Key('connection_gmail_switch')), findsOneWidget);
  });
}
