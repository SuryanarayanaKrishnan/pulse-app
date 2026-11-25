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
  // Free first, then plus; stable within each.
  out.sort((a, b) => (a.isPlus ? 1 : 0).compareTo(b.isPlus ? 1 : 0));
  return out;
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
