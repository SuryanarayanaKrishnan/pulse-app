import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/prices.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';
import 'package:pulse/data/local/price_service.dart';
import 'package:pulse/data/local/wealth_store.dart';
import 'package:pulse/data/models.dart';
import 'package:pulse/data/wealth_models.dart';
import 'package:pulse/data/wealth_service.dart';

final _now = DateTime.utc(2026, 11, 24, 8);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('net worth, assets and allocation include jewellery and funds, revalued locally', () async {
    final db = PulseDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final store = LocalWealthStore(db);
    final wealth = WealthService(
      store: store,
      prices: PriceService(store: store, clock: () => _now),
      fundLookup: FundLookup(null),
      clock: () => _now,
    );
    final catalog = CatalogService(db: db, bundled: () async => File('assets/catalog/cards.json').readAsStringSync());
    await catalog.loadBundled();
    final pipeline = IngestPipeline(db, clock: () => _now);
    addTearDown(pipeline.dispose);
    final repo = LocalPulseRepository(db: db, catalog: catalog, pipeline: pipeline, wealth: wealth, clock: () => _now);

    await repo.addAsset(name: 'Flat', kind: AssetKind.realEstate, value: 100000);
    await wealth.saveJewellery(JewelleryItem(id: 'j', name: 'Necklace', weightGrams: 24, karat: 22, createdAt: _now));
    await wealth.saveFund(FundHolding(id: 'f', kind: 'manual', name: 'AED fund', currency: 'AED', units: 100, nav: 12, createdAt: _now));

    // Bundled fallback gold: 470 AED/g -> 24 g x 22/24 x 470 = 10,340.
    var assets = await repo.assets();
    expect(assets.firstWhere((a) => a.id == 'jewel:j').value, closeTo(10340, 0.01));
    expect(assets.firstWhere((a) => a.id == 'fund:f').kind, AssetKind.funds);
    var nw = await repo.netWorth();
    expect(nw.total, closeTo(100000 + 10340 + 1200, 0.01));
    expect(nw.prices.map((p) => p.name), containsAll(['Gold 24K', 'Gold 22K', 'INR / AED']));
    expect(nw.pricesLive, isFalse); // bundled values, not live

    // A cached live price revalues without any edit to the items.
    await store.savePriceQuotes([
      for (final k in [24, 22, 21, 18])
        PriceQuote(symbol: 'XAU_AED_G_${k}K', price: 500.0 * k / 24, fetchedAt: _now),
    ]);
    assets = await repo.assets();
    expect(assets.firstWhere((a) => a.id == 'jewel:j').value, closeTo(11000, 0.01));
    nw = await repo.netWorth();
    expect(nw.total, closeTo(100000 + 11000 + 1200, 0.01));
    expect(nw.pricesLive, isFalse); // cached, not fetched this session
  });
}
