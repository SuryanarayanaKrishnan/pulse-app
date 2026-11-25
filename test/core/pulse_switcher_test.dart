import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/pulse_switcher.dart';

double _opacity(WidgetTester t, String text) {
  final f = find.ancestor(
    of: find.text(text),
    matching: find.byType(FadeTransition),
  );
  return f
      .evaluate()
      .map((e) => (e.widget as FadeTransition).opacity.value)
      .fold(1.0, (a, b) => a * b);
}

void main() {
  testWidgets('two blocks of different heights are never visible together', (
    tester,
  ) async {
    PulseTheme.useGoogleFonts = false;
    var tall = true;
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        theme: PulseTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              set = setState;
              return ListView(
                children: [
                  PulseSwitcher(
                    child: tall
                        ? const SizedBox(
                            key: ValueKey('a'),
                            height: 800,
                            child: Text('A'),
                          )
                        : const SizedBox(
                            key: ValueKey('b'),
                            height: 200,
                            child: Text('B'),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    set(() => tall = false);
    var bothSeen = false;
    var sawBoth = false;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final a = find.text('A').evaluate().isNotEmpty
          ? _opacity(tester, 'A')
          : 0.0;
      final b = find.text('B').evaluate().isNotEmpty
          ? _opacity(tester, 'B')
          : 0.0;
      if (a > 0.01 && b > 0.01) bothSeen = true;
      if (find.text('A').evaluate().isNotEmpty &&
          find.text('B').evaluate().isNotEmpty)
        sawBoth = true;
      // Both start at the top, never centred on each other.
      if (sawBoth) {
        expect(
          tester.getTopLeft(find.text('A')).dy,
          tester.getTopLeft(find.text('B')).dy,
        );
      }
    }
    await tester.pumpAndSettle();
    expect(bothSeen, isFalse);
    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);
  });
}
