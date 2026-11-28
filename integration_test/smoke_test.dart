import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pulse/main.dart' as app;

/// Launches the REAL app (real main, real encrypted database, real bundled
/// catalog, no overrides) on a device or simulator and checks that it comes up
/// and stays up: no framework error, no error screen, something readable on
/// screen. Run by .github/workflows/ios-simulator-smoke.yml.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real app launches and shows a first screen', (tester) async {
    final errors = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add(d.summary.toString());
      prev?.call(d);
    };
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 1), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 3));

    final texts = [
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        if (w.data != null) w.data!,
    ];
    expect(texts, isNotEmpty, reason: 'nothing readable on the first screen');
    expect(
      texts.any((t) => t.contains('Something went wrong') || t.contains('failed to open')),
      isFalse,
      reason: 'error screen on launch: $texts',
    );
    await binding.takeScreenshot('first-screen');
    FlutterError.onError = prev;
    expect(errors, isEmpty, reason: errors.join('\n'));
  });
}
