// ============================================================================
// graph_widget.dart
// ============================================================================

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../models/data_point.dart';

// ============================================================================
// GRAPH WIDGET
// ============================================================================
// Strip chart: newest sample ALWAYS at the right edge (x = window).
// History scrolls left; points leave only when they reach the left edge.
// ============================================================================

class GraphWidget extends StatelessWidget {
  final List<DataPoint> temperatureData;
  final List<DataPoint> pressureData;
  final double currentTime;

  const GraphWidget({
    super.key,
    required this.temperatureData,
    required this.pressureData,
    required this.currentTime,
  });

  static const double _windowSize = 40.0;
  /// Fixed strip vertical grid (seconds of age between lines).
  static const double _verticalGridSec = 2.5;
  /// Same reserved gutter for left (pressure) and right (temperature) titles.
  static const double _yAxisReserved = 44.0;
  /// Gap between title text and plot area — identical on both sides.
  static const double _yAxisTitleSpace = 8.0;

  /// Session time of the left edge (may be negative before window is full).
  double get _leftTime => currentTime - _windowSize;

  /// Map session points so [currentTime] sits at x = [_windowSize] (right edge).
  List<FlSpot> _spots(List<DataPoint> data, double Function(double) yMap) {
    if (data.isEmpty || currentTime <= 0) return const [];

    final left = _leftTime;
    final spots = <FlSpot>[];
    double? lastX;

    for (final p in data) {
      // Drop samples older than the visible window
      if (p.time < left) continue;
      // x: 0 = left edge, windowSize = now (right edge)
      final x = (p.time - left).clamp(0.0, _windowSize);
      final y = yMap(p.value);
      if (y.isNaN || y.isInfinite) continue;

      // fl_chart needs strictly increasing x for a continuous stroke
      if (lastX != null && x <= lastX) {
        final nudged = lastX + 0.001;
        if (nudged > _windowSize) continue;
        spots.add(FlSpot(nudged, y));
        lastX = nudged;
      } else {
        spots.add(FlSpot(x, y));
        lastX = x;
      }
    }

    // ≥2 spots required to stroke a line (dots are off)
    if (spots.length == 1) {
      final s = spots.first;
      if (s.x > 0) {
        spots.insert(0, FlSpot((s.x - 0.05).clamp(0.0, _windowSize), s.y));
      } else {
        spots.add(FlSpot((s.x + 0.05).clamp(0.0, _windowSize), s.y));
      }
    }
    return spots;
  }

  LineChartBarData _solidLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      dashArray: null,
      belowBarData: BarAreaData(show: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pressureSpots = _spots(pressureData, (v) => v);
    final tempSpots = _spots(temperatureData, (v) => v / 10.0);
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return LineChart(
      LineChartData(
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          // x is age-offset along the strip; 2.5 units = 2.5 s
          verticalInterval: _verticalGridSec,
          drawHorizontalLine: true,
        ),
        borderData: FlBorderData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _yAxisReserved,
              getTitlesWidget: (value, meta) {
                // Hide padded floor label (-1.0); axis range itself stays minY=-1
                if ((value + 1.0).abs() < 0.05) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: _yAxisTitleSpace,
                  child: Text(
                    value.toStringAsFixed(1),
                    style: labelStyle,
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              // Match left gutter so plot↔title gap is the same on both sides
              reservedSize: _yAxisReserved,
              getTitlesWidget: (value, meta) {
                final t = (value * 10).round();
                // Hide padded floor label (-10 °C scale); same floor as left -1.0
                if (t == -10) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: _yAxisTitleSpace,
                  child: Text(
                    t.toString(),
                    style: labelStyle?.copyWith(color: Colors.red),
                    textAlign: TextAlign.left,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              // Fixed strip labels: right edge = 0 s (now), growing leftward (age).
              // Never changes with session time. Marks every 5 s.
              interval: 5,
              getTitlesWidget: (value, meta) {
                // x: 0 = left (oldest), windowSize = right (now)
                final ageSec = (_windowSize - value).round();
                if (ageSec < 0 || ageSec > _windowSize.round()) {
                  return const SizedBox.shrink();
                }
                // 0, 5, 10, …, 40
                if (ageSec % 5 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    '$ageSec',
                    style: labelStyle,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        minX: 0,
        maxX: _windowSize,
        minY: -1,
        maxY: 15,
        lineBarsData: [
          if (pressureSpots.isNotEmpty) _solidLine(pressureSpots, Colors.blue),
          if (tempSpots.isNotEmpty) _solidLine(tempSpots, Colors.red),
        ],
        lineTouchData: const LineTouchData(enabled: false),
      ),
      duration: Duration.zero,
    );
  }
}
