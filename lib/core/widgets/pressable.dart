import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';

/// Press feedback driven by a spring so it can be interrupted and reversed
/// mid-gesture. Dims and scales very slightly; never bounces.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.98,
    this.onLongPress,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 38,
  );

  late final AnimationController _ctl = AnimationController.unbounded(
    vsync: this,
  );

  void _to(double target) => _ctl.animateWith(
    SpringSimulation(_spring, _ctl.value, target, _ctl.velocity),
  );

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _to(1),
      onTapUp: (_) => _to(0),
      onTapCancel: () => _to(0),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, child) {
          final t = _ctl.value.clamp(0.0, 1.2);
          return Opacity(
            opacity: (1 - 0.35 * t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 1 - (1 - widget.scale) * t,
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
