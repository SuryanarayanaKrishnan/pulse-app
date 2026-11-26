import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_util.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import 'upsell_widgets.dart';

/// Categories worth asking about before a purchase.
const recommendableCategories = [
  SpendCategory.groceries,
  SpendCategory.dining,
  SpendCategory.transport,
  SpendCategory.shopping,
  SpendCategory.travel,
  SpendCategory.entertainment,
  SpendCategory.health,
  SpendCategory.utilities,
];

String cardName(CreditCard c) => '${c.issuer} ${c.name}';

String _days(int d) => d == 0
    ? 'Today'
    : d == 1
    ? 'Tomorrow'
    : d < 0
    ? '${-d}d late'
    : '$d days';

Future<void> showWhichCard(BuildContext context, WidgetRef ref) {
  ref
      .read(analyticsProvider)
      .track(AnalyticsEvent.cardRecommendationViewed('which_card'));
  return showPulseSheet<void>(context, builder: (_) => const WhichCardSheet());
}

/// "Which card should I use?" before paying: pick what you are buying,
/// optionally how much, and get one answer with its reason.
class WhichCardSheet extends ConsumerStatefulWidget {
  const WhichCardSheet({super.key, this.initial = SpendCategory.groceries});
  final SpendCategory initial;
  @override
  ConsumerState<WhichCardSheet> createState() => _WhichCardSheetState();
}

class _WhichCardSheetState extends ConsumerState<WhichCardSheet> {
  late SpendCategory _cat = widget.initial;
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final cards = ref.watch(myCardsProvider).value ?? const [];
    final amount = double.tryParse(_amount.text.replaceAll(',', ''));
    final advice = adviseCard(cards, _cat, amount: amount);
    return SheetScaffold(
      title: 'Which card should I use?',
      subtitle: 'Live rates, after this month\'s caps',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final x in recommendableCategories)
                Pill(
                  x.label,
                  selected: x == _cat,
                  onTap: () => setState(() => _cat = x),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: PulseTheme.amount(c.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Amount in AED (optional)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: Space.xl),
          if (advice == null)
            Text('Add a card to get advice.', style: context.tt.bodyMedium)
          else
            AnimatedSwitcher(
              duration: Motion.base,
              child: Column(
                key: ValueKey('${_cat.id}-${advice.best.id}-$amount'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 56,
                        child: CreditCardVisual(
                          card: advice.best,
                          compact: true,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cardName(advice.best),
                              style: context.tt.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(advice.reason, style: context.tt.bodySmall),
                          ],
                        ),
                      ),
                      Text(
                        formatRate(advice.rate),
                        style: PulseTheme.amount(
                          c.accent,
                          size: 24,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (advice.estimate != null) ...[
                    const SizedBox(height: Space.lg),
                    Text(
                      'Earns ${Money.aed(advice.estimate!)} on ${Money.aed(amount!, decimals: false)}',
                      style: context.tt.bodyMedium!.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ],
                  if (advice.runnerUp != null) ...[
                    const SizedBox(height: Space.lg),
                    const Hairline(),
                    ListRow(
                      dense: true,
                      title: 'Next best: ${cardName(advice.runnerUp!)}',
                      trailing: Text(
                        formatRate(advice.runnerUpRate!),
                        style: PulseTheme.amount(c.textSecondary),
                      ),
                    ),
                  ],
                  UpsellRow(category: _cat),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A card payment: due date, minimum versus full, and when to pay.
class DueRow extends StatelessWidget {
  const DueRow(this.info, {super.key, this.onTap});
  final DueInfo info;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tone = info.overdue
        ? c.negative
        : info.urgent
        ? c.warning
        : c.textSecondary;
    return ListRow(
      leading: SizedBox(
        width: 32,
        child: CreditCardVisual(card: info.card, compact: true),
      ),
      title: cardName(info.card),
      subtitle: info.urgent
          ? info.nudge
          : 'Full ${Money.aed(info.totalDue, decimals: false)} · min ${Money.aed(info.minDue, decimals: false)}',
      subtitleColor: info.urgent ? tone : null,
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(_days(info.daysLeft), style: PulseTheme.amount(tone, size: 15)),
          const SizedBox(height: 2),
          Text(
            DateFormat('d MMM').format(info.card.dueDate),
            style: context.tt.bodySmall,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// The selected card's statement cycle in plain rows.
class PaymentDetails extends StatelessWidget {
  const PaymentDetails(this.card, {super.key});
  final CreditCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = dueInfo(card);
    final date = DateFormat('d MMMM');
    final tone = d.overdue
        ? c.negative
        : d.urgent
        ? c.warning
        : c.textPrimary;
    Text num(String s, [Color? col]) =>
        Text(s, style: PulseTheme.amount(col ?? c.textPrimary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RowGroup(
          children: [
            if (card.statementDate != null)
              ListRow(
                dense: true,
                title: 'Statement',
                trailing: num(
                  date.format(card.statementDate!),
                  c.textSecondary,
                ),
              ),
            if (card.hasDueDate)
              ListRow(
                dense: true,
                title: 'Due',
                subtitle: d.nudge,
                subtitleColor: d.urgent ? tone : null,
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    num(date.format(card.dueDate)),
                    Text(
                      _days(d.daysLeft),
                      style: context.tt.bodySmall!.copyWith(color: tone),
                    ),
                  ],
                ),
              ),
            ListRow(
              dense: true,
              title: 'Full amount',
              subtitle: 'No interest',
              trailing: num(Money.aed(d.totalDue)),
            ),
            ListRow(
              dense: true,
              title: 'Minimum',
              subtitle: 'Interest on the rest',
              trailing: num(Money.aed(d.minDue), c.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Reward rules for one card, each with its cap and when it was verified.
class RewardRules extends StatelessWidget {
  const RewardRules(this.card, {super.key});
  final CreditCard card;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final rates = card.categoryRates.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final verified = card.rulesVerifiedOn == null
        ? 'Not yet verified'
        : 'Verified on ${DateFormat('d MMM yyyy').format(card.rulesVerifiedOn!)}';
    return RowGroup(
      children: [
        for (final e in rates)
          Builder(
            builder: (context) {
              final cap = card.caps[e.key];
              final live = effectiveRate(card, e.key);
              final capped = live < e.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(e.key.label, style: context.tt.bodyLarge),
                        ),
                        if (capped) ...[
                          Text(
                            formatRate(e.value),
                            style: PulseTheme.amount(
                              c.textTertiary,
                              size: 13,
                            ).copyWith(decoration: TextDecoration.lineThrough),
                          ),
                          const SizedBox(width: Space.sm),
                        ],
                        Text(
                          formatRate(live),
                          style: PulseTheme.amount(
                            capped ? c.warning : c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    if (cap != null) ...[
                      const SizedBox(height: Space.sm),
                      Meter(
                        value: cap.progress,
                        color: cap.reached
                            ? c.warning
                            : c.forProgress(cap.progress),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cap.reached
                            ? 'Monthly cap of ${Money.aed(cap.limit, decimals: false)} reached. Earning ${formatRate(card.baseRate)} until the 1st'
                            : '${Money.aed(cap.used)} of ${Money.aed(cap.limit, decimals: false)} cap used · ${Money.aed(cap.remaining)} left',
                        style: context.tt.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      verified,
                      style: context.tt.labelSmall!.copyWith(
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Everything else', style: context.tt.bodyLarge),
                  ),
                  Text(
                    formatRate(card.baseRate),
                    style: PulseTheme.amount(c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                verified,
                style: context.tt.labelSmall!.copyWith(color: c.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Utilisation per card as horizontal bars with the 30% guide.
class UtilisationChart extends StatelessWidget {
  const UtilisationChart(this.cards, {super.key});
  final List<CreditCard> cards;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final limit = cards.fold<double>(0, (a, k) => a + k.limit);
    final used = cards.fold<double>(0, (a, k) => a + k.balance);
    final overall = limit == 0 ? 0.0 : used / limit;
    Color tone(double u) => u > 0.5
        ? c.negative
        : u > 0.3
        ? c.warning
        : c.accent;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Overall ${(overall * 100).round()}% of ${Money.aed(limit, decimals: false)}',
            style: context.tt.bodyMedium,
          ),
          const SizedBox(height: Space.lg),
          for (final k in cards) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    cardName(k),
                    style: context.tt.bodyMedium!.copyWith(
                      color: c.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${(k.utilisation * 100).round()}%',
                  style: PulseTheme.amount(tone(k.utilisation), size: 15),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, box) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Meter(
                    value: k.utilisation,
                    color: tone(k.utilisation),
                    height: 8,
                  ),
                  Positioned(
                    left: box.maxWidth * 0.3 - 0.5,
                    top: -3,
                    child: Container(
                      width: 1,
                      height: 14,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${Money.aed(k.balance, decimals: false)} of ${Money.aed(k.limit, decimals: false)}',
              style: context.tt.bodySmall,
            ),
            const SizedBox(height: Space.lg),
          ],
          Text(
            'The line marks 30%. Staying under it helps your credit score.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}
