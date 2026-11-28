import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../wallet/add_sheets.dart' show AddCardSheet;

/// Tick every card you hold, add them all at once. No per-card popup: last
/// digits, limit and due dates can be added later from the card.
class QuickPickCardsSheet extends ConsumerStatefulWidget {
  const QuickPickCardsSheet({super.key, this.preselect = const {}});

  /// Catalog ids ticked on open.
  final Set<String> preselect;

  @override
  ConsumerState<QuickPickCardsSheet> createState() =>
      _QuickPickCardsSheetState();
}

class _QuickPickCardsSheetState extends ConsumerState<QuickPickCardsSheet> {
  late final Set<String> _picked = {...widget.preselect};
  String _query = '';
  bool _busy = false;

  Future<void> _save(List<CreditCard> catalog) async {
    setState(() => _busy = true);
    final repo = ref.read(repositoryProvider);
    try {
      for (final k in catalog.where((k) => _picked.contains(k.id))) {
        await repo.addCard(catalogId: k.id, last4: '');
      }
      invalidateWallet(ref);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Added. Open a card to add its last four digits so alerts match it.',
            ),
          ),
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add every card. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final catalog = ref.watch(catalogProvider).value ?? const <CreditCard>[];
    final held = {
      for (final k in ref.watch(myCardsProvider).value ?? const <CreditCard>[])
        k.catalogId,
    };
    final shown = [
      for (final k in catalog)
        if (!held.contains(k.id) &&
            (_query.isEmpty ||
                '${k.issuer} ${k.name}'.toLowerCase().contains(_query)))
          k,
    ];
    final n = _picked.length;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.md,
              Space.gutter,
              Space.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which cards do you hold?',
                  style: context.tt.headlineSmall,
                ),
                const SizedBox(height: Space.xs),
                Text(
                  'Tick them all. Details can wait.',
                  style: context.tt.bodyMedium!.copyWith(
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: Space.md),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by bank or card',
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Space.lg),
              children: [
                for (final k in shown)
                  ListRow(
                    leading: SizedBox(
                      width: 56,
                      child: CreditCardVisual(card: k, compact: true),
                    ),
                    title: '${k.issuer} ${k.name}',
                    subtitle: k.highlight,
                    trailing: Icon(
                      _picked.contains(k.id)
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: _picked.contains(k.id) ? c.accent : c.textTertiary,
                    ),
                    onTap: () => setState(
                      () => _picked.contains(k.id)
                          ? _picked.remove(k.id)
                          : _picked.add(k.id),
                    ),
                  ),
                ListRow(
                  key: const Key('cant_find_card'),
                  leading: IconWell(Icons.add_card_outlined, color: c.calm),
                  title: "I can't find my card",
                  subtitle: 'Add it yourself',
                  chevron: true,
                  onTap: () async {
                    await showPulseSheet<void>(
                      context,
                      full: true,
                      builder: (_) => const AddCardSheet(startCustom: true),
                    );
                    ref.invalidate(catalogProvider);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.sm,
              Space.gutter,
              Space.md,
            ),
            child: PrimaryButton(
              label: n == 0
                  ? 'Pick your cards'
                  : (n == 1 ? 'Add 1 card' : 'Add $n cards'),
              loading: _busy,
              onPressed: n == 0 ? null : () => _save(catalog),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showQuickPickCards(
  BuildContext context, {
  Set<String> preselect = const {},
}) => showPulseSheet<void>(
  context,
  full: true,
  builder: (_) => QuickPickCardsSheet(preselect: preselect),
);
