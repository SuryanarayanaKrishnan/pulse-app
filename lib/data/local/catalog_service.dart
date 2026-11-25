import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/engine/catalog.dart';
import 'database.dart';

typedef CatalogLoader = Future<String> Function();

/// Loads the card catalog: bundled first (always works offline), then - when
/// a backend is configured - checks for a newer version and, if there is one,
/// stores it. The catalog is plain reference data; it never carries personal
/// information in either direction.
///
/// Remote contract: `GET {API_BASE_URL}/v1/catalog/cards` returns a document
/// shaped like `assets/catalog/cards.json` (`version`, `updated_on`, `cards`).
/// It is applied only when its `version` is greater than the current one and
/// it contains at least one valid card.
class CatalogService {
  CatalogService({
    required this.db,
    CatalogLoader? bundled,
    this.dio,
    this.remotePath = '/v1/catalog/cards',
  }) : _bundled =
           bundled ??
           (() => rootBundle.loadString('assets/catalog/cards.json'));

  final PulseDatabase db;
  final CatalogLoader _bundled;

  /// Null when no backend is configured: the bundled catalog is all there is.
  final Dio? dio;
  final String remotePath;

  static const versionKey = 'catalog.version';

  Future<int> currentVersion() async =>
      int.tryParse(await db.setting(versionKey) ?? '') ?? 0;

  /// Loads the bundled catalog when it is newer than what the database has
  /// (first run, or an app update that ships a newer catalog).
  Future<CardCatalog> loadBundled() async {
    final catalog = CardCatalog.fromJson(
      jsonDecode(await _bundled()) as Map<String, Object?>,
    );
    if (catalog.version > await currentVersion() || await _isEmpty()) {
      await apply(catalog);
    }
    return catalog;
  }

  Future<bool> _isEmpty() async =>
      (await (db.selectOnly(
        db.catalogCards,
      )..addColumns([db.catalogCards.id.count()])).getSingle()).read(
        db.catalogCards.id.count(),
      ) ==
      0;

  /// Asks the backend for a newer catalog. Returns true when one was applied.
  /// Network and format problems are swallowed: the catalog we have stays.
  Future<bool> checkForUpdate() async {
    final client = dio;
    if (client == null) return false;
    try {
      final res = await client.get<Object?>(remotePath);
      final data = res.data;
      if (data is! Map) return false;
      final remote = CardCatalog.fromJson(Map<String, Object?>.from(data));
      if (remote.cards.isEmpty || remote.version <= await currentVersion())
        return false;
      await apply(remote);
      return true;
    } on Object {
      return false;
    }
  }

  /// Replaces the cached catalog with [catalog]. Cards the user owns keep
  /// working even when a newer catalog drops them: rows are upserted, never
  /// deleted.
  Future<void> apply(CardCatalog catalog) async {
    await db.transaction(() async {
      for (final c in catalog.cards) {
        await db
            .into(db.catalogCards)
            .insertOnConflictUpdate(
              CatalogCardsCompanion.insert(
                id: c.id,
                issuer: c.issuer,
                name: c.name,
                network: Value(c.network),
                annualFeeMinor: Value(c.annualFeeMinor),
                minSalaryMinor: Value(c.minSalaryMinor),
                rewardStructure: Value(jsonEncode(c.rewardStructure)),
                perks: Value(jsonEncode(c.perks)),
                verifiedOn: Value(
                  c.verifiedOn?.toIso8601String().substring(0, 10),
                ),
                source: Value(c.source),
                catalogVersion: Value(catalog.version),
              ),
            );
      }
      await db.putSetting(versionKey, '${catalog.version}');
      await db.putSetting('catalog.updated_on', catalog.updatedOn);
    });
  }

  /// The catalog as stored.
  Future<List<CatalogCard>> cards() async {
    final rows =
        await (db.select(db.catalogCards)..orderBy([
              (t) => OrderingTerm.asc(t.issuer),
              (t) => OrderingTerm.asc(t.name),
            ]))
            .get();
    final out = <CatalogCard>[];
    for (final r in rows) {
      try {
        final card = CatalogCard(
          id: r.id,
          issuer: r.issuer,
          name: r.name,
          network: r.network,
          annualFeeMinor: r.annualFeeMinor,
          minSalaryMinor: r.minSalaryMinor,
          rewardStructure: Map<String, Object?>.from(
            jsonDecode(r.rewardStructure) as Map,
          ),
          perks: Map<String, Object?>.from(jsonDecode(r.perks) as Map),
          verifiedOn: r.verifiedOn == null
              ? null
              : DateTime.parse(r.verifiedOn!),
          source: r.source,
        );
        card.spec;
        out.add(card);
      } on Object {
        continue; // a malformed cached entry never breaks the screen
      }
    }
    return out;
  }
}
