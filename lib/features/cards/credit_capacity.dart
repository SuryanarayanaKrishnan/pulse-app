import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/dbr.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../settings/salary_sheet.dart';

/// Total credit limit, how it is spread over the cards, and the DBR headroom
/// against the CBUAE 50% cap. Hidden until at least one card has a limit.
class CreditCapacitySection extends ConsumerWidget {
  const CreditCapacitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myCardsProvider).value ?? const <CreditCard>[];
    final salary = ref.watch(manualSalaryProvider).value;
    final r = computeDbr(
      cards: [
        for (final k in cards)
          DbrCard(name: k.name, limitMinor: (k.limit * 100).round()),
      ],
      salaryMinor: salary?.amountMinor,
    );
    if (r.totalLimitMinor == 0) return const SizedBox.shrink();
    final c = context.pc;
    String aed(int minor) => Money.aed(minor / 100, decimals: false);
    final tone = switch (r.level) {
      DbrLevel.over => c.negative,
      DbrLevel.tight => c.warning,
      _ => c.accent,
    };
    final dbr = r.dbrPct;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Credit capacity'),
        SurfaceCard(
          key: const Key('credit_capacity'),
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total credit limit', style: context.tt.bodySmall),
              const SizedBox(height: 2),
              Text(aed(r.totalLimitMinor), style: context.tt.headlineSmall),
              const SizedBox(height: Space.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    for (final (i, s) in r.cards.indexed)
                      Expanded(
                        flex: (s.sharePct * 10).round().clamp(1, 1000).toInt(),
                        child: Container(
                          height: 8,
                          margin: EdgeInsets.only(right: i == r.cards.length - 1 ? 0 : 2),
                          color: c.accent.withValues(alpha: (1 - i * 0.18).clamp(0.3, 1.0).toDouble()),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Space.sm),
              for (final s in r.cards)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: context.tt.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${aed(s.limitMinor)}  ·  ${s.sharePct.round()}% of your limit', style: context.tt.bodySmall),
                    ],
                  ),
                ),
              const Divider(height: Space.lg),
              if (dbr == null) ...[
                Text(
                  'Add your salary to see how much more credit the 50% debt burden cap leaves you.',
                  style: context.tt.bodyMedium,
                ),
                const SizedBox(height: Space.sm),
                TextButton(
                  key: const Key('capacity_add_salary'),
                  onPressed: () => showPulseSheet<void>(
                    context,
                    builder: (_) => SalarySheet(current: salary),
                  ),
                  child: const Text('Add salary'),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(child: Text('Debt burden (DBR)', style: context.tt.titleSmall)),
                    Text('${dbr.toStringAsFixed(dbr % 1 == 0 ? 0 : 1)}% of ${dbrMaxPct.round()}%',
                        style: context.tt.titleSmall?.copyWith(color: tone)),
                  ],
                ),
                const SizedBox(height: Space.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (dbr / dbrMaxPct).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    color: tone,
                    backgroundColor: c.accent.withValues(alpha: 0.12),
                  ),
                ),
                const SizedBox(height: Space.sm),
                Text(
                  switch (r.level) {
                    DbrLevel.over =>
                      'Over the cap by ${aed(-r.headroomMinor!)} a month. A bank is unlikely to approve new credit until this drops.',
                    DbrLevel.tight =>
                      'Getting close. About ${aed(r.headroomMinor!)} a month of room is left, roughly ${aed(r.extraCardLimitMinor!)} of extra card limit.',
                    _ =>
                      'Room for about ${aed(r.extraCardLimitMinor!)} more card limit, or ${aed(r.headroomMinor!)} a month in loan payments.',
                  },
                  style: context.tt.bodyMedium,
                ),
              ],
              const SizedBox(height: Space.sm),
              Text(
                'The UAE Central Bank caps total debt payments at 50% of gross salary and regular income '
                '(Circular 31/2013). The cap is official. How much of a card limit counts is set by each bank; '
                'we assume ${cardShareOfLimitPct.round()}% a month, so treat this as an estimate. '
                'Loan instalments are not included yet, and a salary entered after deductions will look tighter than the bank sees it.',
                key: const Key('capacity_caveat'),
                style: context.tt.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One calm line for card suggestions: only appears when a new card could
/// matter for the debt burden cap. Nothing when healthy or salary unknown.
class DbrNewCardNote extends ConsumerWidget {
  const DbrNewCardNote({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(myCardsProvider).value ?? const <CreditCard>[];
    final salary = ref.watch(manualSalaryProvider).value;
    final r = computeDbr(
      cards: [for (final k in cards) DbrCard(name: k.name, limitMinor: (k.limit * 100).round())],
      salaryMinor: salary?.amountMinor,
    );
    final text = switch (r.level) {
      DbrLevel.over => 'Your debt burden is over the 50% cap, so a bank may decline a new card.',
      DbrLevel.tight => 'Your debt burden is close to the 50% cap. A new card adds to it.',
      _ => null,
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      key: const Key('dbr_new_card_note'),
      padding: const EdgeInsets.only(top: Space.xs),
      child: Text(text, style: context.tt.bodySmall?.copyWith(color: context.pc.warning)),
    );
  }
}
