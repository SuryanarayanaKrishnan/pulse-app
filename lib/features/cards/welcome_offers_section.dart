import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/engine/welcome_offers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/welcome_offers_providers.dart';

final _day = DateFormat('d MMM yyyy');

String evidenceLabel(WelcomeOffer o) => switch (o.evidence) {
  OfferEvidence.bank => 'Bank source',
  OfferEvidence.aggregator => 'Comparison site, not the bank',
  OfferEvidence.unverified => 'Not verified yet',
};

String deadlineText(WelcomeOffer o) {
  final until = o.validUntil;
  if (until == null) return 'No end date published';
  final left = o.daysLeft!;
  final when = left == 0
      ? 'today'
      : left == 1
      ? 'tomorrow'
      : 'in $left days';
  return 'Apply by ${_day.format(until)} ($when)';
}

/// Welcome bonuses by card, soonest deadline first, each with the bank source
/// and the date it was last checked. Cards you already hold are left out.
class WelcomeOffersSection extends ConsumerWidget {
  const WelcomeOffersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final offers = ref.watch(welcomeOffersProvider).value;
    final watched = ref.watch(watchedOffersProvider).value ?? const {};
    if (offers == null) return const SizedBox.shrink();
    if (offers.isEmpty) {
      return const EmptyState(
        icon: Icons.card_giftcard_outlined,
        title: 'No open offers',
        message: 'No welcome bonus is open on a card you do not hold.',
      );
    }
    final checked = [
      for (final o in offers)
        if (o.evidence != OfferEvidence.unverified) o,
    ];
    final unchecked = [
      for (final o in offers)
        if (o.evidence == OfferEvidence.unverified) o,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.sm,
          ),
          child: Text(
            'Welcome bonuses on cards you do not hold, with the date to apply '
            'by. Every offer shows where it comes from.',
            style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
        RowGroup(children: [for (final o in checked) _row(context, o)]),
        if (unchecked.isNotEmpty) ...[
          const SectionHeader('Not verified yet'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              0,
              Space.gutter,
              Space.sm,
            ),
            child: Text(
              'These have no bank source or check date on file. Treat them '
              'as leads and confirm with the bank before applying.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ),
          RowGroup(children: [for (final o in unchecked) _row(context, o)]),
        ],
        if (watched.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              0,
            ),
            child: Text(
              'Reminders are set for ${watched.length} offer'
              '${watched.length == 1 ? '' : 's'}.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ),
      ],
    );
  }

  Widget _row(BuildContext context, WelcomeOffer o) {
    final c = context.pc;
    return ListRow(
      key: Key('offer-${o.card.id}'),
      title: '${o.card.issuer} ${o.card.name}',
      subtitle: '${o.text}\n${deadlineText(o)}',
      subtitleColor: o.endingSoon ? c.warning : null,
      trailing: o.valueAed == null
          ? null
          : Text(
              '~${Money.aed(o.valueAed!, decimals: false)}',
              style: context.tt.titleSmall,
            ),
      chevron: true,
      onTap: () =>
          showPulseSheet<void>(context, builder: (_) => OfferSheet(o.card.id)),
    );
  }
}

/// The full terms of one offer: figures, deadline, source, and a reminder.
class OfferSheet extends ConsumerWidget {
  const OfferSheet(this.cardId, {super.key});
  final String cardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final offers = ref.watch(welcomeOffersProvider).value ?? const [];
    final o = offers.where((x) => x.card.id == cardId).firstOrNull;
    if (o == null) return const SizedBox.shrink();
    final watched = ref.watch(watchedOffersProvider).value ?? const {};
    final on = watched.contains(o.card.id);
    Widget line(String k, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              k,
              style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              v,
              style: context.tt.bodyMedium!.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(Space.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${o.card.issuer} ${o.card.name}', style: context.tt.titleLarge),
          const SizedBox(height: Space.md),
          Text(o.text, style: context.tt.bodyLarge),
          const SizedBox(height: Space.md),
          line(
            'Deadline',
            deadlineText(o),
            color: o.endingSoon ? c.warning : null,
          ),
          if (o.valueAed != null)
            line('Worth about', Money.aed(o.valueAed!, decimals: false)),
          if (o.minSpendMinor != null)
            line(
              'Spend needed',
              Money.aed(o.minSpendMinor! / 100, decimals: false) +
                  (o.windowDays == null ? '' : ' in ${o.windowDays} days'),
            )
          else if (o.windowDays != null)
            line('Window', '${o.windowDays} days'),
          if (o.requiresFeePayment)
            line('Annual fee', 'You must pay the first fee to get this'),
          line(
            'Source',
            '${evidenceLabel(o)}'
                '${o.checkedOn == null ? '' : ', checked ${_day.format(o.checkedOn!)}'}',
          ),
          if (o.stale)
            line(
              'Heads up',
              'Last checked a while ago. Confirm the terms with the bank '
                  'before applying.',
              color: c.warning,
            ),
          if (o.lowConfidenceCard)
            line(
              'Heads up',
              'Our data for this card is low confidence.',
              color: c.warning,
            ),
          if (o.comboIds.isNotEmpty)
            line('Part of', 'A card combo: see Combos'),
          const SizedBox(height: Space.md),
          if (o.sourceUrl != null)
            TextAction(
              'Open the source',
              onTap: () => launchUrl(
                Uri.parse(o.sourceUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
          if (o.validUntil != null)
            PrimaryButton(
              label: on ? 'Reminder on: tap to turn off' : 'Remind me to apply',
              onPressed: () =>
                  ref.read(watchedOffersProvider.notifier).toggle(o),
            ),
        ],
      ),
    );
  }
}
