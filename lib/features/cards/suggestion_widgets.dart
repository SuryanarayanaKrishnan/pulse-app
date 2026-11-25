import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_suggestions.dart';
import '../../data/providers.dart';
import 'quick_pick_sheet.dart';

final cardSuggestionsProvider = FutureProvider<List<CardSuggestion>>((ref) async {
  final catalog = await ref.watch(catalogProvider.future);
  final owned = await ref.watch(myCardsProvider.future);
  final txs = ref.watch(transactionsProvider).value ?? const [];
  return suggestCards(catalog: catalog, owned: owned, txs: txs, now: DateTime.now());
});

/// "Cards worth having": shown at once, from your spend when there is enough,
/// otherwise from a typical profile (and says so). No setup needed.
class CardSuggestionsSection extends ConsumerWidget {
  const CardSuggestionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(cardSuggestionsProvider).value ?? const [];
    if (list.isEmpty) return const SizedBox.shrink();
    final c = context.pc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Cards worth having'),
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.sm),
          child: Text(
            list.first.typical
                ? 'Based on a typical month. Pulse switches to your own spend as it learns it.'
                : 'Based on your last three months of spending.',
            style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
          ),
        ),
        RowGroup(
          indent: 56 + Space.md,
          children: [
            for (final s in list)
              ListRow(
                leading: SizedBox(width: 56, child: CreditCardVisual(card: s.card, compact: true)),
                title: '${s.card.issuer} ${s.card.name}',
                subtitle: s.reason,
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '+${Money.aed(s.annualGain, decimals: false)}',
                      style: context.tt.labelLarge!.copyWith(color: c.positive),
                    ),
                    Text('a year', style: context.tt.labelSmall),
                  ],
                ),
                onTap: () => showPulseSheet<void>(context, builder: (_) => _SuggestionSheet(s)),
              ),
          ],
        ),
      ],
    );
  }
}

class _SuggestionSheet extends StatelessWidget {
  const _SuggestionSheet(this.s);
  final CardSuggestion s;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SheetScaffold(
      title: '${s.card.issuer} ${s.card.name}',
      subtitle: 'About ${Money.aed(s.annualGain, decimals: false)} a year more than your current cards.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.reason, style: context.tt.bodyLarge),
          const SizedBox(height: Space.sm),
          Text(
            s.typical
                ? 'An estimate from a typical month. Rates are from the built-in catalog and can change.'
                : 'An estimate from your last three months. Rates are from the built-in catalog and can change.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
          const SizedBox(height: Space.lg),
          PrimaryButton(
            label: 'I already hold this card',
            secondary: true,
            onPressed: () {
              Navigator.of(context).pop();
              showQuickPickCards(context, preselect: {s.card.id});
            },
          ),
        ],
      ),
    );
  }
}
