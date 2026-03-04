import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fs_hub/core/theme/app_theme.dart';

class BurndownChart extends StatelessWidget {
  final List<dynamic> data;
  final bool isDark;

  const BurndownChart({super.key, required this.data, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No task data available for this sprint', style: TextStyle(color: Colors.grey, fontSize: 12))),
      );
    }

    // Prepare spots for Ideal and Actual lines
    List<FlSpot> idealSpots = [];
    List<FlSpot> actualSpots = [];
    double maxX = 0;
    double maxY = 0;

    for (var i = 0; i < data.length; i++) {
      final day = double.parse(data[i]['day'].toString());
      final ideal = double.parse(data[i]['ideal'].toString());
      final actualStr = data[i]['actual'];
      
      idealSpots.add(FlSpot(day, ideal));
      if (actualStr != null) {
        actualSpots.add(FlSpot(day, double.parse(actualStr.toString())));
      }
      
      if (day > maxX) maxX = day;
      if (ideal > maxY) maxY = ideal;
    }

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('Début', style: TextStyle(fontSize: 10, color: Colors.grey));
                  if (value == maxX) return const Text('Fin', style: TextStyle(fontSize: 10, color: Colors.grey));
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}h', style: const TextStyle(fontSize: 10, color: Colors.grey));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY * 1.1,
          lineBarsData: [
            // Ideal Line (Dotted Gray)
            LineChartBarData(
              spots: idealSpots,
              isCurved: false,
              color: Colors.grey.withOpacity(0.3),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              dashArray: [5, 5],
            ),
            // Actual Line (Gold Gradient)
            LineChartBarData(
              spots: actualSpots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppTheme.accentGold,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: AppTheme.accentGold,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.accentGold.withOpacity(0.2),
                    AppTheme.accentGold.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
