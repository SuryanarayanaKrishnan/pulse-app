import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// A single 2pt line. No fill, no dot, no axes.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 56,
    this.color,
  });
  final List<double> values;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pc.calm;
    if (values.length < 2) return SizedBox(height: height);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * 0.1 + 1;
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minV - pad,
          maxY: maxV + pad,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: const FlTitlesData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < values.length; i++)
                  FlSpot(i.toDouble(), values[i]),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              barWidth: 2,
              color: c,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.curve,
      ),
    );
  }
}

class ChartSlice {
  const ChartSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// One horizontal stacked bar: proportion at a glance, no legend clutter.
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.slices, this.height = 8});
  final List<ChartSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold(0.0, (a, s) => a + s.value);
    if (total <= 0) return SizedBox(height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            for (var i = 0; i < slices.length; i++) ...[
              if (i > 0)
                SizedBox(width: 2, child: ColoredBox(color: context.pc.bg)),
              Expanded(
                flex: (slices[i].value / total * 1000).round().clamp(1, 1000),
                child: ColoredBox(color: slices[i].color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Month-over-month spend bars with a planned-budget reference line. Neutral
/// bars; only the current month carries the accent.
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.labels,
    required this.values,
    required this.planned,
    this.height = 140,
  });
  final List<String> labels;
  final List<double> values;
  final double planned;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final maxV = [planned, ...values].reduce((a, b) => a > b ? a : b) * 1.1;
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxV,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, m) => Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Text(
                    labels[v.toInt()],
                    style: context.tt.labelMedium!.copyWith(
                      color: v.toInt() == labels.length - 1
                          ? c.textPrimary
                          : c.textTertiary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: planned,
                color: c.textTertiary,
                strokeWidth: 0.5,
                dashArray: [3, 3],
              ),
            ],
          ),
          barGroups: [
            for (var i = 0; i < values.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: values[i],
                    width: 20,
                    borderRadius: BorderRadius.circular(Radii.sm / 2),
                    color: i == values.length - 1
                        ? c.accent
                        : c.surfaceElevated,
                  ),
                ],
              ),
          ],
        ),
        duration: Motion.slow,
        curve: Motion.curve,
      ),
    );
  }
}

/// Allocation donut: slices as arcs with thin gaps, an optional centre.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.slices, this.size = 140, this.thickness = 16, this.center});
  final List<ChartSlice> slices;
  final double size, thickness;
  final Widget? center;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size.square(size),
          painter: _DonutPainter(slices, thickness, context.pc.surfaceElevated),
        ),
        ?center,
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.thickness, this.track);
  final List<ChartSlice> slices;
  final double thickness;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final r = rect.deflate(thickness / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = track;
    canvas.drawArc(r, 0, 2 * math.pi, false, base);
    final total = slices.fold(0.0, (a, s) => a + s.value);
    if (total <= 0) return;
    const gap = 0.035;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * 2 * math.pi;
      final draw = slices.length > 1 ? math.max(sweep - gap, 0.01) : sweep;
      canvas.drawArc(
        r,
        start + (slices.length > 1 ? gap / 2 : 0),
        draw,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.slices != slices || old.thickness != thickness || old.track != track;
}
