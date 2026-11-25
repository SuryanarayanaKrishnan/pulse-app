import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'pressable.dart';

/// Hairline separator (0.5pt), optionally inset from the leading edge.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.indent = 0});
  final double indent;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: indent),
    child: Container(height: 0.5, color: context.pc.border),
  );
}

/// Rows separated by inset hairlines, sitting on the page background.
class RowGroup extends StatelessWidget {
  const RowGroup({
    super.key,
    required this.children,
    this.indent = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.gutter),
  });
  final List<Widget> children;

  /// Hairline inset; aligns separators with row text when rows have a
  /// leading icon.
  final double indent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Hairline(indent: indent),
          children[i],
        ],
      ],
    ),
  );
}

/// Standard list row: optional leading, title + subtitle, trailing.
/// Minimum 52pt tall; 44pt hit targets are guaranteed.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.titleStyle,
    this.subtitleColor,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final TextStyle? titleStyle;
  final Color? subtitleColor;
  final bool dense;

  /// Leading width + gap, for hairline indents.
  static const leadingInset = 32.0 + Space.md;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: dense ? 44 : 52),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: dense ? Space.sm : Space.md),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: Space.md)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: titleStyle ?? context.tt.bodyLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: context.tt.bodySmall!.copyWith(
                        color: subtitleColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.md),
              // Huge amounts or long labels shrink instead of overflowing.
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.45),
                  child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: trailing!),
                ),
              ),
            ],
            if (chevron) ...[
              const SizedBox(width: Space.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: c.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
    return onTap == null ? row : Pressable(onTap: onTap, child: row);
  }
}

/// Monochrome 32pt icon well used as a row's leading element.
class IconWell extends StatelessWidget {
  const IconWell(this.icon, {super.key, this.color, this.size = 32});
  final IconData icon;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Icon(icon, size: size * 0.56, color: color ?? c.textSecondary),
    );
  }
}

/// Small status dot.
class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// Thin, rounded meter. Animates from its previous value.
class Meter extends StatelessWidget {
  const Meter({super.key, required this.value, this.color, this.height = 4});
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: v, end: v),
          duration: Motion.slow,
          curve: Motion.curve,
          builder: (_, x, _) => Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: c.surfaceElevated),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: x,
                child: ColoredBox(color: color ?? c.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
