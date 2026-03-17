import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:collection/collection.dart';

class SubjectBarChart extends StatelessWidget {
  final Map<String, SubjectStatsDetailed> subjectStats;
  final double targetPercentage;

  const SubjectBarChart({
    super.key,
    required this.subjectStats,
    required this.targetPercentage,
  });

  String _formatSubjectNameForAxis(
    String fullName, {
    int maxLength = 10,
    int maxWordsForAbbr = 4,
    int abbrMaxLength = 5,
  }) {
    if (fullName.length <= maxLength) return fullName;

    var words = fullName.split(RegExp(r'\s+'));
    if (words.length > 1 && words.length <= maxWordsForAbbr) {
      var abbr = words.map((w) => w.isNotEmpty ? w[0] : '').join('');
      if (abbr.length > 1 &&
          abbr.length < fullName.length / 1.5 &&
          abbr.length <= abbrMaxLength) {
        return abbr.toUpperCase();
      }
    }
    return '${fullName.substring(0, maxLength - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final sortedEntries = subjectStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final Color belowTargetColor = theme.colorScheme.error.withOpacity(0.85);
    final Color aboveTargetColor =
        (isDarkMode ? Colors.green.shade300 : Colors.green.shade600)
            .withOpacity(0.9);
    final Color gridColor = theme.dividerColor.withOpacity(0.3);
    final Color textColor =
        theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;
    final Color targetLineColor = Colors.blueAccent.shade100;
    final Color tooltipText = isDarkMode ? Colors.white : Colors.black87;
    final Color backgroundRodColor = theme.scaffoldBackgroundColor.withOpacity(
      isDarkMode ? 0.6 : 0.8,
    );

    LinearGradient _barGradient(Color baseColor) {
      return LinearGradient(
        colors: [baseColor.withOpacity(0.7), baseColor],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
    }

    final bool angleLabels = sortedEntries.length > 7;

    // ✅ FIX: Calculate the highest percentage so the chart bounds scale dynamically
    double maxPercentage = 105.0; // Default minimum maximum
    for (var entry in sortedEntries) {
      if (entry.value.percentage > maxPercentage) {
        maxPercentage = entry.value.percentage;
      }
    }
    // Add 5% padding to the top so bars don't hit the ceiling
    final double dynamicMaxY = maxPercentage + 5.0;

    return Padding(
      padding: const EdgeInsets.only(
        top: 16.0,
        right: 16.0,
        bottom: 8.0,
        left: 8.0,
      ),
      child: BarChart(
        swapAnimationDuration: const Duration(milliseconds: 500),
        swapAnimationCurve: Curves.easeInOutCubic,
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY:
              dynamicMaxY, // ✅ FIX: Apply dynamic scaling instead of hardcoded 105
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: gridColor, strokeWidth: 0.8),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: angleLabels ? 45 : 35,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < sortedEntries.length) {
                    final name = _formatSubjectNameForAxis(
                      sortedEntries[index].key,
                    );
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      angle: angleLabels ? -0.785 : 0,
                      child: Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  // ✅ Optional tweak: Only show interval lines that end in 0 or 5 for neatness when > 100
                  if (value % 25 == 0) {
                    return Text(
                      '${value.toInt()}%',
                      style: TextStyle(color: textColor, fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          barGroups: sortedEntries.mapIndexed((index, entry) {
            final stats = entry.value;

            // ✅ FIX: Removed the clamp. Allow it to go above 100% naturally.
            final percentage = stats.percentage;

            final color = percentage < targetPercentage
                ? belowTargetColor
                : aboveTargetColor;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: percentage,
                  gradient: _barGradient(color),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    // ✅ FIX: Background rod scales to dynamicMaxY instead of stopping at 100
                    toY: dynamicMaxY,
                    color: backgroundRodColor,
                  ),
                ),
              ],
            );
          }).toList(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: targetPercentage,
                color: targetLineColor,
                strokeWidth: 2,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  padding: const EdgeInsets.only(right: 5, top: 2),
                  style: TextStyle(
                    color: targetLineColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  labelResolver: (line) => 'Target',
                ),
              ),
            ],
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              tooltipMargin: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final subjectName = sortedEntries[group.x.toInt()].key;
                final percentage = rod.toY;
                final statusColor = percentage < targetPercentage
                    ? belowTargetColor
                    : aboveTargetColor;
                return BarTooltipItem(
                  '$subjectName\n',
                  TextStyle(
                    color: tooltipText,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(
                      text: '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
