import 'dart:ui';

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';
import 'haptics.dart';

/// Frosted, softly-bordered surface. Pass [gradient] for a tinted hero card.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Space.lg),
    this.gradient,
    this.onTap,
    this.blur = false,
    this.radius = Radii.lg,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final bool blur;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final br = BorderRadius.circular(radius);
    Widget body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        gradient:
            gradient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                c.surfaceElevated.withValues(alpha: c.isDark ? 0.9 : 1),
                c.surface,
              ],
            ),
        border: Border.all(color: c.glassBorder),
        boxShadow: Elevations.soft(c),
      ),
      child: child,
    );
    if (blur) {
      body = ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: body,
        ),
      );
    }
    if (onTap == null) return body;
    return _Pressable(onTap: onTap!, child: body);
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: () {
      Haptics.tap();
      widget.onTap();
    },
    child: AnimatedScale(
      scale: _down ? 0.975 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}
