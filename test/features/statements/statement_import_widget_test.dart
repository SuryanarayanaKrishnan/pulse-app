import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart' show pdfrxInitialize;
import 'package:pulse/core/network/cloud_access.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/api/api_exception.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/statement_password_store.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/statements/statement_actions.dart';
import 'package:pulse/features/statements/statements_screen.dart';

Uint8List _fx(String name) {
  final f = File('test/fixtures/statement_import/$name');
  return f.existsSync()
      ? f.readAsBytesSync()
      : File('test/fixtures/statements/$name').readAsBytesSync();
}

void main() {
  late PulseDatabase db;
  late MemoryStatementPasswordStore passwords;
  late LocalStatementService svc;
  late SessionController session;

  setUp(() {
    PulseTheme.useGoogleFonts = false;
    db = PulseDatabase(NativeDatabase.memory());
    passwords = MemoryStatementPasswordStore();
    svc = LocalStatementService(
      db: db,
      passwords: passwords,
      extractor: const PdfrxTextExtractor(initialize: pdfrxInitialize),
    );
    session = SessionController(
      onboarded: true,
      signedIn: true,
      connected: true,
    );
  });
  tearDown(() => db.close());

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) action, {
    CloudAccess cloud = CloudAccess.unavailable,
  }) async {
    tester.view.physicalSize = const Size(1170, 4800);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStatementServiceProvider.overrideWithValue(svc),
          statementPasswordStoreProvider.overrideWithValue(passwords),
          cloudAccessProvider.overrideWithValue(cloud),
          sessionProvider.overrideWith((ref) => session),
        ],
        child: MaterialApp(
          theme: PulseTheme.light,
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => Center(
                child: TextButton(
                  onPressed: () => action(ctx, ref),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// File reading (pdfrx, drift) is real async work, not fake time: wait on
  /// the clock until [finder] shows, then let the sheet animation finish.
  Future<void> until(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> go(WidgetTester tester, Finder waitFor) async {
    await tester.tap(find.text('go'));
    await until(tester, waitFor);
  }

  Future<void> importFile(
    WidgetTester tester,
    Uint8List bytes,
    String name,
    String waitForText,
  ) async {
    await open(
      tester,
      (c, ref) => importStatementBytes(c, ref, bytes: bytes, filename: name),
    );
    await go(tester, find.text(waitForText));
  }

  group('a refused file says why and what to do', () {
    testWidgets('empty', (tester) async {
      await importFile(tester, Uint8List(0), 'a.pdf', 'That file is empty');
      expect(find.text('That file is empty'), findsOneWidget);
      expect(find.textContaining('iCloud'), findsOneWidget);
      expect(find.text('Choose another file'), findsOneWidget);
      expect(find.text('Send us a sample'), findsNothing);
    });

    testWidgets('wrong format (a picture)', (tester) async {
      await importFile(
        tester,
        Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]),
        'shot.png',
        'Not a statement file',
      );
      expect(find.text('Not a statement file'), findsOneWidget);
      expect(find.textContaining('screenshot capture'), findsOneWidget);
    });

    testWidgets('old Excel', (tester) async {
      await importFile(
        tester,
        Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0]),
        'old.xls',
        'Old Excel file',
      );
      expect(find.text('Old Excel file'), findsOneWidget);
      expect(find.textContaining('.xlsx'), findsOneWidget);
    });

    testWidgets('scanned PDF', (tester) async {
      await importFile(
        tester,
        _fx('scanned.pdf'),
        'scan.pdf',
        'This PDF is a scan',
      );
      expect(find.text('This PDF is a scan'), findsOneWidget);
      expect(find.textContaining('CSV'), findsOneWidget);
    });

    testWidgets('bank not supported offers a sample', (tester) async {
      await importFile(
        tester,
        _fx('unknown_layout.pdf'),
        'letter.pdf',
        'Bank not supported yet',
      );
      expect(find.text('Bank not supported yet'), findsOneWidget);
      expect(find.text('Send us a sample'), findsOneWidget);
      expect(find.text('Choose the columns'), findsNothing);
    });

    testWidgets('unknown CSV columns can be mapped by hand', (tester) async {
      await importFile(
        tester,
        _fx('unknown_columns.csv'),
        'x.csv',
        'Columns not recognised',
      );
      expect(find.text('Columns not recognised'), findsOneWidget);
      expect(find.text('Send us a sample'), findsOneWidget);
      await tester.tap(find.text('Choose the columns'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      // Pulse guessed date, description and amount; the amounts are signed.
      await tester.tap(find.byKey(const Key('map_positive')));
      await tester.pump();
      await tester.tap(find.text('Read the statement'));
      await until(tester, find.text('Read x.csv.'));
      expect(find.text('Read x.csv.'), findsOneWidget);
      expect(await db.select(db.statementLines).get(), hasLength(3));
    });
  });

  group('a locked PDF', () {
    Future<void> pickBank(WidgetTester tester) async {
      await tester.tap(find.text('Emirates NBD'));
      await tester.pump();
    }

    testWidgets(
      'prompts for the password, rejects a wrong one, then reads it',
      (tester) async {
        await importFile(
          tester,
          _fx('synthetic_card_locked.pdf'),
          's.pdf',
          'Statement password',
        );
        expect(find.text('Statement password'), findsOneWidget);
        await pickBank(tester);

        await tester.enterText(find.byType(TextField), 'wrong-one');
        await tester.pump();
        await tester.tap(find.text('Save password'));
        await until(tester, find.byKey(const Key('password_notice')));
        expect(find.byKey(const Key('password_notice')), findsOneWidget);
        expect(
          find.textContaining('did not open this statement'),
          findsOneWidget,
        );
        expect((await passwords.saved()), isEmpty); // the wrong one is not kept

        await tester.enterText(find.byType(TextField), '19804567');
        await tester.pump();
        await tester.tap(find.text('Save password'));
        for (
          var i = 0;
          i < 100 && (await svc.statements()).single.parse.name != 'parsed';
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
        }
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Statement password'), findsNothing);
        expect((await svc.statements()).single.parse.name, 'parsed');
      },
    );
  });

  group('needs a Pulse account', () {
    testWidgets('Gmail without a backend: calm state, no sign-in button', (
      tester,
    ) async {
      await open(tester, (c, ref) => connectGmail(c, ref));
      await go(tester, find.text("Available once you're signed in"));
      expect(find.text("Available once you're signed in"), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets(
      'Gmail with a backend but signed out: Sign in opens the sign-in screen',
      (tester) async {
        await open(
          tester,
          (c, ref) => connectGmail(c, ref),
          cloud: CloudAccess.signedOut,
        );
        await go(tester, find.text("Available once you're signed in"));
        expect(find.text("Available once you're signed in"), findsOneWidget);
        expect(session.signedIn, isTrue);
        await tester.tap(find.text('Sign in'));
        await tester.pump();
        expect(session.signedIn, isFalse);
      },
    );

    testWidgets(
      'the statements screen shows the gate on Gmail and keeps file import',
      (tester) async {
        tester.view.physicalSize = const Size(1170, 4800);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cloudAccessProvider.overrideWithValue(CloudAccess.unavailable),
              statementsProvider.overrideWith((ref) async => []),
              emailConnectionsProvider.overrideWith((ref) async => []),
              statementPasswordsProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: PulseTheme.light,
              home: const StatementsScreen(),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(find.text("Available once you're signed in"), findsOneWidget);
        expect(find.text('Add a statement'), findsOneWidget);
        expect(find.text('Connect'), findsNothing);
      },
    );

    test('shared features fail with one consistent message', () {
      final e = NeedsSignInException('Splitting with others');
      expect(e, isA<ApiException>());
      expect(
        e.message,
        "Splitting with others is available once you're signed in.",
      );
      expect(e.code, 'needs_sign_in');
    });
  });
}
