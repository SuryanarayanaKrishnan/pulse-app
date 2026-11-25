// Realistic card face screens: Cards tab, detail, 24-card gallery, close-ups.
// Skipped unless SCREENS_DIR is set:
//
//   SCREENS_DIR=/mnt/project-files/screens/v20 SCREENS_PREFIX=after flutter test test/screens/v20_screens_test.dart
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/bugreport/shake_host.dart';
import 'package:pulse/bugreport/shake_detector.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/capture/providers.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/engine/card_art.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/core/widgets/card_face.dart';
import 'package:pulse/data/mock_repository.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/features/auth/session.dart';

final _dir = Platform.environment['SCREENS_DIR'];
final _prefix = Platform.environment['SCREENS_PREFIX'] ?? 'after';

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
  // The bundled display face, when present (after the redesign).
  final display = File('assets/fonts/Fraunces_600SemiBold.ttf');
  if (display.existsSync()) {
    final f = FontLoader('PulseDisplay')..addFont(bytes(display.path));
    await f.load();
  }
}

Future<void> _save(
  WidgetTester tester,
  GlobalKey key,
  String name, {
  double ratio = 1,
}) async {
  await tester.runAsync(() async {
    final b = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_dir/$_prefix-$name.png');
    await f.create(recursive: true);
    await f.writeAsBytes(data!.buffer.asUint8List());
  });
}

List<CardArtSpec> _gallery() {
  final fixture = (jsonDecode(
    File('test/fixtures/catalog_art.json').readAsStringSync(),
  ) as List).cast<Map<String, Object?>>();
  final specs = [
    for (final f in fixture)
      CardArtSpec.fromJson(Map<String, Object?>.from(f['art']! as Map)),
  ];
  final out = <CardArtSpec>[];
  void take(bool Function(CardArtSpec) test, int n) {
    var k = 0;
    for (final s in specs) {
      if (k >= n) break;
      if (out.contains(s) || !test(s)) continue;
      // Spread: skip every other candidate so the picks differ.
      if (specs.indexOf(s).isOdd && k.isEven) continue;
      out.add(s);
      k++;
    }
  }

  take(
    (s) => s.finish == CardFinish.metal && s.network == CardNetworkMark.visa,
    4,
  );
  take(
    (s) =>
        s.finish == CardFinish.metal && s.network == CardNetworkMark.mastercard,
    4,
  );
  take(
    (s) => s.finish == CardFinish.matte && s.network == CardNetworkMark.visa,
    3,
  );
  take(
    (s) =>
        s.finish == CardFinish.matte && s.network == CardNetworkMark.mastercard,
    2,
  );
  take(
    (s) => s.finish == CardFinish.gloss && s.network == CardNetworkMark.visa,
    4,
  );
  take(
    (s) =>
        s.finish == CardFinish.gloss && s.network == CardNetworkMark.mastercard,
    4,
  );
  take(
    (s) =>
        s.tier.toLowerCase().contains('infinite') ||
        s.tier.toLowerCase().contains('signature'),
    1,
  );
  // Amex: re-network three of the specs (the catalog has one real Amex).
  final base = CardArts.byCatalogId.values.toList();
  var i = 0;
  while (out.length < 24) {
    final b = base[i++ % base.length];
    out.add(CardArtSpec.fromJson({...b.toJson(), 'network': 'amex'}));
  }
  return out.take(24).toList();
}

void main() {
  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';
    testWidgets('v20 screens ($mode)', (tester) async {
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
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              repositoryProvider.overrideWithValue(
                MockPulseRepository(latency: Duration.zero),
              ),
              shakeSourceProvider.overrideWithValue(
                () => const Stream<Accel>.empty(),
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
            child: const PulseApp(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text('Cards').last);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await _save(tester, key, 'cards-$mode');
      await tester.tapAt(const Offset(195, 440));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await _save(tester, key, 'card-detail-$mode');
    }, skip: _dir == null);

    testWidgets('v20 gallery ($mode)', (tester) async {
      await tester.runAsync(_loadFonts);
      PulseTheme.useGoogleFonts = false;
      PulseTheme.testFontFamily = 'PulseInter';
      addTearDown(() => PulseTheme.testFontFamily = null);
      const w = 390.0;
      const cols = 2;
      const gap = 14.0;
      const cardW = (w - gap * 3) / cols;
      const cardH = cardW / 1.586;
      final specs = _gallery();
      final rows = (specs.length / cols).ceil();
      tester.view.physicalSize = Size(w * 2, (rows * (cardH + gap) + gap) * 2);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: dark ? PulseTheme.dark : PulseTheme.light,
            home: Scaffold(
              body: GridView.count(
                crossAxisCount: cols,
                padding: const EdgeInsets.all(gap),
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: 1.586,
                children: [
                  for (final s in specs)
                    CardFace(
                      art: s,
                      last4: '4821',
                      name: s.tier,
                      elevated: true,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await _save(tester, key, 'gallery-$mode', ratio: 2);
    }, skip: _dir == null);
  }

  // Large close-ups, one per material, for judging the realism of detail.
  testWidgets('v20 closeups', (tester) async {
    await tester.runAsync(_loadFonts);
    PulseTheme.useGoogleFonts = false;
    PulseTheme.testFontFamily = 'PulseInter';
    addTearDown(() => PulseTheme.testFontFamily = null);
    const w = 390.0;
    final a = CardArts.byCatalogId;
    final specs = [
      a['mashreq-solitaire']!,
      a['rakbank-titanium-credit-card']!,
      a['mashreq-noon-card']!,
      a['emirates-nbd-go4it']!,
      CardArtSpec.fromJson({
        ...a['standard-chartered-manhattan-rewards']!.toJson(),
        'network': 'amex',
      }),
    ];
    final cardH = (w - 32) / 1.586;
    tester.view.physicalSize = Size(
      w * 2,
      (specs.length * (cardH + 20) + 20) * 2,
    );
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: PulseTheme.light,
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final s in specs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: CardFace(
                      art: s,
                      last4: '4821',
                      name: '${s.bank} ${s.tier}',
                      elevated: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, key, 'closeups', ratio: 2);
  }, skip: _dir == null);
}
