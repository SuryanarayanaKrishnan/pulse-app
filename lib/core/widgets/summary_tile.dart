import 'package:material_ui/material_ui.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import 'pressable.dart';
import 'rows.dart';

/// One tile of a summary grid: what it is, the number that matters, and how
/// it moved. Tap it to see everything behind it. Flat: no border, no shadow.
class SummaryTile extends StatelessWidget {
  const SummaryTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.caption,
    this.deltaPct,
    required this.onTap,
  });

  final IconData icon;
  final String label;

  /// The headline: an amount or a count.
  final String value;

  /// A quiet line under the value ("3 pieces", "Add one").
  final String? caption;

  /// Percent up or down; null shows nothing.
  final double? deltaPct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final d = deltaPct;
    return Semantics(
      button: true,
      label: '$label, $value${d == null ? '' : ', ${_pct(d)}'}',
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconWell(icon),
              const SizedBox(height: Space.md),
              Text(
                label,
                style: context.tt.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Space.xs),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: PulseTheme.amount(c.textPrimary, size: 22),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 2),
              if (d != null)
                Text(
                  _pct(d),
                  style: context.tt.bodySmall!.copyWith(
                    color: d >= 0 ? c.positive : c.negative,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  caption ?? ' ',
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _pct(double v) =>
      '${v >= 0 ? '+' : '−'}${v.abs().toStringAsFixed(1)}%';
}

/// Two tiles per row, even height.
class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: Space.md),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: Space.md),
                Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
