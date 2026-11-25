import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/engine/card_value.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';

String _aed(int minor) => 'AED ${(minor / 100).toStringAsFixed(2)}';

/// Calm one-line result of a card check. Always says it is an estimate.
String cardCheckMessage(CardCheck c) {
  final tail = c.estimated ? '(estimate, unverified terms)' : '(estimate)';
  if (c.right) return 'Right card. ${c.paidTitle} earned about ${_aed(c.earnedMinor)} $tail';
  return '${c.bestTitle} would have earned about ${_aed(c.bestMinor)} here, '
      'vs ${_aed(c.earnedMinor)} on ${c.paidTitle} $tail';
}

String missedBucket(int missedMinor) =>
    missedMinor < 500 ? 'lt_5' : (missedMinor <= 2000 ? '5_20' : 'gt_20');

/// Shows the check as a quiet floating note with a light haptic, and records
/// `card_check_shown` (and `card_check_wrong` for a miss).
void showCardCheckNudge(BuildContext context, Analytics analytics, CardCheck check) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final c = context.pc;
  Haptics.light();
  analytics.track(
    AnalyticsEvent.cardCheckShown(result: check.right ? 'right' : 'wrong', estimated: check.estimated),
  );
  if (!check.right) {
    analytics.track(AnalyticsEvent.cardCheckWrong(missedBucket: missedBucket(check.missedMinor)));
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        key: const ValueKey('card-check-nudge'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            Icon(
              check.right ? Icons.check_circle_outline_rounded : Icons.swap_horiz_rounded,
              size: 20,
              color: check.right ? c.positive : c.warning,
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Text(cardCheckMessage(check))),
          ],
        ),
      ),
    );
}

/// Hook for a system notification of the same result (iOS: from the
/// Record Payment App Intent path). Nothing is wired on this build; the iOS
/// side needs Xcode and notification permission, so this stays a no-op until
/// a platform implementation overrides [cardCheckNotifierProvider].
abstract class CardCheckNotifier {
  Future<void> notify(CardCheck check);
}

class NoopCardCheckNotifier implements CardCheckNotifier {
  const NoopCardCheckNotifier();
  @override
  Future<void> notify(CardCheck check) async {}
}

final cardCheckNotifierProvider = Provider<CardCheckNotifier>((_) => const NoopCardCheckNotifier());
