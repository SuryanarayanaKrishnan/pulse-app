import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulse/core/engine/types.dart';
import 'package:pulse/data/local/catalog_service.dart';
import 'package:pulse/data/local/database.dart';
import 'package:pulse/data/local/ingest_pipeline.dart';
import 'package:pulse/data/local/local_repository.dart';

final _now = DateTime.utc(2026, 3, 12, 8);

Future<(LocalPulseRepository, IngestPipeline)> _rig() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = PulseDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final catalog = CatalogService(
    db: db,
    bundled: () async =>
        File('test/fixtures/catalog/cards_small.json').readAsStringSync(),
  );
  await catalog.loadBundled();
  final pipeline = IngestPipeline(db, clock: () => _now);
  addTearDown(pipeline.dispose);
  return (
    LocalPulseRepository(
      db: db,
      catalog: catalog,
      pipeline: pipeline,
      clock: () => _now,
    ),
    pipeline,
  );
}

Future<IngestOutcome> _alert(
  IngestPipeline p,
  String id, {
  String last4 = '9999',
}) => p.ingest(
  IngestInput(
    channel: TxnSource.sms,
    externalId: id,
    receivedAt: DateTime.utc(2026, 3, 12, 9),
    institution: 'Emirates NBD',
    fields: IngestFields(
      amountMinor: 4500,
      merchant: 'Carrefour',
      last4: last4,
      postedAt: DateTime.utc(2026, 3, 12, 9),
    ),
  ),
);

void main() {
  test(
    'an alert for unknown digits becomes a question, and one answer replays it',
    () async {
      final (repo, pipeline) = await _rig();
      final card = await repo.addCard(
        catalogId: 'emirates-nbd-skywards-infinite',
        last4: '',
      );
      expect(card.last4, '----');

      expect((await _alert(pipeline, 'a1')).status, IngestStatus.needsReview);
      expect((await _alert(pipeline, 'a2')).status, IngestStatus.needsReview);
      expect(await repo.transactions(), isEmpty);

      final s = await repo.digitSuggestions();
      expect(s, hasLength(1));
      expect(s.single.last4, '9999');
      expect(s.single.waiting, 2);
      expect(s.single.candidates.single.id, card.id);
      expect(s.single.question, startsWith('Is ••9999 your'));

      await repo.setCardLast4(card.id, '9999');
      expect(await repo.transactions(), hasLength(2));
      expect(await repo.digitSuggestions(), isEmpty);
      expect((await repo.myCards()).single.last4, '9999');
    },
  );

  test('no digit-less card at that bank means no question, and bad digits are refused', () async {
    final (repo, pipeline) = await _rig();
    await repo.addCard(
      catalogId: 'emirates-nbd-skywards-infinite',
      last4: '1234',
    );
    await _alert(pipeline, 'b1');
    expect(await repo.digitSuggestions(), isEmpty);
    final c = await repo.addCard(
      catalogId: 'emirates-nbd-skywards-infinite',
      last4: '',
    );
    expect(await repo.digitSuggestions(), hasLength(1));
    await expectLater(repo.setCardLast4(c.id, '12'), throwsA(anything));
  });
}
