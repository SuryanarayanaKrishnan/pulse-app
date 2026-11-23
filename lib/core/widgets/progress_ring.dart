import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Animated circular progress used for budgets. Turns warm when over budget.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.stroke = 12,
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
    final over = progress > 1;
    final base =
        color ?? (over ? c.negative : (progress > 0.85 ? c.warning : c.accent));
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(
            v,
            c.border.withValues(alpha: 0.6),
            base,
            Color.lerp(base, c.accentAlt, 0.6)!,
            stroke,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.p, this.track, this.a, this.b, this.stroke);
  final double p;
  final Color track;
  final Color a;
  final Color b;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect =
        Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    final sweep = math.min(p, 1.0) * math.pi * 2;
    if (sweep <= 0) return;
    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + math.pi * 2,
        colors: [a, b, a],
        transform: const GradientRotation(0),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.p != p || o.a != a || o.track != track;
}
