import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../theme/tokens.dart';

/// How a transaction was captured: a quiet glyph and, optionally, a word.
class SourceBadge extends StatelessWidget {
  const SourceBadge(this.source, {super.key, this.showLabel = true});
  final TxSource source;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(source.icon, size: 12, color: c.textTertiary),
        if (showLabel) ...[
          const SizedBox(width: Space.xs),
          Text(source.label, style: context.tt.bodySmall),
        ],
      ],
    );
  }
}
