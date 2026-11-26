import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/theme.dart';
import '../theme/tokens.dart';
import '../utils/money.dart';
import 'haptics.dart';
import 'rows.dart';

/// One named series in an inspectable chart.
class ChartSeries {
  const ChartSeries(this.name, this.values, this.color, {this.dashed = false});
  final String name;
  final List<double> values;
  final Color color;
  final bool dashed;
}

/// The figures for the selected point, above the chart. Replaces tooltips:
/// nothing floats over the data, and the numbers stay readable.
class ChartReadout extends StatelessWidget {
  const ChartReadout({super.key, required this.label, required this.items});
  final String label;
  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.tt.labelMedium),
          const SizedBox(height: Space.xs),
          Wrap(
            spacing: Space.lg,
            runSpacing: Space.xs,
            children: [
              for (final (name, value, color) in items)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Dot(color, size: 7),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.tt.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      value,
                      style: PulseTheme.amount(c.textPrimary, size: 13),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _bottomLabel(
  BuildContext context,
  List<String> labels,
  int? selected,
  double value,
  TitleMeta meta,
) {
  final i = value.round();
  if (i < 0 || i >= labels.length || value != i.toDouble()) {
    return const SizedBox.shrink();
  }
  final c = context.pc;
  return SideTitleWidget(
    meta: meta,
    space: 6,
    child: Text(
      labels[i],
      style: context.tt.labelSmall!.copyWith(
        color: i == selected ? c.textPrimary : c.textTertiary,
        fontWeight: i == selected ? FontWeight.w600 : FontWeight.w500,
      ),
    ),
  );
}

/// Grouped bars, one group per period. Tap a group to read its numbers.
class GroupedBarChart extends StatefulWidget {
  const GroupedBarChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 150,
    this.format,
    this.title,
    this.extra,
  });
  final List<String> labels;
  final List<ChartSeries> series;
  final double height;
  final String Function(double)? format;

  /// Readout heading for an index; defaults to the label.
  final String Function(int)? title;

  /// Further readout figures for an index, after the series.
  final List<(String, String, Color)> Function(int)? extra;

  @override
  State<GroupedBarChart> createState() => _GroupedBarChartState();
}

class _GroupedBarChartState extends State<GroupedBarChart> {
  late int _selected = widget.labels.length - 1;

  @override
  void didUpdateWidget(GroupedBarChart old) {
    super.didUpdateWidget(old);
    if (_selected >= widget.labels.length) _selected = widget.labels.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final fmt = widget.format ?? (v) => Money.aed(v, decimals: false);
    final n = widget.labels.length;
    if (n == 0) return SizedBox(height: widget.height);
    var maxY = 0.0;
    for (final s in widget.series) {
      for (final v in s.values) {
        if (v > maxY) maxY = v;
      }
    }
    final rodWidth = (widget.series.length > 1 ? 9 : 16).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartReadout(
          label: widget.title?.call(_selected) ?? widget.labels[_selected],
          items: [
            for (final s in widget.series)
              (s.name, fmt(s.values[_selected]), s.color),
            ...?widget.extra?.call(_selected),
          ],
        ),
        SizedBox(
          height: widget.height,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.08,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY == 0 ? 1 : maxY / 2,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: c.border, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    getTitlesWidget: (v, m) =>
                        _bottomLabel(context, widget.labels, _selected, v, m),
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                enabled: true,
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  final i = response?.spot?.touchedBarGroupIndex;
                  if (i == null || !event.isInterestedForInteractions) return;
                  if (i != _selected) {
                    Haptics.tap();
                    setState(() => _selected = i);
                  }
                },
              ),
              barGroups: [
                for (var i = 0; i < n; i++)
                  BarChartGroupData(
                    x: i,
                    barsSpace: 3,
                    barRods: [
                      for (final s in widget.series)
                        BarChartRodData(
                          toY: s.values[i] < 0 ? 0 : s.values[i],
                          width: rodWidth,
                          color: i == _selected
                              ? s.color
                              : s.color.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            duration: Motion.base,
            curve: Motion.curve,
          ),
        ),
      ],
    );
  }
}

/// Lines over periods. Tap or drag to read a period.
class InspectLineChart extends StatefulWidget {
  const InspectLineChart({
    super.key,
    required this.labels,
    required this.series,
    this.height = 150,
    this.format,
    this.fill = false,
    this.title,
  });
  final List<String> labels;
  final List<ChartSeries> series;
  final double height;
  final String Function(double)? format;
  final bool fill;
  final String Function(int)? title;

  @override
  State<InspectLineChart> createState() => _InspectLineChartState();
}

class _InspectLineChartState extends State<InspectLineChart> {
  late int _selected = widget.labels.length - 1;

  @override
  void didUpdateWidget(InspectLineChart old) {
    super.didUpdateWidget(old);
    if (_selected >= widget.labels.length) _selected = widget.labels.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.pc;
    final fmt = widget.format ?? (v) => Money.aed(v, decimals: false);
    final n = widget.labels.length;
    if (n < 2) return SizedBox(height: widget.height);
    var minY = double.infinity, maxY = -double.infinity;
    for (final s in widget.series) {
      for (final v in s.values) {
        if (v < minY) minY = v;
        if (v > maxY) maxY = v;
      }
    }
    final pad = (maxY - minY) * 0.12 + 1;
    final lo = widget.fill
        ? minY - pad * 3
        : (minY - pad).clamp(0.0, double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChartReadout(
          label: widget.title?.call(_selected) ?? widget.labels[_selected],
          items: [
            for (final s in widget.series)
              (s.name, fmt(s.values[_selected]), s.color),
          ],
        ),
        SizedBox(
          height: widget.height,
          child: LineChart(
            LineChartData(
              minY: lo.toDouble(),
              maxY: maxY + pad,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: ((maxY + pad - lo) / 2).clamp(
                  1,
                  double.infinity,
                ),
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: c.border, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: _selected.toDouble(),
                    color: c.textTertiary.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [3, 3],
                  ),
                ],
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: const AxisTitles(),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 24,
                    getTitlesWidget: (v, m) =>
                        _bottomLabel(context, widget.labels, _selected, v, m),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                enabled: true,
                handleBuiltInTouches: false,
                touchSpotThreshold: 400,
                touchCallback: (event, response) {
                  final spots = response?.lineBarSpots;
                  if (spots == null ||
                      spots.isEmpty ||
                      !event.isInterestedForInteractions) {
                    return;
                  }
                  final i = spots.first.x.round();
                  if (i != _selected) {
                    Haptics.tap();
                    setState(() => _selected = i);
                  }
                },
              ),
              lineBarsData: [
                for (final s in widget.series)
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < s.values.length; i++)
                        FlSpot(i.toDouble(), s.values[i]),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.2,
                    preventCurveOverShooting: true,
                    barWidth: 2,
                    color: s.color,
                    dashArray: s.dashed ? [4, 4] : null,
                    isStrokeCapRound: true,
                    belowBarData: BarAreaData(
                      show: widget.fill && !s.dashed,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          s.color.withValues(alpha: 0.16),
                          s.color.withValues(alpha: 0),
                        ],
                      ),
                    ),
                    dotData: FlDotData(
                      show: !s.dashed,
                      checkToShowDot: (spot, _) => spot.x.round() == _selected,
                      getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                        radius: 3.5,
                        color: s.color,
                        strokeWidth: 2,
                        strokeColor: c.isDark ? c.bg : c.surface,
                      ),
                    ),
                  ),
              ],
            ),
            duration: Motion.base,
            curve: Motion.curve,
          ),
        ),
      ],
    );
  }
}
