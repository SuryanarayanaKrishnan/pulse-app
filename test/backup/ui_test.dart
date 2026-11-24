import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/backup/backup_providers.dart';
import 'package:pulse/backup/backup_state.dart';
import 'package:pulse/backup/demo_backup.dart';
import 'package:pulse/backup/restore_flow.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/primary_button.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/backup/backup_screen.dart';
import 'package:pulse/features/backup/backup_setup_screen.dart';
import 'package:pulse/features/backup/restore_screen.dart';

const _words = [
  'abandon',
  'ability',
  'able',
  'about',
  'above',
  'absent',
  'absorb',
  'abstract',
  'absurd',
  'abuse',
  'access',
  'accident',
];

Future<void> _pump(
  WidgetTester tester,
  Widget screen, {
  List overrides = const [],
  ThemeMode mode = ThemeMode.light,
}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith((ref) => SessionController()),
        ...overrides.cast(),
      ],
      child: MaterialApp.router(
        theme: PulseTheme.light,
        darkTheme: PulseTheme.dark,
        themeMode: mode,
        routerConfig: GoRouter(
          routes: [GoRoute(path: '/', builder: (_, _) => screen)],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  group('backup screen', () {
    testWidgets('off: explains the feature and the no-recovery rule', (
      tester,
    ) async {
      final demo = DemoBackupController(initial: const BackupState());
      await _pump(
        tester,
        const BackupScreen(),
        overrides: [backupControllerProvider.overrideWithValue(demo)],
      );
      expect(find.text('Turn on encrypted backup'), findsOneWidget);
      expect(
        find.textContaining('nobody, including us, can recover it'),
        findsOneWidget,
      );
    });

    testWidgets(
      'on: shows last backed up, and a failure is calm and keeps the data message',
      (tester) async {
        final now = DateTime.utc(2026, 7, 1, 12);
        final demo = DemoBackupController(
          initial: BackupState(
            enabled: true,
            lastSuccess: now.subtract(const Duration(hours: 2)),
            lastError: 'No connection right now. We will try again on Wi-Fi.',
            failures: 3,
            dirty: true,
          ),
        );
        await _pump(
          tester,
          BackupScreen(now: now),
          overrides: [backupControllerProvider.overrideWithValue(demo)],
        );
        expect(find.text('Last backed up 2 hours ago'), findsOneWidget);
        expect(
          find.text('Your backup is behind'),
          findsOneWidget,
          reason: 'three failures in a row is worth a mention',
        );
        expect(
          find.textContaining('Your data is safe on this phone.'),
          findsOneWidget,
        );
        expect(find.textContaining('No connection right now'), findsOneWidget);
        expect(find.text('Back up now'), findsOneWidget);
        expect(find.text('Google Drive'), findsOneWidget);
        expect(
          find.text('Needs setup, not available in this build'),
          findsNWidgets(2),
        );
      },
    );
  });

  group('setup flow', () {
    testWidgets(
      'recovery phrase: must retype the right words before it can continue',
      (tester) async {
        final demo = DemoBackupController(initial: const BackupState());
        await _pump(
          tester,
          const BackupSetupScreen(fixedPhrase: _words),
          overrides: [backupControllerProvider.overrideWithValue(demo)],
        );
        expect(find.text('Recommended'), findsOneWidget);
        expect(find.textContaining('cannot be recovered'), findsOneWidget);
        await _tapText(tester, 'Continue');
        expect(find.text('abandon'), findsOneWidget);
        expect(find.text('accident'), findsOneWidget);
        await _tapText(tester, 'I have written it down');
        expect(find.text('Check your copy'), findsOneWidget);
        PrimaryButtonProbe get() => PrimaryButtonProbe(tester);
        expect(get().enabled('Continue'), isFalse);
        final fields = find.byType(TextField);
        expect(fields, findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          await tester.enterText(fields.at(i), 'wrong');
        }
        await tester.pump();
        expect(get().enabled('Continue'), isFalse);
        // fill with the real words for each hinted position
        for (var i = 0; i < 3; i++) {
          final hint = (tester
              .widget<TextField>(fields.at(i))
              .decoration!
              .hintText)!; // "Word 7"
          final n = int.parse(hint.split(' ').last);
          await tester.enterText(fields.at(i), _words[n - 1].toUpperCase());
        }
        await tester.pump();
        expect(get().enabled('Continue'), isTrue);
        await _tapText(tester, 'Continue');
        await _tapText(tester, 'Turn on backup');
        await tester.pump(const Duration(milliseconds: 300));
        expect(demo.state.enabled, isTrue);
        expect(demo.state.secretKind, 'phrase');
        expect(find.text('Backup is on'), findsOneWidget);
      },
    );

    testWidgets(
      'own passphrase: needs length, a match and the acknowledgement',
      (tester) async {
        final demo = DemoBackupController(initial: const BackupState());
        await _pump(
          tester,
          const BackupSetupScreen(),
          overrides: [backupControllerProvider.overrideWithValue(demo)],
        );
        await _tapText(tester, 'My own passphrase');
        await _tapText(tester, 'Continue');
        final fields = find.byType(TextField);
        final probe = PrimaryButtonProbe(tester);
        await tester.enterText(fields.at(0), 'short');
        await tester.enterText(fields.at(1), 'short');
        await tester.pump();
        expect(find.textContaining('Too short'), findsOneWidget);
        expect(probe.enabled('Continue'), isFalse);
        await tester.enterText(fields.at(0), 'four small words here');
        await tester.enterText(fields.at(1), 'four small words HERE');
        await tester.pump();
        expect(find.text('Does not match'), findsOneWidget);
        await tester.enterText(fields.at(1), 'four small words here');
        await tester.pump();
        expect(
          probe.enabled('Continue'),
          isFalse,
          reason: 'acknowledgement still missing',
        );
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(probe.enabled('Continue'), isTrue);
      },
    );
  });

  group('restore flow (scripted demo)', () {
    testWidgets('source, key, version list, restore, done', (tester) async {
      await _pump(
        tester,
        RestoreScreen(now: DateTime(2026, 7, 1, 12)),
        overrides: [
          restoreFlowProvider.overrideWith(
            (ref) async => DemoRestoreFlow(now: DateTime(2026, 7, 1, 12)),
          ),
        ],
      );
      expect(find.text('Restore from backup'), findsOneWidget);
      await _tapText(tester, 'From my Pulse account');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Enter your key'), findsOneWidget);
      expect(find.textContaining('no reset'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about',
      );
      await tester.pump();
      expect(find.text('Recovery phrase recognised'), findsOneWidget);
      await _tapText(tester, 'Unlock backup');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Choose a backup'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
      expect(
        find.text('1,342 records, 14 photos and documents'),
        findsOneWidget,
      );
      await _tapText(tester, 'Restore this backup');
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('You are back'), findsOneWidget);
    });
  });
}

/// Reads whether the primary button with [label] is tappable.
class PrimaryButtonProbe {
  PrimaryButtonProbe(this.tester);
  final WidgetTester tester;
  bool enabled(String label) =>
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, label))
          .onPressed !=
      null;
}
