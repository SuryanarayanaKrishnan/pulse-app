import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A default stacking combo or tip from the bundled card-intel set
/// (`assets/catalog/combos.json`, exported from the backend). Works offline
/// and without any cards.
class CardCombo {
  const CardCombo({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.cardIds,
    required this.tier,
    required this.severity,
    required this.confidence,
    this.validUntil,
    this.annualSavingAed,
    this.savingNote,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final List<String> cardIds;

  /// `free` shows to everyone; `plus` is locked until entitled.
  final String tier;
  final String severity;
  final String confidence;
  final DateTime? validUntil;

  /// Estimated potential saving in AED a year, when the catalog gives enough
  /// to work one out. Null means no figure, and never zero.
  final double? annualSavingAed;

  /// How [annualSavingAed] was worked out and what it assumes.
  final String? savingNote;

  bool get hasSaving => annualSavingAed != null && annualSavingAed! > 0;

  bool get isPlus => tier == 'plus';
  bool get isWarning => severity == 'warn';

  /// Plain wording for how sure we are. Never overstates a single report.
  String get confidenceLabel => switch (confidence) {
    'verified' => 'Verified',
    'corroborated' => 'Reported by several people',
    _ => 'Community report, not verified',
  };

  /// First sentence, for the locked teaser and list subtitles.
  String get headline {
    final i = body.indexOf('. ');
    return i < 0 ? body : body.substring(0, i + 1);
  }

  factory CardCombo.fromJson(Map<String, dynamic> j) => CardCombo(
    id: j['id'] as String,
    kind: j['kind'] as String? ?? 'combo',
    title: j['title'] as String,
    body: j['body'] as String? ?? '',
    cardIds: [
      for (final c in (j['card_ids'] as List? ?? const [])) c as String,
    ],
    tier: j['tier'] as String? ?? 'plus',
    severity: j['severity'] as String? ?? 'info',
    confidence: j['confidence'] as String? ?? 'reported',
    validUntil: DateTime.tryParse(j['valid_until'] as String? ?? ''),
    annualSavingAed: (j['annual_saving_aed'] as num?)?.toDouble(),
    savingNote: j['saving_note'] as String?,
  );
}

List<CardCombo> parseCombos(String source, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final raw =
      (jsonDecode(source) as Map<String, dynamic>)['items'] as List? ??
      const [];
  final out =
      [for (final j in raw) CardCombo.fromJson(j as Map<String, dynamic>)]
          .where(
            (c) =>
                c.validUntil == null ||
                !c.validUntil!.isBefore(
                  DateTime(today.year, today.month, today.day),
                ),
          )
          .toList();
  return sortCombos(out);
}

/// Combos with a savings figure first, biggest saving first. Everything
/// without one (including warnings and caveats) follows, free before plus,
/// information before warnings. Stable otherwise.
List<CardCombo> sortCombos(List<CardCombo> items) {
  final indexed = items.indexed.toList();
  int rank(CardCombo c) => c.hasSaving ? 0 : 1;
  indexed.sort((a, b) {
    final x = a.$2, y = b.$2;
    var r = rank(x).compareTo(rank(y));
    if (r != 0) return r;
    if (x.hasSaving) {
      r = y.annualSavingAed!.compareTo(x.annualSavingAed!);
    } else {
      r = (x.isPlus ? 1 : 0).compareTo(y.isPlus ? 1 : 0);
      if (r == 0) r = (x.isWarning ? 1 : 0).compareTo(y.isWarning ? 1 : 0);
    }
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

final cardCombosProvider = FutureProvider<List<CardCombo>>((ref) async {
  try {
    return parseCombos(
      await rootBundle.loadString('assets/catalog/combos.json'),
    );
  } catch (_) {
    return const [];
  }
});
