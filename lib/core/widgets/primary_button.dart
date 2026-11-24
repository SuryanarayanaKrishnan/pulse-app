import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'haptics.dart';
import 'pressable.dart';

/// Solid accent button (or a quiet filled secondary). 50pt tall, 12pt radius.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.expand = true,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final bool expand;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final enabled = onPressed != null && !loading;
    final fg = secondary
        ? (destructive ? c.negative : c.accent)
        : (destructive ? Colors.white : c.onAccent);
    final bg = secondary
        ? c.surfaceElevated
        : (destructive ? c.negative : c.accent);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: enabled
            ? () {
                Haptics.medium();
                onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          opacity: enabled || loading ? 1 : 0.4,
          duration: Motion.base,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                  )
                else ...[
                  if (icon != null) ...[
                    Icon(icon, size: 20, color: fg),
                    const SizedBox(width: Space.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: context.tt.labelLarge!.copyWith(color: fg),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain accent text action with a 44pt hit target.
class TextAction extends StatelessWidget {
  const TextAction(this.label, {super.key, required this.onTap, this.color});
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Pressable(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: context.tt.titleSmall!.copyWith(
              color: color ?? context.pc.accent,
            ),
          ),
        ),
      ),
    ),
  );
}
