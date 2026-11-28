import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../transactions/tx_detail_sheet.dart';
import 'feature_catalog.dart';

/// Search: one field for every screen and setting, plus your cards and your
/// spending once you type two letters. With nothing typed it lists every
/// feature, so nothing is hidden three taps deep.
Future<void> showAllFeaturesSheet(BuildContext context) => showPulseSheet<void>(
  context,
  full: true,
  builder: (_) => const AllFeaturesSheet(),
);

class AllFeaturesSheet extends ConsumerStatefulWidget {
  const AllFeaturesSheet({super.key});
  @override
  ConsumerState<AllFeaturesSheet> createState() => _AllFeaturesSheetState();
}

class _AllFeaturesSheetState extends ConsumerState<AllFeaturesSheet> {
  String _q = '';

  void _open(PulseFeature f) {
    // The sheet sits on the root navigator; close it, then go.
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(f.route);
  }

  void _openCard() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.go(Routes.cards);
  }

  void _openTx(Transaction t) {
    final nav = Navigator.of(context);
    nav.pop();
    showPulseSheet<void>(nav.context, builder: (_) => TxDetailSheet(tx: t));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final hits = [
      for (final f in pulseFeatures)
        if (f.matches(_q)) f,
    ];
    final q = _q.trim().toLowerCase();
    final cards = q.length < 2
        ? const <CreditCard>[]
        : [
            for (final k
                in ref.watch(myCardsProvider).value ?? const <CreditCard>[])
              if ('${k.issuer} ${k.name} ${k.last4}'.toLowerCase().contains(q))
                k,
          ];
    final spend = q.length < 2
        ? const <Transaction>[]
        : [
            for (final t
                in ref.watch(transactionsProvider).value ??
                    const <Transaction>[])
              if (t.merchant.toLowerCase().contains(q)) t,
          ].take(6).toList();
    final groups = <String>[];
    for (final f in hits) {
      if (!groups.contains(f.group)) groups.add(f.group);
    }
    return SheetScaffold(
      title: 'Search',
      subtitle: 'Settings, screens, cards and spending. Try "gmail" or "dark".',
      // SheetScaffold already scrolls; a nested ListView here fought it and
      // made the sheet bounce back up.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('features-search'),
            onChanged: (v) => setState(() => _q = v),
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              hintText: 'Search Pulse',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: Space.md),
          if (hits.isEmpty && cards.isEmpty && spend.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Text(
                'Nothing matches "$_q".',
                textAlign: TextAlign.center,
                style: context.tt.bodyMedium!.copyWith(color: c.textSecondary),
              ),
            ),
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
              child: Text(
                g.toUpperCase(),
                style: context.tt.labelSmall!.copyWith(
                  color: c.textTertiary,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final f in hits.where((f) => f.group == g))
                  ListRow(
                    key: Key('feature-${f.id}'),
                    leading: IconWell(f.icon, color: c.calm),
                    title: f.title,
                    subtitle: f.subtitle,
                    chevron: true,
                    onTap: () => _open(f),
                  ),
              ],
            ),
          ],
          if (cards.isNotEmpty) ...[
            _groupLabel(context, 'Cards'),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final k in cards)
                  ListRow(
                    key: Key('search-card-${k.id}'),
                    leading: IconWell(
                      Icons.credit_card_outlined,
                      color: c.calm,
                    ),
                    title: '${k.issuer} ${k.name}',
                    subtitle: '••${k.last4}',
                    chevron: true,
                    onTap: _openCard,
                  ),
              ],
            ),
          ],
          if (spend.isNotEmpty) ...[
            _groupLabel(context, 'Spending'),
            RowGroup(
              padding: EdgeInsets.zero,
              indent: ListRow.leadingInset,
              children: [
                for (final t in spend)
                  ListRow(
                    key: Key('search-tx-${t.id}'),
                    leading: IconWell(
                      Icons.receipt_long_outlined,
                      color: c.calm,
                    ),
                    title: t.merchant,
                    subtitle: t.accountLabel,
                    chevron: true,
                    onTap: () => _openTx(t),
                  ),
              ],
            ),
          ],
          const SizedBox(height: Space.lg),
        ],
      ),
    );
  }
}

Widget _groupLabel(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: Space.sm, bottom: Space.xs),
  child: Text(
    text.toUpperCase(),
    style: context.tt.labelSmall!.copyWith(
      color: context.pc.textTertiary,
      letterSpacing: 0.8,
    ),
  ),
);
