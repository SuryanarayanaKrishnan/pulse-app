import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/budget_file.dart';
import 'package:pulse/core/engine/sheet_import.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/budgets/budget_import_screen.dart';

Uint8List _file(String name) =>
    File('test/fixtures/sheets/$name').readAsBytesSync();

String _why(Uint8List b, String name) {
  try {
    readBudgetFile(b, name);
  } on FormatException catch (e) {
    return e.message;
  }
  fail('expected a refusal');
}

void main() {
  group('Excel and CSV from Files read on the phone, no sign-in', () {
    test('a CSV', () {
      final a = analyzeSheets(
        readBudgetFile(_file('budget_grid.csv'), 'budget.csv'),
      );
      expect(a.isEmpty, isFalse);
    });

    test('an .xlsx workbook reads the same as the CSV', () {
      final csv = analyzeSheets(
        readBudgetFile(_file('budget_grid.csv'), 'budget.csv'),
      );
      final xlsx = analyzeSheets(
        readBudgetFile(_file('budget_grid.xlsx'), 'budget.xlsx'),
      );
      expect(xlsx.isEmpty, isFalse);
      expect(xlsx.labels.keys.toSet(), csv.labels.keys.toSet());
    });

    test('a tab-separated text export', () {
      final tsv = Uint8List.fromList(
        'Item\tAmount\nRent\t2000\nGroceries\t600\n'.codeUnits,
      );
      expect(analyzeSheets(readBudgetFile(tsv, 'budget.tsv')).isEmpty, isFalse);
    });
  });

  group('a file that cannot be read says what it is', () {
    test('empty', () => expect(_why(Uint8List(0), 'a.csv'), contains('empty')));
    test(
      'old .xls',
      () => expect(
        _why(Uint8List.fromList([0xD0, 0xCF, 0x11, 0xE0, 0, 0]), 'a.xls'),
        contains('.xlsx'),
      ),
    );
    test(
      'a PDF',
      () => expect(
        _why(Uint8List.fromList('%PDF-1.4 x'.codeUnits), 'a.pdf'),
        contains('PDF'),
      ),
    );
    test(
      'a picture',
      () => expect(
        _why(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2]), 'a.png'),
        contains('picture'),
      ),
    );
    test(
      'a Numbers file',
      () => expect(
        _why(
          Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]),
          'b.numbers',
        ),
        contains('Export'),
      ),
    );
    test(
      'a zip that is not a workbook',
      () => expect(
        _why(Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0]), 'b.xlsx'),
        contains('not an Excel'),
      ),
    );
    test(
      'binary junk',
      () => expect(
        _why(Uint8List.fromList([1, 0, 2, 0]), 'x.bin'),
        contains('neither'),
      ),
    );
  });

  group('the Google Sheets link', () {
    Future<void> open(
      WidgetTester tester,
      Future<Uint8List> Function(String) fetch,
    ) async {
      PulseTheme.useGoogleFonts = false;
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(
              MockPulseRepository(latency: Duration.zero),
            ),
            analyticsProvider.overrideWithValue(NoopAnalytics()),
            kvStoreProvider.overrideWithValue(MemoryKvStore()),
            sessionProvider.overrideWith(
              (ref) => SessionController(
                onboarded: true,
                signedIn: true,
                connected: true,
              ),
            ),
            sheetFetcherProvider.overrideWithValue(fetch),
          ],
          child: const PulseApp(initialLocation: '/budget-import'),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.enterText(
        find.byKey(const Key('import_link')),
        'https://docs.google.com/spreadsheets/d/1AbCdEfGhIjKlMnOpQrStUvWxYz0123456789/edit',
      );
      await tester.tap(find.text('Read the sheet'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('a shared workbook is read', (tester) async {
      await open(tester, (_) async => _file('budget_grid.xlsx'));
      expect(find.textContaining('We found'), findsOneWidget);
    });

    testWidgets('a private sheet gets a plain next step, not a crash', (
      tester,
    ) async {
      await open(
        tester,
        (_) => throw const SheetLinkException(
          'That sheet is private. Sharing step.',
        ),
      );
      expect(find.byKey(const Key('import_error')), findsOneWidget);
      expect(find.textContaining('That sheet is private'), findsOneWidget);
    });

    testWidgets('a file from Files is still offered when the link fails', (
      tester,
    ) async {
      await open(tester, (_) => throw StateError('offline'));
      expect(find.textContaining('Download it as Excel'), findsOneWidget);
      expect(find.text('Choose a file'), findsOneWidget);
    });
  });
}
