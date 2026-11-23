import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return AnimatedBuilder(
      animation: _ctl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + _ctl.value * 3, 0),
            end: Alignment(-0.5 + _ctl.value * 3, 0),
            colors: [c.surfaceElevated, c.border, c.surfaceElevated],
          ),
        ),
      ),
    );
  }
}

/// A list of skeleton rows.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 4, this.height = 64});
  final int rows;
  final double height;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
    child: Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.md),
            child: Skeleton(height: height, radius: Radii.md),
          ),
      ],
    ),
  );
}
