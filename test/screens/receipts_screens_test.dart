// Renders the Email receipts settings row and an enriched transaction to PNG at 390x844.
// Skipped unless SCREENS_DIR is set, so it never touches the normal run:
//
//   SCREENS_DIR=/mnt/project-files/screens/v15 flutter test test/screens/receipts_screens_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

import 'package:pulse/data/models.dart';
import 'package:pulse/features/transactions/tx_detail_sheet.dart';

final _dir = Platform.environment['SCREENS_DIR'];

Future<void> _loadFonts() async {
  Future<ByteData> bytes(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());
  const inter = '/usr/share/fonts/opentype/inter';
  final text = FontLoader('PulseInter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    text.addFont(bytes('$inter/Inter-$w.otf'));
  }
  await text.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      bytes(
        '${Platform.environment['FLUTTER_ROOT'] ?? '/home/user/flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ),
    );
  await icons.load();
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('email receipts screens ($mode)', (tester) async {
      await tester.runAsync(_loadFonts);
      PulseTheme.useGoogleFonts = false;
      PulseTheme.testFontFamily = 'PulseInter';
      addTearDown(() => PulseTheme.testFontFamily = null);
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.platformBrightnessTestValue = dark
          ? Brightness.dark
          : Brightness.light;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final key = GlobalKey();

      Future<void> open(Widget Function() home) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                repositoryProvider.overrideWithValue(
                  MockPulseRepository(
                    latency: Duration.zero,
                    now: DateTime(2026, 11, 14),
                  ),
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
              ],
              child: home(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 3));
      }

      Future<void> shot(String name) async {
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.runAsync(() async {
          final b =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await b.toImage(pixelRatio: 1);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          final f = File('$_dir/$name-$mode.png');
          await f.create(recursive: true);
          await f.writeAsBytes(data!.buffer.asUint8List());
        });
      }

      await open(
        () => const PulseApp(initialLocation: '/settings/connections'),
      );
      final row = find.byKey(const Key('settings_email_receipts'));
      await tester.scrollUntilVisible(
        row,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.4);
      await tester.pump(const Duration(milliseconds: 500));
      await shot('settings-email-receipts');

      final tx = Transaction(
        id: 't1',
        merchant: 'noon supermall',
        amount: 147.5,
        category: SpendCategory.shopping,
        date: DateTime(2026, 3, 14, 10),
        source: TxSource.manual,
        cardId: 'c',
        accountLabel: 'Example Visa 1234',
        receiptRef: 'msg-1',
        receiptNotes:
            'Shipping fee: free\nSupermall service fees: AED 3.50\nExtended Warranty: AED 9.00\n'
            'Coupon: -AED 15.00\nCard cashback (estimate): AED 16.25',
      );
      await open(
        () => MaterialApp(
          theme: dark ? PulseTheme.dark : PulseTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(child: TxDetailSheet(tx: tx)),
          ),
        ),
      );
      await shot('transaction-with-receipt');
    }, skip: _dir == null);
  }
}
