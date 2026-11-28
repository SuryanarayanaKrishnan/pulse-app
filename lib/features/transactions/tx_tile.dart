import 'package:material_ui/material_ui.dart';

import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models.dart';

/// One transaction row: category glyph, merchant, category and source.
class TxTile extends StatelessWidget {
  const TxTile(this.tx, {super.key, this.onTap});
  final Transaction tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
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
