// Renders the Family vault screens to PNG at 390x844.
// Skipped unless SCREENS_DIR is set:
//
//   SCREENS_DIR=/mnt/project-files/screens/v16 flutter test test/screens/vault_screens_test.dart
@TestOn('vm')
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/vault/release.dart';
import 'package:pulse/core/vault/vault_models.dart';
import 'package:pulse/data/local/vault_store.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/vault/entry_sheet.dart';
import 'package:pulse/features/vault/nominee_sheet.dart';
import 'package:pulse/features/vault/vault_screen.dart';

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

final _t0 = DateTime(2026, 11, 1);
VaultEntry _e(
  String id,
  VaultType t,
  String inst,
  String title,
  String where, {
  int? value,
  String nominee = '',
}) => VaultEntry(
  id: id,
  type: t,
  institution: inst,
  title: title,
  whereToFind: where,
  estimatedValueMinor: value,
  nomineeName: nominee,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('family vault screens ($mode)', (tester) async {
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

      final sara = Nominee(
        id: 'n1',
        name: 'Sara',
        relationship: 'Wife',
        contact: '+971 50 000 0000',
        createdAt: _t0,
      );
      final store = MemoryVaultStore(
        entries: [
          _e(
            '1',
            VaultType.bank,
            'Mashreq',
            'Salary account',
            'Statements in the grey folder, app on my phone',
            value: 1850000,
            nominee: 'Sara',
          ),
          _e(
            '2',
            VaultType.bank,
            'Emirates NBD',
            'Savings',
            'Branch at Dubai Mall, ask for the relationship manager',
          ),
          _e(
            '3',
            VaultType.card,
            'ADCB',
            'Visa ending 4242',
            'Statements by email',
          ),
          _e(
            '4',
            VaultType.insurance,
            'Sukoon',
            'Term life',
            'Policy in the safe, agent Ravi on 04 000 0000',
            value: 100000000,
          ),
          _e(
            '5',
            VaultType.property,
            'Marina apartment',
            '',
            'Title deed in the bank locker, Ejari in the filing box',
          ),
          _e(
            '6',
            VaultType.identity,
            'Passport and Emirates ID',
            '',
            'Originals in the safe, scans in the Documents folder',
          ),
        ],
        nominees: [
          sara,
          Nominee(
            id: 'n2',
            name: 'Imran',
            relationship: 'Brother',
            entryIds: {'4', '5'},
            createdAt: _t0,
          ),
        ],
      )..settings['vault.owner_name'] = 'Omar';

      Future<void> open(Widget Function() home) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: ProviderScope(
              overrides: [
                vaultStoreProvider.overrideWithValue(store),
                analyticsProvider.overrideWithValue(NoopAnalytics()),
                repositoryProvider.overrideWithValue(
                  MockPulseRepository(
                    latency: Duration.zero,
                    now: DateTime(2026, 11, 14),
                  ),
                ),
                inactivityRelayProvider.overrideWithValue(
                  const UnavailableInactivityRelay(),
                ),
              ],
              child: MaterialApp(
                theme: dark ? PulseTheme.dark : PulseTheme.light,
                home: home(),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 300));
        }
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

      await open(() => const VaultScreen());
      await shot('vault-home');
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('vault-people-checkin');

      await open(() => const Scaffold(body: EntrySheet()));
      await tester.enterText(
        find.byKey(const Key('vault_institution')),
        'ADCB',
      );
      await tester.enterText(
        find.byKey(const Key('vault_where')),
        'Card 4111 1111 1111 1111 in my wallet',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shot('vault-entry-guard');

      await open(() => const PreviewScreen(nomineeId: 'n2'));
      await shot('vault-preview');

      await open(() => Scaffold(body: KitSheet(nominee: sara)));
      await tester.tap(find.byKey(const Key('kit_make')));
      await tester.pump(const Duration(milliseconds: 600));
      await shot('vault-release-kit');
    }, skip: _dir == null);
  }
}
