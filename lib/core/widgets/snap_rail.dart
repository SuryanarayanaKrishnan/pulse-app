import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Horizontal rail of fixed-width tiles that snaps to tile edges. Tiles are
/// sized so the next one always peeks in by a clear margin, which reads as
/// "scroll" rather than "clipped".
class SnapRail extends StatelessWidget {
  const SnapRail({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.visible = 2.35,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;

  /// How many tiles fit the viewport (fractional part = the peek).
  final double visible;

  static const gap = Space.md;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final avail = box.maxWidth - Space.gutter;
      final w = ((avail - gap * visible.floor()) / visible).floorToDouble();
      return SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
          physics: _SnapPhysics(extent: w + gap),
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(width: gap),
          itemBuilder: (c, i) => SizedBox(width: w, child: itemBuilder(c, i)),
        ),
      );
    },
  );
}

/// Snaps to multiples of [extent] using the platform's spring.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.extent, super.parent});
  final double extent;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(extent: extent, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final page = position.pixels / extent;
    final target = (velocity.abs() < toleranceFor(position).velocity
            ? page.roundToDouble()
            : (velocity > 0 ? page.floorToDouble() + 1 : page.ceilToDouble() - 1)) *
        extent;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((clamped - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      clamped,
      velocity,
      tolerance: toleranceFor(position),
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}
