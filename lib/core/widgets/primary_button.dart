import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'haptics.dart';

/// Gradient pill button with press-scale and haptic feedback.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.secondary = false,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;
  final bool loading;
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final enabled = widget.onPressed != null && !widget.loading;
    final fg = widget.secondary ? c.textPrimary : Colors.white;
    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 20, color: fg),
            const SizedBox(width: 8),
          ],
          Text(widget.label, style: context.tt.labelLarge!.copyWith(color: fg)),
        ],
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                Haptics.medium();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
            opacity: enabled || widget.loading ? 1 : 0.5,
            duration: const Duration(milliseconds: 200),
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.pill),
                gradient: widget.secondary
                    ? null
                    : LinearGradient(
                        colors: [
                          c.accent,
                          Color.lerp(c.accent, c.accentAlt, 0.55)!,
                        ],
                      ),
                color: widget.secondary ? c.surfaceElevated : null,
                border: widget.secondary ? Border.all(color: c.border) : null,
                boxShadow: widget.secondary ? null : Elevations.glow(c.accent),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
