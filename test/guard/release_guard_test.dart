import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/env/env.dart';
import 'package:pulse/data/providers.dart';

/// A release build must never show sample data as the person's own money. Two
/// nets: nothing outside the allowed files may construct a mock/demo store,
/// and in a simulated release every sample fallback throws instead of
/// returning data.
void main() {
  tearDown(() => Env.debugReleaseOverride = null);

  test('mock and demo stores are only built where the guard is', () {
    const allowed = {
      'lib/data/providers.dart',
      'lib/data/mock_repository.dart',
    };
    final pattern = RegExp(
      r'MockPulseRepository\(|demo(Wealth|Investing|BudgetPlan|Goal)Store\(|Memory(Goal|BudgetPlan)Store demo',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll('\\', '/');
      if (allowed.contains(rel) || rel.contains('/demo_')) continue;
      final text = f.readAsStringSync();
      if (pattern.hasMatch(text) &&
          !rel.endsWith('goal_store.dart') &&
          !rel.endsWith('budget_plan_store.dart')) {
        offenders.add(rel);
      }
    }
    expect(offenders, isEmpty, reason: 'sample data built outside the guarded providers: $offenders');
  });

  test('every sample fallback in providers.dart is guarded', () {
    final src = File('lib/data/providers.dart').readAsStringSync();
    final fallbacks = RegExp(r'return (MockPulseRepository|demo\w+Store)\(').allMatches(src).length;
    final guards = RegExp(r'requireSampleAllowed\(').allMatches(src).length - 1; // minus the definition
    expect(guards, greaterThanOrEqualTo(fallbacks), reason: '$fallbacks sample fallbacks but only $guards guards');
  });

  test('in a release build the repository never falls back to sample data', () {
    Env.debugReleaseOverride = true;
    final c = ProviderContainer(); // no database: the fallback path
    addTearDown(c.dispose);
    expect(() => c.read(repositoryProvider), throwsA(anything));
    expect(() => c.read(wealthStoreProvider), throwsA(anything));
    expect(() => c.read(goalStoreProvider), throwsA(anything));
    expect(() => c.read(budgetPlanStoreProvider), throwsA(anything));
  });

  test('previews and tests (not release) still get the sample repository', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(repositoryProvider), isNotNull);
  });
}
