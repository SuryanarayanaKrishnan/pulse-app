import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Thin circular progress. Solid colour; accent, amber near the limit, red
/// over it.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 44,
    this.stroke = 4,
    this.color,
    this.child,
  });

  final double progress;
  final double size;
  final double stroke;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: progress, end: progress),
        duration: Motion.slow,
        curve: Motion.curve,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(
            v,
            c.surfaceElevated,
            color ?? c.forProgress(progress),
            stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.track, this.fg, this.stroke);
  final double p;
  final Color track;
  final Color fg;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    final sweep = math.min(p, 1.0) * math.pi * 2;
    if (sweep <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = stroke
        ..color = fg,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.p != p || o.fg != fg || o.track != track;
}
