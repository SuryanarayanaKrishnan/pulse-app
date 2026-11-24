import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'haptics.dart';
import 'pressable.dart';

/// Chip, optionally selectable. Selected chips invert; no tints.
class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.icon,
    this.leading,
    this.selected = false,
    this.onTap,
  });
  final String label;
  final IconData? icon;

  /// A custom leading widget (a category glyph); wins over [icon].
  final Widget? leading;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final fg = selected ? c.bg : c.textPrimary;
    final pill = AnimatedContainer(
      duration: Motion.fast,
      curve: Motion.curve,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: Space.md + 2),
      decoration: BoxDecoration(
        color: selected ? c.textPrimary : c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: context.tt.labelMedium!.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: () {
          Haptics.tap();
          onTap!();
        },
        child: pill,
      ),
    );
  }
}

/// iOS-style segmented control with a sliding thumb.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });
  final Map<T, String> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final keys = segments.keys.toList();
    final index = keys.indexOf(value);
    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.sm + 2),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / keys.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.curve,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.isDark ? c.border : c.surface,
                    borderRadius: BorderRadius.circular(Radii.sm),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final k in keys)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: k == value,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (k == value) return;
                            Haptics.tap();
                            onChanged(k);
                          },
                          child: Center(
                            child: Text(
                              segments[k]!,
                              style: context.tt.labelMedium!.copyWith(
                                color: c.textPrimary,
                                fontWeight: k == value
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
