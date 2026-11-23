import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// A flat grouped surface. No border, no shadow, one radius. Use sparingly:
/// prefer [RowGroup] rows on the page background.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  /// Only for states that need attention (e.g. a reconciliation mismatch).
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
    return onTap == null ? body : Pressable(onTap: onTap, child: body);
  }
}
