import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/engine/habit_model.dart';
import '../../core/engine/superapps.dart';
import '../../core/learning/learning_controller.dart';
import '../../data/learning_hooks.dart';
import '../../data/providers.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';

/// One transaction row: category glyph, merchant, category and source.
class TxTile extends ConsumerWidget {
  const TxTile(this.tx, {super.key, this.onTap});
  final Transaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.pc;
    final row = _row(context, c);
    final sa = superAppFor(tx.merchant);
    final chips = tx.guess && !tx.reviewed && sa != null
        ? chipsFor(
            tx.merchant,
            ranked: [
              for (final g
                  in ref
                      .read(merchantMemoryProvider)
                      .habits
                      .rank(
                        sa.key,
                        (tx.amount * 100).round(),
                        dubaiHour(tx.date),
                      ))
                g.category,
            ],
          )
        : const <String>[];
    if (chips.isEmpty) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final slug in chips)
                ActionChip(
                  key: ValueKey('chip-$slug'),
                  label: Text(_label(slug)),
                  onPressed: () => unawaited(_pick(ref, slug, chips.first)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _label(String slug) => SpendCategory.defaults
      .firstWhere((c) => c.id == slug, orElse: () => SpendCategory.other)
      .label;

  /// One tap: set the category, learn it for this size of payment.
  Future<void> _pick(WidgetRef ref, String slug, String first) async {
    final cat = SpendCategory.defaults.firstWhere(
      (c) => c.id == slug,
      orElse: () => SpendCategory.other,
    );
    await ref.read(repositoryProvider).recategorise(tx.id, cat);
    unawaited(
      ref
          .read(merchantMemoryProvider)
          .bump(chipTaps: 1, topChipTaps: first == slug ? 1 : 0),
    );
    unawaited(
      rememberCategoryChoice(ref.read(merchantMemoryProvider), tx, cat),
    );
    unawaited(
      recordConfirmedCategory(ref.read(learningControllerProvider), tx, cat),
    );
    invalidateLedger(ref);
  }

  Widget _row(BuildContext context, PulseColors c) {
    return ListRow(
      leading: CategoryIcon.well(tx.category),
      title: tx.merchant,
      titleStyle: context.tt.bodyLarge!.copyWith(
        color: tx.excluded ? c.textTertiary : null,
      ),
      subtitle: [
        tx.category.label,
        tx.source.label,
        if (tx.pendingHold)
          'Hold, waiting for the final charge'
        else if (tx.excluded)
          'Excluded',
      ].join(' · '),
      // An enormous amount shrinks to fit instead of running off the screen.
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            Money.aed(tx.signed, sign: true),
            style: PulseTheme.amount(
              tx.excluded
                  ? c.textTertiary
                  : (tx.isIncome ? c.positive : c.textPrimary),
            ),
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
