import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/tokens.dart';

/// Smooth gradient-filled line sparkline.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 72,
    this.color,
    this.showDot = true,
  });
  final List<double> values;
  final double height;
  final Color? color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.pc.accentAlt;
    if (values.length < 2) return SizedBox(height: height);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final pad = (maxV - minV) * 0.15 + 1;
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
              curveSmoothness: 0.3,
              barWidth: 3,
              color: c,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: showDot,
                checkToShowDot: (s, d) => s.x == values.length - 1,
                getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.white,
                  strokeColor: c,
                  strokeWidth: 3,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0)],
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class DonutSlice {
  const DonutSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Donut chart with centre content.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 180,
    this.center,
  });
  final List<DonutSlice> slices;
  final double size;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: size * 0.34,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
              sections: [
                for (final s in slices)
                  PieChartSectionData(
                    value: s.value,
                    color: s.color,
                    radius: size * 0.14,
                    showTitle: false,
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
          ),
          ?center,
        ],
      ),
    );
  }
}

/// Month-over-month spend bars with a planned-budget reference line.
class TrendBars extends StatelessWidget {
  const TrendBars({
    super.key,
    required this.labels,
    required this.values,
    required this.planned,
    this.height = 150,
  });
  final List<String> labels;
  final List<double> values;
  final double planned;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final maxV = [planned, ...values].reduce((a, b) => a > b ? a : b) * 1.15;
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
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[v.toInt()],
                    style: context.tt.labelSmall!.copyWith(
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
                color: c.textTertiary.withValues(alpha: 0.6),
                strokeWidth: 1,
                dashArray: [4, 4],
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
                    width: 22,
                    borderRadius: BorderRadius.circular(8),
                    gradient: i == values.length - 1
                        ? LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [c.accent, c.accentAlt],
                          )
                        : null,
                    color: i == values.length - 1 ? null : c.surfaceElevated,
                    borderSide: i == values.length - 1
                        ? BorderSide.none
                        : BorderSide(color: c.border),
                  ),
                ],
              ),
          ],
        ),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}
