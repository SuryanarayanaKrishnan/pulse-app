import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/engine/dates.dart';
import '../../core/engine/prices.dart';
import '../wealth_models.dart';
import 'database.dart';
import 'ids.dart';

/// Storage for jewellery, documents, fund holdings, cached prices and
/// valuation snapshots. Two implementations: the drift database (the phone)
/// and memory (demo data, web builds, tests).
abstract class WealthStore {
  Future<List<JewelleryItem>> jewellery();
  Future<JewelleryItem> saveJewellery(JewelleryItem item);
  Future<void> deleteJewellery(String id);

  Future<List<WealthDocument>> documents();
  Future<WealthDocument> saveDocument(WealthDocument doc);
  Future<void> deleteDocument(String id);

  Future<List<FundHolding>> funds();
  Future<FundHolding> saveFund(FundHolding fund);
  Future<void> deleteFund(String id);

  Future<List<PriceQuote>> priceQuotes();
  Future<void> savePriceQuotes(List<PriceQuote> quotes);

  /// Stores [valueMinor] for the day; the latest value of a day wins.
  Future<void> recordValuation(String kind, String id, CalDate date, int valueMinor, {double? unitPrice});
  Future<List<ValuationPoint>> valuationHistory(String kind, String id);
}

String newWealthId() => newId();

// ---- drift -----------------------------------------------------------------

List<String> _paths(String json) {
  try {
    final v = jsonDecode(json);
    return v is List ? [for (final e in v) '$e'] : const [];
  } catch (_) {
    return const [];
  }
}

CalDate? _date(String? iso) {
  if (iso == null) return null;
  try {
    return CalDate.parse(iso);
  } catch (_) {
    return null;
  }
}

class LocalWealthStore implements WealthStore {
  LocalWealthStore(this.db);
  final PulseDatabase db;

  JewelleryItem _jewel(JewelleryRow r) => JewelleryItem(
    id: r.id,
    name: r.name,
    weightGrams: r.weightGrams,
    karat: r.karat,
    purityOverride: r.purityOverride,
    purchasePriceMinor: r.purchasePriceMinor,
    purchaseDate: _date(r.purchaseDate),
    makingChargesMinor: r.makingChargesMinor,
    notes: r.notes,
    photoPaths: _paths(r.photoPaths),
    createdAt: r.createdAt,
  );

  @override
  Future<List<JewelleryItem>> jewellery() async => [
    for (final r in await (db.select(db.jewelleryItems)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get())
      _jewel(r),
  ];

  @override
  Future<JewelleryItem> saveJewellery(JewelleryItem i) async {
    await db.into(db.jewelleryItems).insertOnConflictUpdate(
      JewelleryItemsCompanion(
        id: Value(i.id),
        name: Value(i.name),
        weightGrams: Value(i.weightGrams),
        karat: Value(i.karat),
        purityOverride: Value(i.purityOverride),
        purchasePriceMinor: Value(i.purchasePriceMinor),
        purchaseDate: Value(i.purchaseDate?.toIso()),
        makingChargesMinor: Value(i.makingChargesMinor),
        notes: Value(i.notes),
        photoPaths: Value(jsonEncode(i.photoPaths)),
        createdAt: Value(i.createdAt),
        deletedAt: const Value(null),
      ),
    );
    return i;
  }

  @override
  Future<void> deleteJewellery(String id) async {
    await (db.update(db.jewelleryItems)..where((t) => t.id.equals(id))).write(
      JewelleryItemsCompanion(deletedAt: Value(DateTime.now().toUtc())),
    );
    await (db.delete(db.valuationSnapshots)..where((t) => t.subjectKind.equals('jewellery') & t.subjectId.equals(id))).go();
  }

  @override
  Future<List<WealthDocument>> documents() async => [
    for (final r in await (db.select(db.documentAttachments)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get())
      WealthDocument(
        id: r.id,
        title: r.title,
        category: DocCategory.fromWire(r.category),
        notes: r.notes,
        filePaths: _paths(r.filePaths),
        dueOn: _date(r.dueOn),
        dueKind: r.dueKind,
        remindDaysBefore: r.remindDaysBefore,
        notificationId: r.notificationId,
        createdAt: r.createdAt,
      ),
  ];

  @override
  Future<WealthDocument> saveDocument(WealthDocument d) async {
    await db.into(db.documentAttachments).insertOnConflictUpdate(
      DocumentAttachmentsCompanion(
        id: Value(d.id),
        title: Value(d.title),
        category: Value(d.category.wire),
        notes: Value(d.notes),
        filePaths: Value(jsonEncode(d.filePaths)),
        dueOn: Value(d.dueOn?.toIso()),
        dueKind: Value(d.dueKind),
        remindDaysBefore: Value(d.remindDaysBefore),
        notificationId: Value(d.notificationId),
        createdAt: Value(d.createdAt),
        deletedAt: const Value(null),
      ),
    );
    return d;
  }

  @override
  Future<void> deleteDocument(String id) =>
      (db.update(db.documentAttachments)..where((t) => t.id.equals(id))).write(
        DocumentAttachmentsCompanion(deletedAt: Value(DateTime.now().toUtc())),
      );

  @override
  Future<List<FundHolding>> funds() async => [
    for (final r in await (db.select(db.fundHoldings)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get())
      FundHolding(
        id: r.id,
        kind: r.kind,
        schemeCode: r.schemeCode,
        name: r.name,
        currency: r.currency,
        units: r.units,
        avgCostNav: r.avgCostNav,
        nav: r.nav,
        navDate: r.navDate,
        navSource: r.navSource,
        navFetchedAt: r.navFetchedAt,
        sipAmountMinor: r.sipAmountMinor,
        sipDay: r.sipDay,
        createdAt: r.createdAt,
      ),
  ];

  @override
  Future<FundHolding> saveFund(FundHolding f) async {
    await db.into(db.fundHoldings).insertOnConflictUpdate(
      FundHoldingsCompanion(
        id: Value(f.id),
        kind: Value(f.kind),
        schemeCode: Value(f.schemeCode),
        name: Value(f.name),
        currency: Value(f.currency),
        units: Value(f.units),
        avgCostNav: Value(f.avgCostNav),
        nav: Value(f.nav),
        navDate: Value(f.navDate),
        navSource: Value(f.navSource),
        navFetchedAt: Value(f.navFetchedAt),
        sipAmountMinor: Value(f.sipAmountMinor),
        sipDay: Value(f.sipDay),
        createdAt: Value(f.createdAt),
        deletedAt: const Value(null),
      ),
    );
    return f;
  }

  @override
  Future<void> deleteFund(String id) => (db.update(db.fundHoldings)..where((t) => t.id.equals(id))).write(
    FundHoldingsCompanion(deletedAt: Value(DateTime.now().toUtc())),
  );

  @override
  Future<List<PriceQuote>> priceQuotes() async => [
    for (final r in await db.select(db.priceCache).get())
      PriceQuote(
        symbol: r.symbol,
        price: r.price,
        unit: r.unit,
        source: r.source,
        status: r.status,
        quotedAt: r.quotedAt,
        fetchedAt: r.fetchedAt,
      ),
  ];

  @override
  Future<void> savePriceQuotes(List<PriceQuote> quotes) => db.batch((b) {
    for (final q in quotes) {
      b.insert(
        db.priceCache,
        PriceCacheCompanion.insert(
          symbol: q.symbol,
          price: q.price,
          unit: Value(q.unit),
          source: Value(q.source),
          status: Value(q.status),
          quotedAt: Value(q.quotedAt),
          fetchedAt: q.fetchedAt,
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  });

  @override
  Future<void> recordValuation(String kind, String id, CalDate date, int valueMinor, {double? unitPrice}) async {
    final iso = date.toIso();
    final existing = await (db.select(db.valuationSnapshots)
          ..where((t) => t.subjectKind.equals(kind) & t.subjectId.equals(id) & t.snapshotDate.equals(iso)))
        .getSingleOrNull();
    if (existing == null) {
      await db.into(db.valuationSnapshots).insert(
        ValuationSnapshotsCompanion.insert(
          id: newId(),
          subjectKind: kind,
          subjectId: id,
          snapshotDate: iso,
          valueMinor: valueMinor,
          unitPrice: Value(unitPrice),
        ),
      );
    } else {
      await (db.update(db.valuationSnapshots)..where((t) => t.id.equals(existing.id))).write(
        ValuationSnapshotsCompanion(valueMinor: Value(valueMinor), unitPrice: Value(unitPrice)),
      );
    }
  }

  @override
  Future<List<ValuationPoint>> valuationHistory(String kind, String id) async => [
    for (final r in await (db.select(db.valuationSnapshots)
          ..where((t) => t.subjectKind.equals(kind) & t.subjectId.equals(id))
          ..orderBy([(t) => OrderingTerm.asc(t.snapshotDate)]))
        .get())
      ValuationPoint(CalDate.parse(r.snapshotDate), r.valueMinor, r.unitPrice),
  ];
}

// ---- memory ------------------------------------------------------------------

/// In-memory store for demo data, the web build and tests.
class MemoryWealthStore implements WealthStore {
  MemoryWealthStore({
    List<JewelleryItem> jewellery = const [],
    List<WealthDocument> documents = const [],
    List<FundHolding> funds = const [],
    Map<String, List<ValuationPoint>> history = const {},
    List<PriceQuote> quotes = const [],
  }) : _jewellery = [...jewellery],
       _documents = [...documents],
       _funds = [...funds],
       _history = {for (final e in history.entries) e.key: [...e.value]} {
    for (final q in quotes) {
      _quotes[q.symbol] = q;
    }
  }

  final List<JewelleryItem> _jewellery;
  final List<WealthDocument> _documents;
  final List<FundHolding> _funds;
  final Map<String, PriceQuote> _quotes = {};
  final Map<String, List<ValuationPoint>> _history;

  static T _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    i < 0 ? list.add(item) : list[i] = item;
    return item;
  }

  @override
  Future<List<JewelleryItem>> jewellery() async => List.of(_jewellery);
  @override
  Future<JewelleryItem> saveJewellery(JewelleryItem i) async => _upsert<JewelleryItem>(_jewellery, i, (e) => e.id);
  @override
  Future<void> deleteJewellery(String id) async {
    _jewellery.removeWhere((e) => e.id == id);
    _history.remove('jewellery:$id');
  }

  @override
  Future<List<WealthDocument>> documents() async => List.of(_documents);
  @override
  Future<WealthDocument> saveDocument(WealthDocument d) async => _upsert<WealthDocument>(_documents, d, (e) => e.id);
  @override
  Future<void> deleteDocument(String id) async => _documents.removeWhere((e) => e.id == id);

  @override
  Future<List<FundHolding>> funds() async => List.of(_funds);
  @override
  Future<FundHolding> saveFund(FundHolding f) async => _upsert<FundHolding>(_funds, f, (e) => e.id);
  @override
  Future<void> deleteFund(String id) async => _funds.removeWhere((e) => e.id == id);

  @override
  Future<List<PriceQuote>> priceQuotes() async => _quotes.values.toList();
  @override
  Future<void> savePriceQuotes(List<PriceQuote> quotes) async {
    for (final q in quotes) {
      _quotes[q.symbol] = q;
    }
  }

  @override
  Future<void> recordValuation(String kind, String id, CalDate date, int valueMinor, {double? unitPrice}) async {
    final list = _history.putIfAbsent('$kind:$id', () => []);
    list.removeWhere((p) => p.date == date);
    list.add(ValuationPoint(date, valueMinor, unitPrice));
    list.sort((a, b) => a.date.compareTo(b.date));
  }

  @override
  Future<List<ValuationPoint>> valuationHistory(String kind, String id) async => List.of(_history['$kind:$id'] ?? const []);
}
