import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/theme/tokens.dart';

void main() {
  test('both themes give pushed screens an opaque background', () {
    for (final t in [PulseTheme.light, PulseTheme.dark]) {
      expect(t.scaffoldBackgroundColor.a, 1.0);
    }
  });

  for (final theme in [PulseTheme.light, PulseTheme.dark]) {
    testWidgets(
      'a pushed full-screen route hides the tab page beneath it (${theme.brightness.name})',
      (tester) async {
        PulseTheme.useGoogleFonts = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: TabBackdrop(
              tab: PulseTab.cards,
              // A tab root: its Scaffold is made transparent for the wash.
              child: Builder(
                builder: (context) => Scaffold(
                  body: Column(
                    children: [
                      const Text('Card combos'),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const Scaffold(
                              body: Text('Cards worth having'),
                            ),
                          ),
                        ),
                        child: const Text('open'),
                      ),
                      Builder(
                        builder: (context) {
                          ScaffoldMessenger.of(context);
                          return const SizedBox();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        ScaffoldMessenger.of(tester.element(find.text('open')))
            .showSnackBar(const SnackBar(content: Text('Moved AED 200')));
        await tester.tap(find.text('open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
        expect(find.text('Cards worth having'), findsOneWidget);
        // Settled: the page below is no longer painted or hit-testable.
        expect(find.text('Card combos'), findsNothing);
        expect(find.text('Card combos', skipOffstage: false), findsOneWidget);
        expect(
          find
              .byType(Offstage, skipOffstage: false)
              .evaluate()
              .any((e) => (e.widget as Offstage).offstage),
          isTrue,
        );
      },
    );
  }
}
