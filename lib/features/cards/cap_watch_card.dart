import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/cap_tracker.dart';
import '../../core/engine/next_best.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/cap_providers.dart';

/// Shown next to every forecast-based pick: it is an estimate, not a promise.
const capForecastCaveat =
    'An estimate from your past spending, a convenience suggestion and not a '
    'guarantee. Card terms, caps and rates can change; check with the bank.';

/// "Cap watch": cards that are close to or at a monthly cashback cap, how much
/// is left, and, once a cap is hit, the best next card for the spend still to
/// come (held cards first, then cards to get). Hidden when nothing is near a
/// cap, so it only appears when it has something to say.
class CapWatchCard extends ConsumerWidget {
  const CapWatchCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(capNotifyProvider);
    final watch = ref.watch(capWatchProvider).value ?? const <CardCapStatus>[];
    if (watch.isEmpty) return const SizedBox.shrink();
    final anyHit = watch.any((c) => c.level == CapLevel.hit);
    final plan = anyHit ? ref.watch(nextBestProvider).value : null;
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: SurfaceCard(
        key: const Key('cap_watch'),
        padding: const EdgeInsets.all(Space.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  anyHit ? Icons.speed_rounded : Icons.trending_up_rounded,
                  size: 20,
                  color: anyHit ? c.warning : c.accent,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    anyHit ? 'Cashback cap reached' : 'Close to a cashback cap',
                    style: context.tt.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            for (final card in watch.take(3)) _CapRow(card),
            if (plan != null) ...[
              const SizedBox(height: Space.sm),
              _NextBest(plan),
            ],
          ],
        ),
      ),
    );
  }
}

class _CapRow extends StatelessWidget {
  const _CapRow(this.status);
  final CardCapStatus status;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final m = status.worst!;
    final hit = m.level == CapLevel.hit;
    final spend = m.remainingSpendAed;
    final line = hit
        ? '${Money.aed(m.earnedAed, decimals: false)} of '
              '${Money.aed(m.capAed, decimals: false)} cashback used. Cap reached.'
        : '${Money.aed(m.remainingAed, decimals: false)} cashback left'
              '${spend == null ? '' : ', about ${Money.aed(spend, decimals: false)} more spend'}.';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status.title, style: context.tt.labelLarge),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(
              value: (m.pct / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: c.border,
              color: hit ? c.warning : c.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            line,
            style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NextBest extends StatelessWidget {
  const _NextBest(this.plan);
  final NextBestPlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final top = plan.top;
    return Column(
      key: const Key('cap_next_best'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('For the rest of the month', style: context.tt.labelLarge),
        const SizedBox(height: 4),
        Text(plan.reason, style: context.tt.bodyMedium),
        if (top != null) ...[
          const SizedBox(height: 4),
          Text(
            'Get ${top.card.issuer} ${top.card.name}: about '
            '${Money.aed(top.netYearlyMinor / 100, decimals: false)} a year '
            'net of its fee.',
            style: context.tt.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          '${plan.forecast.note}. $capForecastCaveat',
          key: const Key('cap_caveat'),
          style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}
