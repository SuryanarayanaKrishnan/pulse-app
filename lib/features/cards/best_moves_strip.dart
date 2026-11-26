import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/entitlement/entitlement.dart';
import '../../core/entitlement/plus_gate.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/best_moves.dart';
import '../../data/card_combos.dart';
import '../../data/providers.dart';
import 'combo_widgets.dart';

/// "Best moves": the top few card combos as a swipeable strip, each with its
/// estimated yearly saving when the catalog has one. Needs no cards. Sits on
/// Home so the app's highlight is not three taps deep.
class BestMovesStrip extends ConsumerWidget {
  const BestMovesStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(cardCombosProvider).value ?? const <CardCombo>[];
    final moves = pickBestMoves(all);
    if (moves.isEmpty) return const SizedBox.shrink();
    final fresh = ref.watch(newHighValueCombosProvider);
    final names = _names(ref);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Column(
      key: const Key('best_moves'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Best moves',
          action: 'See all',
          onAction: () => showAllCombos(context),
        ),
        SnapRail(
          height: 150 * scale + 8,
          visible: 1.25,
          itemCount: moves.length,
          itemBuilder: (context, i) => BestMoveCard(
            moves[i],
            isNew: fresh.contains(moves[i].id),
            names: names,
          ),
        ),
      ],
    );
  }

  static Map<String, String> _names(WidgetRef ref) {
    final cat = ref.watch(catalogProvider).value ?? const [];
    return {
      for (final c in cat)
        if (c.catalogId != null) c.catalogId!: '${c.issuer} ${c.name}',
    };
  }
}

/// One move: what it is, what it could save, and a quiet "New" when it
/// has not been opened yet.
class BestMoveCard extends ConsumerWidget {
  const BestMoveCard(
    this.combo, {
    super.key,
    this.isNew = false,
    this.names = const {},
  });
  final CardCombo combo;
  final bool isNew;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final locked =
        combo.isPlus && !ref.watch(canUseProvider(PlusFeature.nicheIntel));
    return SurfaceCard(
      key: Key('best_move_${combo.id}'),
      padding: const EdgeInsets.all(Space.md),
      onTap: () {
        ref.read(seenCombosProvider.notifier).markSeen([combo.id]);
        if (locked) {
          showPaywall(context, PlusFeature.nicheIntel);
        } else {
          showPulseSheet<void>(
            context,
            builder: (_) => ComboDetailSheet(combo, names: names),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                locked ? Icons.lock_outline_rounded : Icons.layers_outlined,
                size: 20,
                color: locked ? c.textTertiary : c.accent,
              ),
              const SizedBox(width: Space.sm),
              Text(
                '${combo.cardIds.length} cards',
                style: context.tt.labelMedium!.copyWith(color: c.textSecondary),
              ),
              const Spacer(),
              if (isNew)
                Container(
                  key: const Key('best_move_new'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Text(
                    'New',
                    style: context.tt.labelSmall!.copyWith(
                      color: c.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Space.sm),
          Expanded(
            child: Text(
              combo.title,
              style: context.tt.titleSmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (combo.hasSaving) ...[
            Text(
              'Up to ${Money.aed(combo.annualSavingAed!, decimals: false)} a year',
              style: context.tt.titleSmall!.copyWith(color: c.positive),
            ),
            Text(
              'Estimate, not a promise',
              style: context.tt.labelSmall!.copyWith(color: c.textTertiary),
            ),
          ] else
            Text(
              'Card tip',
              style: context.tt.labelMedium!.copyWith(color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}
