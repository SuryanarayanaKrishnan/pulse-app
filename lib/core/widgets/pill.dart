import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'haptics.dart';

/// Chip / pill, optionally selectable.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.icon,
    this.selected = false,
    this.onTap,
    this.color,
  });
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final tint = color ?? c.accent;
    final pill = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? tint.withValues(alpha: 0.2) : c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(
          color: selected ? tint.withValues(alpha: 0.7) : c.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? tint : c.textSecondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: context.tt.labelMedium!.copyWith(
              color: selected ? c.textPrimary : c.textSecondary,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap!();
      },
      child: pill,
    );
  }
}
