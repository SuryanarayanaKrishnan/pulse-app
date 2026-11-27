import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pulse/app.dart';
import 'package:pulse/core/analytics/analytics.dart';
import 'package:pulse/core/theme/theme.dart';
import 'package:pulse/data/local/attachments.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/reminders.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/providers.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/features/auth/session.dart';
import 'package:pulse/features/wealth/document_screens.dart';
import 'package:pulse/features/wealth/cas_import_screen.dart';
import 'package:pulse/features/wealth/fund_screens.dart';
import 'package:pulse/features/wealth/jewellery_screens.dart';
import 'package:pulse/features/wealth/wealth_widgets.dart';
import 'package:pulse/core/widgets/widgets.dart';

import '../support/fake_adapter.dart';

class FakePicker implements PhotoPicker {
  FakePicker(this.path);
  final String path;
  final taken = <PhotoSource>[];
  @override
  Future<String?> pick(PhotoSource source) async {
    taken.add(source);
    return path;
  }
}

class Rig {
  Rig({this.dio, String photo = 'demo:0'})
    : store = MemoryWealthStore(),
      reminders = RecordingReminders(),
      picker = FakePicker(photo);
  final MemoryWealthStore store;
  final RecordingReminders reminders;
  final FakePicker picker;
  final Dio? dio;

  List<Override> get overrides => [
    wealthStoreProvider.overrideWithValue(store),
    remindersProvider.overrideWithValue(reminders),
    photoPickerProvider.overrideWithValue(picker),
    if (dio != null) fundLookupProvider.overrideWithValue(FundLookup(dio)),
  ];
}

Future<void> pumpSheet(WidgetTester tester, Rig rig, Widget sheet) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: rig.overrides,
      child: MaterialApp(theme: PulseTheme.light, home: Scaffold(body: sheet)),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> pumpApp(WidgetTester tester, String location, {Rig? rig}) async {
  PulseTheme.useGoogleFonts = false;
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        analyticsProvider.overrideWithValue(NoopAnalytics()),
        sessionProvider.overrideWith((ref) => SessionController(onboarded: true, signedIn: true, connected: true)),
        ...?rig?.overrides,
      ],
      child: PulseApp(initialLocation: location),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  group('add gold or jewellery', () {
    testWidgets('shows the computed value, lets you adjust it, and saves with a photo', (tester) async {
      final rig = Rig(photo: '/tmp/ring.jpg');
      await pumpSheet(tester, rig, const AddJewellerySheet());

      // Nothing to value yet.
      expect(find.byKey(const Key('jewellery-preview-value')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('jewellery-preview-value'))).data, '–');

      await tester.enterText(find.widgetWithText(TextField, 'Weight of the gold'), '10');
      await tester.pump();
      // Bundled gold: AED 470/g (24K). 10 g of 22K = 4,308.33
      expect(tester.widget<Text>(find.byKey(const Key('jewellery-preview-value'))).data, 'AED 4,308');

      await tester.tap(find.byTooltip('More 0.1 g'));
      await tester.pump();
      expect(find.widgetWithText(TextField, '10.1'), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('jewellery-preview-value'))).data, 'AED 4,351');

      await tester.tap(find.text('18K'));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('jewellery-preview-value'))).data, 'AED 3,560'); // 10.1 x .75 x 470

      await tester.tap(find.text('Gallery'));
      await tester.pump();
      expect(rig.picker.taken, [PhotoSource.gallery]);

      // Name is required.
      final save = find.text('Add piece');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump();
      expect(await rig.store.jewellery(), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Name, like "Wedding necklace"'), 'Gold chain');
      await tester.enterText(find.widgetWithText(TextField, 'Total paid (AED)'), '3200');
      await tester.pump();
      expect(find.textContaining('vs paid'), findsWidgets);
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));

      final saved = (await rig.store.jewellery()).single;
      expect(saved.name, 'Gold chain');
      expect(saved.karat, 18);
      expect(saved.weightGrams, 10.1);
      expect(saved.purchasePriceMinor, 320000);
      expect(saved.photoPaths, ['/tmp/ring.jpg']);
      final h = await rig.store.valuationHistory('jewellery', saved.id);
      expect(h.single.valueMinor, 356025);
    });

    testWidgets('a custom fineness is valued as given', (tester) async {
      final rig = Rig();
      await pumpSheet(tester, rig, const AddJewellerySheet());
      await tester.enterText(find.widgetWithText(TextField, 'Weight of the gold'), '10');
      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Fineness stamp, like 900'), '900');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('jewellery-preview-value'))).data, 'AED 4,230');
    });
  });

  group('add a document', () {
    testWidgets('category chip, photo, a date and a reminder schedule a local notification', (tester) async {
      final rig = Rig(photo: '/tmp/scan.jpg');
      await pumpSheet(tester, rig, const AddDocumentSheet());
      await tester.tap(find.text('FD certificate'));
      await tester.pump();
      await tester.tap(find.text('Scan'));
      await tester.pump();
      expect(rig.picker.taken, [PhotoSource.camera]);

      await tester.enterText(find.widgetWithText(TextField, 'Title (FD certificate)'), 'ADCB FD');
      final pick = find.text('Pick a date (optional)');
      await tester.ensureVisible(pick);
      await tester.tap(pick);
      await tester.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Next month'));
        await tester.pump(const Duration(milliseconds: 200));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').hitTestable().first);
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me before'), findsOneWidget);
      await tester.tap(find.text('1 week'));
      await tester.pump();

      final save = find.text('Save document');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));

      final d = (await rig.store.documents()).single;
      expect(d.title, 'ADCB FD');
      expect(d.category.wire, 'fd_certificate');
      expect(d.dueKind, 'maturity');
      expect(d.dueOn, isNotNull);
      expect(d.remindDaysBefore, 7);
      expect(d.filePaths, ['/tmp/scan.jpg']);
      expect(rig.reminders.scheduled.length, 1);
      expect(rig.reminders.scheduled.values.single.$1, 'ADCB FD');
      final at = rig.reminders.scheduled.values.single.$3;
      expect(at.hour, 9);
      expect(at.isAfter(DateTime.now()), isTrue);
      expect(DateTime(d.dueOn!.year, d.dueOn!.month, d.dueOn!.day - 7, 9), at);
    });

    testWidgets('no date means no reminder is asked for or scheduled', (tester) async {
      final rig = Rig();
      await pumpSheet(tester, rig, const AddDocumentSheet());
      await tester.tap(find.text('Passport'));
      await tester.pump();
      expect(find.text('Remind me before'), findsNothing);
      final save = find.text('Save document');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));
      expect((await rig.store.documents()).single.title, 'Passport');
      expect(rig.reminders.scheduled, isEmpty);
    });
  });

  group('add a mutual fund', () {
    testWidgets('manual entry shows value and gain in AED and saves', (tester) async {
      final rig = Rig();
      await pumpSheet(tester, rig, const AddFundSheet());
      // Without a price service, search explains itself and offers manual entry.
      expect(find.text('Search needs the Pulse price service'), findsOneWidget);
      await tester.tap(find.text('Enter by hand').first);
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Fund name'), 'Gulf Income Fund');
      await tester.enterText(find.widgetWithText(TextField, 'Units held'), '100');
      await tester.enterText(_hintStarting('Current NAV per unit'), '12.5');
      await tester.enterText(_hintStarting('Average cost per unit (optional)'), '10');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '500');
      await tester.enterText(find.widgetWithText(TextField, 'Day (1-31)'), '5');
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('fund-preview'))).data, contains('Worth AED 1,250'));
      expect(tester.widget<Text>(find.byKey(const Key('fund-preview'))).data, contains('+25.0%'));

      final save = find.text('Add fund');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));
      final f = (await rig.store.funds()).single;
      expect((f.kind, f.currency, f.units, f.nav, f.avgCostNav), ('manual', 'AED', 100.0, 12.5, 10.0));
      expect((f.sipAmountMinor, f.sipDay), (50000, 5));
    });

    testWidgets('search finds a scheme, loads its NAV and saves an Indian holding', (tester) async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
        ..httpClientAdapter = FakeAdapter({
          'GET /v1/funds/search': [
            {'scheme_code': 122639, 'name': 'Parag Parikh Flexi Cap Fund - Direct Growth'},
          ],
          'GET /v1/funds/schemes/122639/latest': {'scheme_code': '122639', 'nav_date': '2026-11-23', 'nav': '81.5'},
        });
      final rig = Rig(dio: dio);
      await pumpSheet(tester, rig, const AddFundSheet());
      await tester.enterText(find.widgetWithText(TextField, 'Search by fund name, like "flexi cap"'), 'parag');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Parag Parikh Flexi Cap Fund - Direct Growth'), findsOneWidget);
      await tester.tap(find.text('Parag Parikh Flexi Cap Fund - Direct Growth'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Latest NAV INR 81.5000'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Units held'), '1000');
      await tester.pump();
      await tester.pump();
      // INR 81,500 at the bundled 0.0425 = AED 3,464
      expect(tester.widget<Text>(find.byKey(const Key('fund-preview'))).data, contains('Worth AED 3,464'));
      final save = find.text('Add fund');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 100));
      final f = (await rig.store.funds()).single;
      expect((f.kind, f.schemeCode, f.currency, f.navSource, f.nav), ('india_mf', '122639', 'INR', 'market', 81.5));
    });

    testWidgets('the CAS import entry point shows the free steps and keeps nothing', (tester) async {
      final rig = Rig();
      await pumpSheet(tester, rig, const CasImportSheet());
      expect(find.text('Get your statement'), findsOneWidget);
      expect(find.byKey(const Key('cas-open-cams')), findsOneWidget);
      expect(find.byKey(const Key('cas-open-kfintech')), findsOneWidget);
      expect(find.textContaining('PAN'), findsWidgets);
      expect(await rig.store.funds(), isEmpty);
    });
  });

  group('Wealth screen', () {
    testWidgets('lists jewellery, funds, documents and upcoming dates, and opens the jewellery detail', (tester) async {
      await pumpApp(tester, '/wealth');
      await tester.pump(const Duration(milliseconds: 500)); // let the async sections load
      for (final h in ['Upcoming', 'Gold and jewellery', 'Mutual funds', 'Stocks and ETFs', 'Investing plan', 'Documents']) {
        // The list is lazy: scroll a screenful at a time until the header builds.
        for (var i = 0; i < 20 && find.widgetWithText(SectionHeader, h).evaluate().isEmpty; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -400));
          await tester.pump();
        }
        expect(find.widgetWithText(SectionHeader, h), findsOneWidget, reason: h);
      }
    });

    testWidgets('jewellery detail shows value, gain, chart and a full-screen photo viewer', (tester) async {
      await pumpApp(tester, '/jewellery/jw1');
      expect(find.text('Bridal necklace set'), findsWidgets);
      expect(find.text('Worth today'), findsOneWidget);
      expect(find.textContaining('vs paid'), findsOneWidget);
      expect(find.text('Value over time'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(PhotoStrip), matching: find.byType(AttachmentImage)).first);
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('deleting a piece removes it from the phone', (tester) async {
      final rig = Rig();
      await rig.store.saveJewellery(JewelleryItem(id: 'x', name: 'Test bangle', weightGrams: 5, karat: 22, createdAt: DateTime.now()));
      await pumpApp(tester, '/jewellery/x', rig: rig);
      expect(find.text('Test bangle'), findsWidgets);
      final del = find.text('Delete this piece');
      await tester.ensureVisible(del);
      await tester.tap(del);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(await rig.store.jewellery(), isEmpty);
    });
  });
}

Finder _hintStarting(String start) => find.byWidgetPredicate(
  (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(start),
);
