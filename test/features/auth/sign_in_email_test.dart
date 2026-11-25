import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/auth/sign_in_screen.dart';

void main() {
  testWidgets('the email error clears as soon as the email is edited', (
    tester,
  ) async {
    PulseTheme.useGoogleFonts = false;
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          analyticsProvider.overrideWithValue(NoopAnalytics()),
          sessionProvider.overrideWith((ref) => SessionController()),
        ],
        child: MaterialApp(theme: PulseTheme.light, home: const SignInScreen()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'nope');
    await tester.tap(find.text('Email me a code'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'me@example.com');
    await tester.pump();
    expect(find.text('Enter a valid email'), findsNothing);

    // Submitting a corrected email moves on to the code step.
    await tester.tap(find.text('Email me a code'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Verify and continue'), findsOneWidget);
    expect(find.text('Enter a valid email'), findsNothing);
  });
}
