import '../core/engine/dates.dart';
import '../core/engine/prices.dart';
import '../core/engine/valuation.dart';
import 'local/attachments.dart';
import 'local/price_service.dart';
import 'local/reminders.dart';
import 'local/wealth_store.dart';
import 'models.dart';
import 'wealth_models.dart';

class JewelleryView {
  const JewelleryView(this.item, this.value);
  final JewelleryItem item;
  final JewelleryValue value;
}

class FundView {
  const FundView(this.holding, this.value);
  final FundHolding holding;
  final FundValue value;
}

enum UpcomingKind { document, sip }

/// One line in the Wealth "upcoming" list.
class UpcomingItem {
  const UpcomingItem({required this.kind, required this.refId, required this.title, required this.detail, required this.date, required this.status});
  final UpcomingKind kind;
  final String refId, title, detail;
  final CalDate date;
  final DueStatus status;
}

/// Everything Wealth does with jewellery, documents and funds, on the phone:
/// storage, local valuation from the cached price book, photos in
/// app-private storage and scheduled reminders. Only price and NAV lookups
/// ever leave the phone (through [PriceService] and [FundLookup]), and they
/// carry no personal data.
class WealthService {
  WealthService({
    required this.store,
    required this.prices,
    required this.fundLookup,
    Reminders? reminders,
    AttachmentStorage? storage,
    DateTime Function()? clock,
  }) : reminders = reminders ?? const NoopReminders(),
       storage = storage ?? MemoryAttachmentStorage(),
       _clock = clock ?? DateTime.now;

  final WealthStore store;
  final PriceService prices;
  final FundLookup fundLookup;
  final Reminders reminders;
  final AttachmentStorage storage;
  final DateTime Function() _clock;

  CalDate get today {
    final n = _clock();
    return CalDate(n.year, n.month, n.day);
  }

  Future<PriceBook> book() => prices.current();

  JewelleryValue valueOfJewellery(JewelleryItem i, PriceBook book) => valueJewelleryItem(i, book.gold24 ?? 0);

  FundValue valueOfFund(FundHolding f, PriceBook book) =>
      valueFund(units: f.units, nav: f.nav, avgCostNav: f.avgCostNav, fxToAed: book.fx(f.currency));

  // ---- jewellery -------------------------------------------------------------

  Future<List<JewelleryView>> jewelleryViews() async {
    final b = await book();
    return [for (final i in await store.jewellery()) JewelleryView(i, valueOfJewellery(i, b))];
  }

  /// Saves the piece. [newPhotoSources] are temporary picker files that get
  /// copied into app-private storage; [removedPhotos] are deleted from it.
  Future<JewelleryItem> saveJewellery(
    JewelleryItem item, {
    List<String> newPhotoSources = const [],
    List<String> removedPhotos = const [],
  }) async {
    final copied = [for (final s in newPhotoSources) await storage.import(s)];
    final kept = [for (final p in item.photoPaths) if (!removedPhotos.contains(p)) p];
    final saved = await store.saveJewellery(item.copyWith(photoPaths: [...kept, ...copied]));
    await storage.delete(removedPhotos);
    final b = await book();
    final v = valueOfJewellery(saved, b);
    await store.recordValuation('jewellery', saved.id, today, v.valueMinor, unitPrice: v.pricePerGram);
    return saved;
  }

  Future<void> deleteJewellery(String id) async {
    final item = (await store.jewellery()).where((e) => e.id == id).firstOrNull;
    await store.deleteJewellery(id);
    if (item != null) await storage.delete(item.photoPaths);
  }

  Future<List<ValuationPoint>> jewelleryHistory(String id) => store.valuationHistory('jewellery', id);

  /// Writes today's valuation of every piece and fund from the current book.
  Future<void> recordValuations() async {
    final b = await book();
    for (final i in await store.jewellery()) {
      final v = valueOfJewellery(i, b);
      await store.recordValuation('jewellery', i.id, today, v.valueMinor, unitPrice: v.pricePerGram);
    }
    for (final f in await store.funds()) {
      final v = valueOfFund(f, b);
      if (v.valueAedMinor != null) await store.recordValuation('fund', f.id, today, v.valueAedMinor!, unitPrice: f.nav);
    }
  }

  // ---- documents -------------------------------------------------------------

  Future<List<WealthDocument>> documents() => store.documents();

  Future<WealthDocument> saveDocument(
    WealthDocument doc, {
    List<String> newFileSources = const [],
    List<String> removedFiles = const [],
  }) async {
    final copied = [for (final s in newFileSources) await storage.import(s)];
    final kept = [for (final p in doc.filePaths) if (!removedFiles.contains(p)) p];
    final nid = doc.notificationId ?? notificationIdFor(doc.id);
    final withFiles = WealthDocument(
      id: doc.id,
      title: doc.title,
      category: doc.category,
      notes: doc.notes,
      filePaths: [...kept, ...copied],
      dueOn: doc.dueOn,
      dueKind: doc.dueKind,
      remindDaysBefore: doc.remindDaysBefore,
      notificationId: nid,
      createdAt: doc.createdAt,
    );
    final saved = await store.saveDocument(withFiles);
    await storage.delete(removedFiles);
    await _schedule(saved);
    return saved;
  }

  Future<void> deleteDocument(String id) async {
    final doc = (await store.documents()).where((e) => e.id == id).firstOrNull;
    await store.deleteDocument(id);
    if (doc != null) {
      await reminders.cancel(doc.notificationId ?? notificationIdFor(doc.id));
      await storage.delete(doc.filePaths);
    }
  }

  Future<void> _schedule(WealthDocument d) async {
    final id = d.notificationId ?? notificationIdFor(d.id);
    await reminders.cancel(id);
    final due = d.dueOn, days = d.remindDaysBefore;
    if (due == null || days == null) return;
    final at = reminderTime(due, days, _clock());
    if (at == null) return;
    final when = days == 0 ? 'today' : 'in $days ${days == 1 ? 'day' : 'days'}';
    await reminders.schedule(id: id, title: d.title, body: '${d.dueLabel} $when (${d.category.label})', at: at);
  }

  /// Re-registers every reminder; safe to call on each app open (after a
  /// reboot, a restore or a clock change).
  Future<void> rescheduleReminders() async {
    for (final d in await store.documents()) {
      await _schedule(d);
    }
  }

  /// Asks the OS for notification permission, once the user opts in to a reminder.
  Future<bool> requestReminderPermission() => reminders.requestPermission();

  // ---- funds -------------------------------------------------------------------

  Future<List<FundView>> fundViews() async {
    final b = await book();
    return [for (final f in await store.funds()) FundView(f, valueOfFund(f, b))];
  }

  Future<FundHolding> saveFund(FundHolding f) async {
    final saved = await store.saveFund(f);
    final b = await book();
    final v = valueOfFund(saved, b);
    if (v.valueAedMinor != null) await store.recordValuation('fund', saved.id, today, v.valueAedMinor!, unitPrice: saved.nav);
    return saved;
  }

  Future<void> deleteFund(String id) => store.deleteFund(id);

  Future<List<FundScheme>> searchFunds(String q) => fundLookup.search(q);

  /// Updates the NAV of every searched (Indian) holding from the backend.
  /// Manual holdings are left alone. Returns how many were updated.
  Future<int> refreshNavs() async {
    if (!fundLookup.available) return 0;
    var n = 0;
    for (final f in await store.funds()) {
      final code = f.schemeCode;
      if (!f.isIndian || code == null) continue;
      try {
        final nav = await fundLookup.latest(code);
        if (nav == null) continue;
        await store.saveFund(f.copyWith(nav: nav.nav, navDate: nav.navDate, navSource: 'market', navFetchedAt: _clock().toUtc()));
        n++;
      } on Object {
        // Offline or the source is down: keep the last NAV.
      }
    }
    return n;
  }

  // ---- upcoming ----------------------------------------------------------------

  Future<List<UpcomingItem>> upcoming({int sipWithinDays = 31}) async {
    final t = today;
    final out = <UpcomingItem>[];
    for (final d in await store.documents()) {
      final due = d.dueOn;
      if (due == null) continue;
      out.add(UpcomingItem(
        kind: UpcomingKind.document,
        refId: d.id,
        title: d.title,
        detail: '${d.dueLabel} ${dueText(due, t)} · ${d.category.label}',
        date: due,
        status: dueStatus(due, t),
      ));
    }
    for (final f in await store.funds()) {
      if (!f.hasSip) continue;
      final next = nextSipDate(f.sipDay!, t);
      if (next.daysSince(t) > sipWithinDays) continue;
      out.add(UpcomingItem(
        kind: UpcomingKind.sip,
        refId: f.id,
        title: '${f.name} SIP',
        detail: 'SIP ${dueText(next, t)} · ${f.currency} ${(f.sipAmountMinor! / 100).toStringAsFixed(0)}',
        date: next,
        status: dueStatus(next, t),
      ));
    }
    out.sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  // ---- net worth -----------------------------------------------------------------

  /// Jewellery and funds as net-worth assets, revalued from [book]. A fund in
  /// a currency with no FX rate is left out and its absence is explained in
  /// the note of the funds' remaining rows rather than guessed.
  Future<List<Asset>> assets({PriceBook? priceBook}) async {
    final b = priceBook ?? await book();
    final out = <Asset>[];
    for (final i in await store.jewellery()) {
      final v = valueOfJewellery(i, b);
      out.add(Asset(
        id: 'jewel:${i.id}',
        name: i.name,
        kind: AssetKind.gold,
        value: v.valueMinor / 100,
        note: '${i.weightGrams.toStringAsFixed(i.weightGrams == i.weightGrams.roundToDouble() ? 0 : 1)} g · ${i.purityLabel}',
      ));
    }
    for (final f in await store.funds()) {
      final v = valueOfFund(f, b);
      if (v.valueAedMinor == null) continue;
      out.add(Asset(
        id: 'fund:${f.id}',
        name: f.name,
        kind: AssetKind.funds,
        value: v.valueAedMinor! / 100,
        note: '${_units(f.units)} units · NAV ${f.currency} ${f.nav.toStringAsFixed(2)}',
      ));
    }
    return out;
  }

  static String _units(double u) => u == u.roundToDouble() ? u.toStringAsFixed(0) : u.toStringAsFixed(3);
}

/// A piece valued at a 24k price in AED per gram.
JewelleryValue valueJewelleryItem(JewelleryItem i, double aedPerGram24) => valueJewellery(
  weightGrams: i.weightGrams,
  aedPerGram24: aedPerGram24,
  karat: i.karat,
  purity: i.purityOverride,
  purchasePriceMinor: i.purchasePriceMinor,
  makingChargesMinor: i.makingChargesMinor,
);

/// The "Live values" rows for the Wealth screen from a price book.
List<PriceInput> priceInputs(PriceBook b) {
  String src(PriceQuote q) => b.origin == PriceOrigin.bundled || q.source == null ? 'Demo value' : q.source!;
  final out = <PriceInput>[];
  for (final k in const [24, 22]) {
    final q = b.quote('XAU_AED_G_${k}K');
    if (q != null) {
      out.add(PriceInput(name: 'Gold ${k}K', value: 'AED ${q.price.toStringAsFixed(2)} / g', source: src(q), updatedAt: q.fetchedAt));
    }
  }
  for (final c in const ['INR']) {
    final q = b.quote('FX_${c}_AED');
    if (q != null) {
      out.add(PriceInput(name: '$c / AED', value: q.price.toStringAsFixed(c == 'INR' ? 4 : 4), source: src(q), updatedAt: q.fetchedAt));
    }
  }
  return out;
}
