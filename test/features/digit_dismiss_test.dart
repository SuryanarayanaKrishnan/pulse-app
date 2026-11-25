import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/features/cards/digit_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('"not mine" survives a restart and can be undone', () async {
    SharedPreferences.setMockInitialValues({});
    final a = ProviderContainer();
    addTearDown(a.dispose);
    a.read(dismissedDigitsProvider);
    a.read(dismissedDigitsProvider.notifier).add('9999');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final b = ProviderContainer(); // app restart
    addTearDown(b.dispose);
    b.read(dismissedDigitsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.read(dismissedDigitsProvider), {'9999'});

    b.read(dismissedDigitsProvider.notifier).restore('9999');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(dismissedDigitsProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.read(dismissedDigitsProvider), isEmpty);
  });
}
