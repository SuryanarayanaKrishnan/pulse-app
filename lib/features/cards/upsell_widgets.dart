import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/analytics/analytics.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_upsell_providers.dart';
import '../../data/models.dart';
import 'card_widgets.dart' show cardName;
import 'credit_capacity.dart';
import 'quick_pick_sheet.dart';

const _surface = 'which_card';

String _aed(int minor) => Money.aed(minor / 100, decimals: false);

/// A quiet "You'd earn more with..." row under the best-card answer: one card
/// the user does not hold, with the estimated extra AED a month and a year.
/// Renders nothing when there is nothing worth saying.
class UpsellRow extends ConsumerStatefulWidget {
  const UpsellRow({super.key, required this.category});
  final SpendCategory category;

  @override
  ConsumerState<UpsellRow> createState() => _UpsellRowState();
}

class _UpsellRowState extends ConsumerState<UpsellRow> {
  String? _shownFor;

  void _logShown(String cardId) {
    if (_shownFor == cardId) return;
    _shownFor = cardId;
    ref
        .read(analyticsProvider)
        .track(AnalyticsEvent.cardSuggestionShown(_surface));
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(cardUpsellProvider(widget.category.id)).value;
    if (view == null) return const SizedBox.shrink();
    _logShown(view.upsell.card.id);
    final c = context.pc;
    final u = view.upsell;
    final fee = u.annualFeeMinor > 0
        ? ', after the ${_aed(u.annualFeeMinor)} annual fee'
        : '';
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Hairline(),
          const SizedBox(height: Space.md),
          Text(
            "You'd earn more with...",
            style: context.tt.labelMedium!.copyWith(color: c.textSecondary),
          ),
          ListRow(
            key: const Key('upsell_row'),
            dense: true,
            leading: SizedBox(
              width: 44,
              child: CreditCardVisual(card: view.display, compact: true),
            ),
            title: cardName(view.display),
            subtitle:
                'About +${_aed(u.netMonthlyMinor)} a month, +${_aed(u.netYearlyMinor)} a year$fee (estimate)',
            chevron: true,
            onTap: () {
              ref
                  .read(analyticsProvider)
                  .track(AnalyticsEvent.cardSuggestionTapped(_surface));
              showPulseSheet<void>(
                context,
                builder: (_) => UpsellDetailSheet(view, widget.category),
              );
            },
          ),
          const DbrNewCardNote(),
          Align(
            alignment: Alignment.centerRight,
            child: TextAction(
              'Not interested',
              color: c.textTertiary,
              onTap: () => _dismiss(u.card.id, cardName(view.display)),
            ),
          ),
        ],
      ),
    );
  }

  void _dismiss(String id, String name) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(dismissedUpsellsProvider.notifier);
    notifier.dismiss(id);
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Hidden. You can show $name again in Settings.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.restore(id),
        ),
      ),
    );
  }
}

/// The suggested card in full: where the estimate comes from, and what to do.
class UpsellDetailSheet extends ConsumerWidget {
  const UpsellDetailSheet(this.view, this.category, {super.key});
  final UpsellView view;
  final SpendCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final u = view.upsell;
    final card = view.display;
    final best = u.ownedBest;
    final spend = _aed(u.monthlySpendMinor);
    return SheetScaffold(
      title: cardName(card),
      subtitle: 'An estimate, not a promise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SizedBox(width: 220, child: CreditCardVisual(card: card)),
          ),
          const SizedBox(height: Space.lg),
          RowGroup(
            children: [
              ListRow(
                dense: true,
                title: 'Earns on ${category.label.toLowerCase()}',
                trailing: Text(formatRateText(card, category)),
              ),
              if (best != null)
                ListRow(
                  dense: true,
                  title: 'Your best card for it',
                  subtitle: '${best.issuer} ${best.name}',
                  trailing: Text(_aed(u.ownedMonthlyMinor)),
                ),
              ListRow(
                dense: true,
                title: 'This card',
                trailing: Text(_aed(u.candidateMonthlyMinor)),
              ),
              ListRow(
                dense: true,
                title: 'Annual fee',
                trailing: Text(
                  u.annualFeeMinor > 0 ? _aed(u.annualFeeMinor) : 'None',
                ),
              ),
              ListRow(
                dense: true,
                title: 'Extra a year, after fee',
                trailing: Text(
                  '+${_aed(u.netYearlyMinor)}',
                  style: context.tt.labelLarge!.copyWith(color: c.positive),
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Text(
            'Worked out on about $spend a month of ${category.label.toLowerCase()}, '
            '${view.typicalSpend ? 'a typical month rather than yours' : 'from your last three months'}. '
            'Rates are from the built-in catalog and can change; the bank decides approval.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'I already hold this card',
            secondary: true,
            onPressed: () {
              Navigator.of(context).pop();
              showQuickPickCards(context, preselect: {u.card.id});
            },
          ),
          const SizedBox(height: Space.sm),
          Center(
            child: TextAction(
              'Not interested',
              color: c.textTertiary,
              onTap: () {
                ref.read(dismissedUpsellsProvider.notifier).dismiss(u.card.id);
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}

String formatRateText(CreditCard card, SpendCategory cat) {
  final r = card.categoryRates[cat] ?? card.baseRate;
  return '${r.toStringAsFixed(r % 1 == 0 ? 0 : 1)}%';
}

/// Settings: suggestions the user hid, each with "Show again".
class HiddenSuggestionsSheet extends ConsumerWidget {
  const HiddenSuggestionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids =
        (ref.watch(dismissedUpsellsProvider).value ?? const <String>{}).toList()
          ..sort();
    final names = {
      for (final c in ref.watch(upsellCatalogProvider).value ?? const [])
        c.id: '${c.issuer} ${c.name}',
    };
    return SheetScaffold(
      title: 'Hidden card suggestions',
      subtitle: 'Cards you said you are not interested in',
      child: ids.isEmpty
          ? Text('Nothing hidden.', style: context.tt.bodyMedium)
          : RowGroup(
              children: [
                for (final id in ids)
                  ListRow(
                    dense: true,
                    title: names[id] ?? id,
                    trailing: TextAction(
                      'Show again',
                      onTap: () => ref
                          .read(dismissedUpsellsProvider.notifier)
                          .restore(id),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> showHiddenSuggestions(BuildContext context) =>
    showPulseSheet<void>(
      context,
      builder: (_) => const HiddenSuggestionsSheet(),
    );
