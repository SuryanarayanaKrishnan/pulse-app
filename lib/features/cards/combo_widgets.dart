import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/entitlement/entitlement.dart';
import '../../core/entitlement/plus_gate.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import '../../data/card_combos.dart';
import '../../data/providers.dart';

/// "Card combos" for everyone, with or without cards. Free items read in full;
/// Plus items show their title and a lock until the user has Plus.
class CardCombosSection extends ConsumerWidget {
  const CardCombosSection({super.key, this.limit});

  /// Cap on rows shown (the wallet shows a few, the full list opens a sheet).
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(cardCombosProvider).value ?? const [];
    if (combos.isEmpty) return const SizedBox.shrink();
    final shown = limit == null ? combos : combos.take(limit!).toList();
    final names = _catalogNames(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Card combos',
          action: limit != null && combos.length > limit! ? 'See all' : null,
          onAction: () => showPulseSheet<void>(
            context,
            full: true,
            builder: (_) => const _AllCombosSheet(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Space.gutter,
            0,
            Space.gutter,
            Space.sm,
          ),
          child: Text(
            'Which card to use where, and what stacks. No cards needed.',
            style: context.tt.bodySmall!.copyWith(
              color: context.pc.textSecondary,
            ),
          ),
        ),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [for (final k in shown) ComboRow(k, names: names)],
        ),
      ],
    );
  }
}

Map<String, String> _catalogNames(WidgetRef ref) {
  final cat = ref.watch(catalogProvider).value ?? const [];
  return {
    for (final c in cat)
      if (c.catalogId != null) c.catalogId!: '${c.issuer} ${c.name}',
  };
}

String cardLabel(String id, Map<String, String> names) =>
    names[id] ??
    id
        .split('-')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

class ComboRow extends ConsumerWidget {
  const ComboRow(this.combo, {super.key, this.names = const {}});
  final CardCombo combo;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final locked =
        combo.isPlus && !ref.watch(canUseProvider(PlusFeature.nicheIntel));
    return ListRow(
      leading: IconWell(
        locked
            ? Icons.lock_outline_rounded
            : (combo.isWarning
                  ? Icons.error_outline_rounded
                  : Icons.layers_outlined),
        color: locked
            ? c.textTertiary
            : (combo.isWarning ? c.warning : c.accent),
      ),
      title: combo.title,
      subtitle: locked ? 'Niche detail with Plus' : combo.headline,
      trailing: locked ? const PlusBadge() : null,
      chevron: !locked,
      onTap: () => locked
          ? showPaywall(context, PlusFeature.nicheIntel)
          : showPulseSheet<void>(
              context,
              builder: (_) => ComboDetailSheet(combo, names: names),
            ),
    );
  }
}

class ComboDetailSheet extends StatelessWidget {
  const ComboDetailSheet(this.combo, {super.key, this.names = const {}});
  final CardCombo combo;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(combo.title, style: context.tt.headlineSmall),
          const SizedBox(height: Space.sm),
          Text(
            combo.confidenceLabel,
            style: context.tt.labelMedium!.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: Space.lg),
          Text(combo.body, style: context.tt.bodyLarge),
          const SizedBox(height: Space.lg),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final id in combo.cardIds) Pill(cardLabel(id, names)),
            ],
          ),
          if (combo.validUntil != null) ...[
            const SizedBox(height: Space.md),
            Text(
              'Applies until ${combo.validUntil!.day}/${combo.validUntil!.month}/${combo.validUntil!.year}.',
              style: context.tt.bodySmall!.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: Space.md),
          Text(
            'Terms change. Check the bank before you apply or pay. Not financial advice.',
            style: context.tt.bodySmall!.copyWith(color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _AllCombosSheet extends ConsumerWidget {
  const _AllCombosSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combos = ref.watch(cardCombosProvider).value ?? const [];
    final names = _catalogNames(ref);
    return ListView(
      padding: const EdgeInsets.only(bottom: Space.xxxl),
      children: [
        const SectionHeader('Card combos', top: Space.md),
        RowGroup(
          indent: ListRow.leadingInset,
          children: [for (final k in combos) ComboRow(k, names: names)],
        ),
      ],
    );
  }
}
