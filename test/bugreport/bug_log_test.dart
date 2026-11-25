import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/bugreport/bug_log.dart';
import 'package:pulse/core/analytics/analytics.dart';

void main() {
  test('keeps only the last 200 lines', () {
    final log = BugLog();
    for (var i = 0; i < 350; i++) {
      log.event('evt_${String.fromCharCode(97 + i % 26)}');
    }
    expect(log.entries.length, 200);
    expect(log.lines(200).length, 200);
    expect(log.lines(5).length, 5);
  });

  test('capacity is honoured and oldest entries drop first', () {
    final log = BugLog(capacity: 3);
    for (final n in ['a_one', 'b_two', 'c_three', 'd_four']) {
      log.event(n);
    }
    expect(log.entries.map((e) => e.text), ['b_two', 'c_three', 'd_four']);
  });

  test('routes drop queries and ids; current route is tracked', () {
    final log = BugLog();
    log.route('/cards/48213?merchant=Noon');
    expect(log.currentRoute, '/cards/#');
    expect(log.entries.single.text, '/cards/#');
  });

  test('only plain event names are accepted', () {
    final log = BugLog();
    log.event('Paid Noon AED 40');
    log.event('merchant=Noon');
    log.event('first_capture');
    expect(log.entries.map((e) => e.text), ['first_capture']);
  });

  test('errors are redacted and carry stack frames', () {
    final log = BugLog();
    log.error(
      FormatException("Bad amount 'AED 1,200' for sara@x.ae"),
      StackTrace.fromString('#0      foo (package:pulse/a.dart:10:5)\n#1      bar (package:pulse/b.dart:20:7)'),
    );
    final text = log.lines().join('\n');
    expect(text, contains('FormatException'));
    expect(text, contains('a.dart:10:5'));
    expect(text, isNot(contains('1,200')));
    expect(text, isNot(contains('sara')));
    expect(log.entries.where((e) => e.kind == LogKind.trace).length, 2);
  });

  test('long lines are cut', () {
    final log = BugLog();
    log.error('x' * 1000);
    expect(log.entries.first.text.length, lessThan(210));
  });

  test('analytics wrapper logs names, never properties', () {
    final log = BugLog();
    final a = LoggingAnalytics(NoopAnalytics(), log);
    a.track(AnalyticsEvent.backupCompleted(trigger: 'auto', sizeBucket: '<1MB', seconds: 3));
    a.screen('/home');
    expect(log.entries.map((e) => e.text), ['backup_completed', '/home']);
  });
}
