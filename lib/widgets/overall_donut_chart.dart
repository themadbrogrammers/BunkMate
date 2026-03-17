import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:bunkmate/providers/attendance_provider.dart';

class OverallDonutChart extends StatelessWidget {
  final CalculationResult result;

  const OverallDonutChart({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Define colors
    final Color presentColor = isDarkMode
        ? Colors.green.shade400
        : Colors.green.shade600;
    final Color odColor = isDarkMode
        ? Colors.orange.shade400
        : Colors.orange.shade600;
    // ✅ ADDED MAKEUP COLOR
    final Color makeupColor = isDarkMode
        ? Colors.purple.shade400
        : Colors.purple.shade600;
    final Color absentColor = isDarkMode
        ? Colors.red.shade400
        : Colors.red.shade600;
    final Color textColor = theme.textTheme.bodyMedium?.color ?? Colors.white;

    // We use totalConducted as the base timeframe.
    // If you prefer the chart to always add up to 100% perfectly,
    // you can change this to: (result.totalPresent + result.totalOD + result.totalMakeup + result.totalAbsent)
    final double totalHours = result.totalConducted;

    if (totalHours <= 0) {
      return const Center(child: Text("No data for chart."));
    }

    // Prepare chart sections
    final List<PieChartSectionData> sections = [];
    if (result.totalPresent > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalPresent,
          title:
              '${(result.totalPresent / totalHours * 100).toStringAsFixed(0)}%',
          color: presentColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (result.totalOD > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalOD,
          title: '${(result.totalOD / totalHours * 100).toStringAsFixed(0)}%',
          color: odColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    // ✅ ADDED MAKEUP SECTION
    if (result.totalMakeup > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalMakeup,
          title:
              '${(result.totalMakeup / totalHours * 100).toStringAsFixed(0)}%',
          color: makeupColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }
    if (result.totalAbsent > 0) {
      sections.add(
        PieChartSectionData(
          value: result.totalAbsent,
          title:
              '${(result.totalAbsent / totalHours * 100).toStringAsFixed(0)}%',
          color: absentColor,
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 50,
              sectionsSpace: 2,
              startDegreeOffset: -90,
            ),
            swapAnimationDuration: const Duration(milliseconds: 250),
            swapAnimationCurve: Curves.linear,
          ),
        ),
        const SizedBox(height: 16),
        // --- Legend ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 16.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: [
              _buildLegendItem(
                color: presentColor,
                text: 'Present (${result.totalPresent.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
              _buildLegendItem(
                color: odColor,
                text: 'OD (${result.totalOD.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
              // ✅ ADDED MAKEUP LEGEND ITEM
              _buildLegendItem(
                color: makeupColor,
                text: 'Makeup (${result.totalMakeup.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
              _buildLegendItem(
                color: absentColor,
                text: 'Absent (${result.totalAbsent.toStringAsFixed(0)} hrs)',
                textColor: textColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String text,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: textColor)),
      ],
    );
  }
}
