import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../theme/tokens.dart';

/// Small badge showing how a transaction was captured.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key, this.showLabel = true});
  final TxSource source;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tint = source.automatic ? c.accentAlt : c.warning;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 7 : 5, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(source.icon, size: 11, color: tint),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              source.label,
              style: context.tt.labelSmall!.copyWith(
                color: tint,
                letterSpacing: 0.2,
                fontSize: 10,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
