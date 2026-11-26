import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/capture/kv_store.dart';
import 'package:pulse/core/engine/cas_parser.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/cas_import_service.dart';
import 'package:pulse/data/local/live_prices.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/statement_service.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/wealth_service.dart';
import 'package:pulse/features/wealth/cas_import_screen.dart';

class _Http implements HttpClientAdapter {
  _Http(this.body);
  final String body;
  bool fail = false;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? s,
    Future<void>? c,
  ) async {
    if (fail)
      throw DioException(
        requestOptions: o,
        type: DioExceptionType.connectionError,
      );
    return ResponseBody.fromString(body, 200);
  }

  @override
  void close({bool force = false}) {}
}

/// Stands in for pdfrx: the "PDF" is locked until [password] is given.
class FakeCasExtractor implements PdfTextExtractor {
  FakeCasExtractor(this.text, {this.password = 'secret'});
  final String text;
  final String? password;
  final seen = <List<String>>[];
  @override
  Future<PdfReadResult> extract(Uint8List bytes, List<String> passwords) async {
    seen.add(passwords);
    if (password != null && !passwords.contains(password))
      return const PdfReadResult(PdfReadStatus.needsPassword);
    return PdfReadResult(PdfReadStatus.read, text);
  }
}

CasImportService build(
  MemoryWealthStore store,
  String text, {
  bool offline = false,
  String? password = 'secret',
  FakeCasExtractor? ex,
}) {
  final http = _Http(File('test/fixtures/navall_sample.txt').readAsStringSync())
    ..fail = offline;
  final now = DateTime.utc(2026, 11, 26);
  return CasImportService(
    extractor: ex ?? FakeCasExtractor(text, password: password),
    amfi: AmfiService(
      dio: Dio()..httpClientAdapter = http,
      cache: MemoryTextCache(),
      kv: MemoryKvStore(),
      clock: () => now,
      minSchemes: 1,
    ),
    wealth: WealthService(
      store: store,
      prices: PriceService(store: store),
      fundLookup: FundLookup(null),
      clock: () => now,
    ),
  );
}

void main() {
  final cas = File('test/fixtures/cas/cams_detailed_synthetic.txt')
      .readAsStringSync();
  final bytes = Uint8List.fromList([1, 2, 3]);

  group('CasImportService', () {
    test('locked PDF asks for a password; a wrong one is reported; the right one reads', () async {
      final svc = build(MemoryWealthStore(), cas);
      expect((await svc.read(bytes)).status, CasReadStatus.needsPassword);
      expect(
        (await svc.read(bytes, password: 'nope')).status,
        CasReadStatus.wrongPassword,
      );
      final ok = await svc.read(bytes, password: 'secret');
      expect(ok.status, CasReadStatus.ok);
      expect(ok.statement!.schemes, isNotEmpty);
    });

    test('non-CAS and demat text give a clear status', () async {
      expect(
        (await build(
          MemoryWealthStore(),
          'invoice',
          password: null,
        ).read(bytes)).status,
        CasReadStatus.notAFundStatement,
      );
      final demat = File('test/fixtures/cas/demat_synthetic.txt')
          .readAsStringSync();
      expect(
        (await build(MemoryWealthStore(), demat, password: null).read(bytes))
            .status,
        CasReadStatus.demat,
      );
    });

    test('preview: ISIN match, same scheme in two folios combined, closed skipped, unmatched flagged', () async {
      final svc = build(MemoryWealthStore(), cas);
      final p = await svc.preview(
        (await svc.read(bytes, password: 'secret')).statement!,
      );
      expect(p.closedSchemes, 1);
      expect(p.candidates, hasLength(3));
      final flexi = p.candidates.firstWhere((c) => c.schemeCode == '100001');
      expect(flexi.basis, MatchBasis.isin);
      expect(flexi.folios, 2);
      expect(flexi.units, closeTo(156.916, 1e-9));
      expect(flexi.avgCostNav, closeTo(32000 / 156.916, 1e-9));
      expect(flexi.nav, 215.1);
      expect(flexi.navDate, '2026-11-25');
      expect(
        flexi.sip,
        isNull,
      ); // last instalment is months before the statement end
      final liquid = p.candidates.firstWhere((c) => c.name.contains('Liquid'));
      expect(liquid.matched, isFalse);
      expect(liquid.flags.join(), contains('Not found in the AMFI list'));
      expect(liquid.approximate, isTrue);
      expect(
        p.candidates.firstWhere((c) => c.name.contains('Obscure')).avgCostNav,
        isNull,
      );
      expect(p.amfiAsOf, '2026-11-25');
    });

    test('offline AMFI: still previews, nothing matched, says so', () async {
      final svc = build(MemoryWealthStore(), cas, offline: true);
      final p = await svc.preview(
        (await svc.read(bytes, password: 'secret')).statement!,
      );
      expect(p.amfiOffline, isTrue);
      expect(p.candidates.every((c) => !c.matched), isTrue);
      expect(p.candidates.first.flags.join(), contains('Could not reach AMFI'));
    });

    test(
      'apply saves holdings only; re-import updates instead of duplicating',
      () async {
        final store = MemoryWealthStore();
        final svc = build(store, cas);
        Future<CasApplyReport> run() async {
          final p = await svc.preview(
            (await svc.read(bytes, password: 'secret')).statement!,
          );
          return svc.apply(p);
        }

        final r1 = await run();
        expect((r1.added, r1.updated, r1.manual), (3, 0, 2));
        final funds = await store.funds();
        expect(funds, hasLength(3));
        final flexi = funds.firstWhere((f) => f.schemeCode == '100001');
        expect(
          (flexi.kind, flexi.currency, flexi.navSource),
          ('india_mf', 'INR', 'market'),
        );
        expect(funds.where((f) => f.kind == 'manual'), hasLength(2));
        expect(funds.where((f) => f.navSource == 'statement'), hasLength(2));

        final r2 = await run();
        expect((r2.added, r2.updated), (0, 3));
        expect(
          await store.funds(),
          hasLength(3),
        ); // the two manual ones are not matchable, so they are added again
      },
    );

    test(
      'unchecked rows are not saved and a SIP hint is saved only when kept',
      () async {
        final store = MemoryWealthStore();
        final svc = build(store, cas);
        final st = (await svc.read(bytes, password: 'secret')).statement!;
        // Pretend the statement ended in May 2026 so the SIP is still running.
        final p = await svc.preview(_end(st, '2026-05-20'));
        final flexi = p.candidates.firstWhere((c) => c.schemeCode == '100001');
        expect(flexi.sip, isNotNull);
        expect(flexi.useSip, isTrue); // labelled by the statement
        for (final c in p.candidates.where((c) => c != flexi)) {
          c.include = false;
        }
        flexi.useSip = false;
        await svc.apply(p);
        final saved = await store.funds();
        expect(saved, hasLength(1));
        expect(saved.single.hasSip, isFalse);
        final p2 = await svc.preview(_end(st, '2026-05-20'));
        p2.candidates.firstWhere((c) => c.schemeCode == '100001').useSip = true;
        for (final c in p2.candidates.where((c) => c.schemeCode != '100001')) {
          c.include = false;
        }
        expect((await svc.apply(p2)).updated, 1);
        final again = (await store.funds()).firstWhere(
          (f) => f.schemeCode == '100001',
        );
        expect((again.sipAmountMinor, again.sipDay), (500000, 5));
      },
    );
  });

  group('Get your statement screen', () {
    Future<void> pump(
      WidgetTester t,
      MemoryWealthStore store,
      FakeCasExtractor ex, {
      List<String>? opened,
      bool offline = false,
    }) async {
      PulseTheme.useGoogleFonts = false;
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final svc = build(store, cas, ex: ex, offline: offline);
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            casImportServiceProvider.overrideWithValue(svc),
            casPdfPickerProvider.overrideWithValue(
              () async => (bytes: bytes, name: 'cas.pdf'),
            ),
            casLinkOpenerProvider.overrideWithValue(
              (u) async => opened?.add(u),
            ),
            wealthStoreProvider.overrideWithValue(store),
          ],
          child: MaterialApp(
            theme: PulseTheme.light,
            home: const Scaffold(body: CasImportSheet()),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('steps, deep links, password, preview and confirm', (t) async {
      final store = MemoryWealthStore();
      final opened = <String>[];
      final ex = FakeCasExtractor(cas);
      await pump(t, store, ex, opened: opened);
      await t.ensureVisible(find.byKey(const Key('cas-open-cams')));
      await t.tap(find.byKey(const Key('cas-open-cams')));
      await t.tap(find.byKey(const Key('cas-open-kfintech')));
      expect(opened, [camsCasUrl, kfintechCasUrl]);

      await t.ensureVisible(find.byKey(const Key('cas-have-pdf')));
      await t.tap(find.byKey(const Key('cas-have-pdf')));
      await t.pumpAndSettle();
      expect(find.text('Statement password'), findsOneWidget);

      await t.enterText(find.byKey(const Key('cas-password')), 'wrong');
      await t.tap(find.byKey(const Key('cas-open')));
      await t.pumpAndSettle();
      expect(
        find.text('That password did not open the statement'),
        findsOneWidget,
      );

      await t.enterText(find.byKey(const Key('cas-password')), 'secret');
      await t.tap(find.byKey(const Key('cas-open')));
      await t.pumpAndSettle();
      expect(find.text('Review 3 funds'), findsOneWidget);
      expect(find.textContaining('2 folios combined'), findsOneWidget);
      expect(find.textContaining('Not found in the AMFI list'), findsWidgets);
      expect(await store.funds(), isEmpty); // nothing saved before confirming

      final confirm = find.byKey(const Key('cas-confirm'));
      await t.ensureVisible(confirm);
      await t.tap(confirm);
      await t.pumpAndSettle();
      expect(find.byKey(const Key('cas-done')), findsOneWidget);
      expect(await store.funds(), hasLength(3));
    });

    testWidgets(
      'a file that is not a CAS shows a clear problem and saves nothing',
      (t) async {
        final store = MemoryWealthStore();
        await pump(
          t,
          store,
          FakeCasExtractor('Electricity bill', password: null),
        );
        await t.ensureVisible(find.byKey(const Key('cas-have-pdf')));
        await t.tap(find.byKey(const Key('cas-have-pdf')));
        await t.pumpAndSettle();
        expect(find.byKey(const Key('cas-problem')), findsOneWidget);
        expect(find.textContaining('CAMS or KFintech'), findsWidgets);
        expect(await store.funds(), isEmpty);
      },
    );
  });
}

CasStatement _end(CasStatement st, String end) => CasStatement(
  schemes: st.schemes,
  periodFrom: st.periodFrom,
  periodTo: end,
  warnings: st.warnings,
  kind: st.kind,
);
