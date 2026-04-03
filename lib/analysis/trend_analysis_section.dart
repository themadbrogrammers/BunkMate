import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/helpers/ad_helper.dart';

class TrendAnalysisSection extends StatelessWidget {
  const TrendAnalysisSection({super.key});

  void _showRewardedAdDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onReward,
  }) {
    FocusScope.of(context).requestFocus(FocusNode());
    showRewardedAdDialog(
      context: context,
      title: title,
      content: content,
      onReward: onReward,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();
    final premium = context.watch<PremiumProvider>();
    final adProvider = context.watch<AdProvider>();
    final theme = Theme.of(context);

    final canShowTrend = provider.result.subjectStats.values.any(
      (s) => s.absences.isNotEmpty,
    );

    // ✨ Determine the lock state before building the UI!
    final bool isLocked =
        canShowTrend &&
        !premium.isPremium &&
        !adProvider.isAbsenceTrendUnlocked;

    return _buildTrendAnalysisSection(
      context,
      provider,
      theme,
      canShowTrend,
      premium.isPremium,
      isLocked,
    );
  }

  Widget _buildTrendInsightItem(
    ThemeData theme,
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 16,
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  // --- Helper: Trend Analysis Section ---
  Widget _buildTrendAnalysisSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    bool canShowTrend,
    bool isPremium,
    bool isLocked,
  ) {
    String? trendInsight;
    IconData? trendInsightIcon;

    Widget insightsWidget = const SizedBox.shrink();
    Widget dayOfWeekChartWidget = const SizedBox.shrink();
    Widget theActualMonthlyChart = const SizedBox.shrink();

    final isLightMode = theme.brightness == Brightness.light;
    final primaryColor = theme.colorScheme.primary;
    final errorColor = theme.colorScheme.error;

    final List<Color> dayChartColors = isLightMode
        ? [
            Colors.blue.shade500,
            Colors.cyan.shade600,
            Colors.teal.shade500,
            Colors.green.shade500,
            Colors.lightGreen.shade600,
            Colors.lime.shade600,
            Colors.orange.shade500,
          ]
        : [
            Colors.blue.shade300,
            Colors.cyan.shade300,
            Colors.teal.shade300,
            Colors.green.shade300,
            Colors.lightGreen.shade300,
            Colors.lime.shade300,
            Colors.amber.shade300,
          ];

    List<AbsenceRecord> allAbsences = [];
    Map<String, double> monthlyAbsences = {};
    List<MapEntry<String, double>> sortedMonthlyEntries = [];

    if (canShowTrend) {
      allAbsences =
          provider.result.subjectStats.values.expand((s) => s.absences).toList()
            ..sort((a, b) => a.date.compareTo(b.date));

      if (allAbsences.isNotEmpty) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
        final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

        int absencesToday = allAbsences
            .where((a) => !a.date.isBefore(todayStart))
            .length;
        int absencesYesterday = allAbsences
            .where(
              (a) =>
                  !a.date.isBefore(yesterdayStart) &&
                  a.date.isBefore(todayStart),
            )
            .length;
        int absencesLast7Days = allAbsences
            .where((a) => a.date.isAfter(sevenDaysAgo))
            .length;
        int absencesLast30Days = allAbsences
            .where((a) => a.date.isAfter(thirtyDaysAgo))
            .length;

        Map<int, int> dayCounts = {};
        for (var a in allAbsences) {
          dayCounts[a.date.weekday] = (dayCounts[a.date.weekday] ?? 0) + 1;
        }

        var sortedDays = dayCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        String mostMissedDay = sortedDays.isNotEmpty
            ? DateFormat(
                'EEEE',
              ).format(DateTime(2023, 1, sortedDays.first.key + 1))
            : "N/A";

        int longestStreak = 0;
        int currentStreak = 0;
        DateTime? lastDate;

        for (final a in allAbsences) {
          final currentDate = DateUtils.dateOnly(a.date);
          if (lastDate != null &&
              currentDate.difference(lastDate).inDays == 1) {
            currentStreak++;
          } else {
            currentStreak = 1;
          }
          longestStreak = max(longestStreak, currentStreak);
          lastDate = currentDate;
        }

        String avgTimeBetween = "N/A";
        if (allAbsences.length > 1) {
          Duration totalTimeBetween = Duration.zero;
          for (int i = 1; i < allAbsences.length; i++) {
            if (!DateUtils.isSameDay(
              allAbsences[i].date,
              allAbsences[i - 1].date,
            )) {
              totalTimeBetween += allAbsences[i].date.difference(
                allAbsences[i - 1].date,
              );
            }
          }
          int numGaps =
              allAbsences
                  .map((a) => DateUtils.dateOnly(a.date))
                  .toSet()
                  .length -
              1;
          if (numGaps > 0) {
            double avgDays = totalTimeBetween.inDays / numGaps;
            avgTimeBetween = "${avgDays.toStringAsFixed(1)} days";
          }
        }

        if (dayCounts.isNotEmpty && allAbsences.length >= 5) {
          final totalAbsences = dayCounts.values.sum;
          final topDayEntry = dayCounts.entries.reduce(
            (a, b) => a.value > b.value ? a : b,
          );
          final double ratio = topDayEntry.value / totalAbsences;

          if (ratio >= 0.4) {
            final dayName = DateFormat(
              'EEEE',
            ).format(DateTime(2023, 1, topDayEntry.key + 1));
            trendInsight =
                'Absences cluster on $dayName (${(ratio * 100).toStringAsFixed(0)}%).';
            trendInsightIcon = Icons.insights_rounded;
          }
        }

        if (trendInsight == null &&
            absencesLast30Days >= 5 &&
            absencesLast7Days / absencesLast30Days >= 0.4) {
          trendInsight =
              'Absences have spiked recently (${absencesLast7Days} in the last 7 days).';
          trendInsightIcon = Icons.trending_up_rounded;
        }

        // ✨ TEASE DATA FOR LOCKED USERS
        if (isLocked) {
          mostMissedDay = "•••";
          avgTimeBetween = "•••";
          longestStreak = max(
            longestStreak,
            3,
          ); // Force it to show the danger streak
          trendInsight = "Hidden patterns detected in your attendance.";
          trendInsightIcon = Icons.lock_outline_rounded;
        }

        insightsWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildRecencyInsight(
                          theme,
                          "Today",
                          isLocked ? "?" : absencesToday.toString(),
                          errorColor,
                          isLocked ? true : absencesToday > 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRecencyInsight(
                          theme,
                          "Yesterday",
                          isLocked ? "?" : absencesYesterday.toString(),
                          errorColor.withOpacity(0.8),
                          isLocked ? true : absencesYesterday > 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildRecencyInsight(
                          theme,
                          "7 Days",
                          isLocked ? "?" : absencesLast7Days.toString(),
                          primaryColor,
                          isLocked ? true : absencesLast7Days > 0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildRecencyInsight(
                          theme,
                          "30 Days",
                          isLocked ? "?" : absencesLast30Days.toString(),
                          Colors.purpleAccent,
                          isLocked ? true : absencesLast30Days > 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Column(
              children: [
                _buildTrendInsightItem(
                  theme,
                  Icons.calendar_today_rounded,
                  "Peak Absence Day",
                  mostMissedDay,
                  Colors.orangeAccent,
                ),
                _buildTrendInsightItem(
                  theme,
                  Icons.timer_rounded,
                  "Absence Frequency",
                  avgTimeBetween,
                  Colors.blueAccent,
                ),
                if (longestStreak > 1)
                  _buildTrendInsightItem(
                    theme,
                    Icons.local_fire_department_rounded,
                    "Danger Streak",
                    isLocked ? "••• Days" : "$longestStreak Days",
                    errorColor,
                  ),
              ],
            ),
          ],
        );

        Map<int, double> dayOfWeekHours = {
          1: 0,
          2: 0,
          3: 0,
          4: 0,
          5: 0,
          6: 0,
          7: 0,
        };

        // ✨ THE CHART TEASE: Inject gorgeous dummy data if locked
        if (isLocked) {
          dayOfWeekHours = {
            1: 1.5,
            2: 5.0,
            3: 2.0,
            4: 4.5,
            5: 1.0,
            6: 0.0,
            7: 0.0,
          };
        } else {
          for (var absence in allAbsences) {
            dayOfWeekHours[absence.date.weekday] =
                (dayOfWeekHours[absence.date.weekday] ?? 0) + absence.hours;
          }
        }

        final maxDayHours = dayOfWeekHours.values.isEmpty
            ? 1.0
            : dayOfWeekHours.values.reduce(max);
        final maxYLimit = (maxDayHours * 1.2).ceilToDouble().clamp(
          5.0,
          double.infinity,
        );
        final intervalDayY = (maxYLimit / 4).clamp(
          1.0,
          maxYLimit > 0 ? maxYLimit : 1.0,
        );

        dayOfWeekChartWidget = SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxYLimit,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: intervalDayY,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: theme.hintColor.withOpacity(0.15),
                  strokeWidth: 1.5,
                  dashArray: [6, 6],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: intervalDayY,
                    getTitlesWidget: (v, m) {
                      if (v == 0) return const SizedBox.shrink();
                      return Text(
                        '${v.toInt()}h',
                        style: TextStyle(
                          color: theme.hintColor.withOpacity(0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      const days = [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ];
                      final index = value.toInt();
                      if (index >= 0 && index < days.length) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 8,
                          child: Text(
                            days[index],
                            style: TextStyle(
                              color: theme.hintColor.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              barGroups: dayOfWeekHours.entries.mapIndexed((index, entry) {
                final dayIndex = entry.key - 1;
                final hours = entry.value;
                final baseColor =
                    dayChartColors[dayIndex % dayChartColors.length];

                return BarChartGroupData(
                  x: dayIndex,
                  barRods: [
                    BarChartRodData(
                      toY: hours,
                      gradient: LinearGradient(
                        colors: [
                          baseColor,
                          baseColor.withOpacity(isLightMode ? 0.6 : 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: maxYLimit,
                        color: theme.dividerColor.withOpacity(0.06),
                      ),
                    ),
                  ],
                );
              }).toList(),
              // ✨ FIX: Light mode contrast fix for BarChart tooltips
              barTouchData: BarTouchData(
                enabled: !isLocked,
                handleBuiltInTouches: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => isLightMode
                      ? Colors.black87
                      : theme.colorScheme.surface.withOpacity(0.95),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  tooltipMargin: 8,
                  tooltipRoundedRadius: 12,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    const days = [
                      'Monday',
                      'Tuesday',
                      'Wednesday',
                      'Thursday',
                      'Friday',
                      'Saturday',
                      'Sunday',
                    ];
                    final dayName = days[group.x.toInt()];
                    final hours = rod.toY;
                    final color =
                        dayChartColors[group.x.toInt() % dayChartColors.length];

                    return BarTooltipItem(
                      '$dayName\n',
                      TextStyle(
                        color: isLightMode ? Colors.white70 : theme.hintColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        TextSpan(
                          text: '${hours.toStringAsFixed(1)} hrs',
                          style: TextStyle(
                            color: isLightMode ? Colors.white : color,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            swapAnimationDuration: const Duration(milliseconds: 800),
            swapAnimationCurve: Curves.easeOutQuint,
          ),
        );

        if (isLocked) {
          // ✨ Dummy Trajectory Data
          sortedMonthlyEntries = [
            const MapEntry("2026-01", 3.0),
            const MapEntry("2026-02", 9.0),
            const MapEntry("2026-03", 5.0),
          ];
          monthlyAbsences = Map.fromEntries(sortedMonthlyEntries);
        } else {
          var groupedByMonth = groupBy(
            allAbsences,
            (AbsenceRecord r) => DateFormat('yyyy-MM').format(r.date),
          );
          groupedByMonth.forEach((month, records) {
            monthlyAbsences[month] = records.map((r) => r.hours).sum;
          });
          sortedMonthlyEntries = monthlyAbsences.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));
        }

        if (monthlyAbsences.length >= 2 || isLocked) {
          final spots = sortedMonthlyEntries
              .mapIndexed((i, e) => FlSpot(i.toDouble(), e.value))
              .toList();
          final rawMaxY = monthlyAbsences.isEmpty
              ? 10.0
              : monthlyAbsences.values.reduce(max);
          final maxYLimit2 = (rawMaxY * 1.3).ceilToDouble().clamp(
            5.0,
            double.infinity,
          );
          final intervalY = (maxYLimit2 / 4).clamp(
            1.0,
            maxYLimit2 > 0 ? maxYLimit2 : 1.0,
          );

          theActualMonthlyChart = SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: intervalY,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: theme.hintColor.withOpacity(0.15),
                    strokeWidth: 1.5,
                    dashArray: [6, 6],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < monthlyAbsences.keys.length) {
                          final monthYear = sortedMonthlyEntries[index].key;
                          final monthAbbr = DateFormat(
                            'MMM',
                          ).format(DateFormat('yyyy-MM').parse(monthYear));
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              monthAbbr,
                              style: TextStyle(
                                color: theme.hintColor.withOpacity(0.9),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: intervalY,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            '${value.toInt()}h',
                            style: TextStyle(
                              color: theme.hintColor.withOpacity(0.7),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (monthlyAbsences.length - 1).toDouble().clamp(
                  0.0,
                  double.infinity,
                ),
                minY: 0,
                maxY: maxYLimit2,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [primaryColor, Colors.purpleAccent],
                    ),
                    barWidth: 4.5,
                    isStrokeCapRound: true,
                    shadow: Shadow(
                      color: Colors.purpleAccent.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: theme.colorScheme.surface,
                          strokeWidth: 2.5,
                          strokeColor: primaryColor,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primaryColor.withOpacity(0.45),
                          Colors.purpleAccent.withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
                // ✨ FIX: Light mode contrast fix for LineChart tooltips
                lineTouchData: LineTouchData(
                  enabled: !isLocked,
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator: (barData, spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: primaryColor.withOpacity(0.6),
                          strokeWidth: 2,
                          dashArray: [4, 4],
                        ),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) =>
                              FlDotCirclePainter(
                                radius: 6,
                                color: primaryColor,
                                strokeWidth: 3,
                                strokeColor: theme.colorScheme.surface,
                              ),
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => isLightMode
                        ? Colors.black87
                        : theme.colorScheme.surface.withOpacity(0.95),
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    tooltipMargin: 12,
                    tooltipRoundedRadius: 12,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((spot) {
                            final index = spot.x.toInt();
                            if (index < 0 ||
                                index >= monthlyAbsences.keys.length)
                              return null;
                            final monthYear = sortedMonthlyEntries[index].key;
                            final formattedMonth = DateFormat(
                              'MMM yyyy',
                            ).format(DateFormat('yyyy-MM').parse(monthYear));
                            final hours = spot.y;
                            return LineTooltipItem(
                              '$formattedMonth\n',
                              TextStyle(
                                color: isLightMode
                                    ? Colors.white70
                                    : theme.hintColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: '${hours.toStringAsFixed(1)} hrs',
                                  style: TextStyle(
                                    color: isLightMode
                                        ? Colors.white
                                        : primaryColor,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            );
                          })
                          .whereNotNull()
                          .toList();
                    },
                  ),
                ),
              ),
              duration: Duration(milliseconds: 800),
              curve: Curves.easeOutQuint,
            ),
          );
        } else {
          theActualMonthlyChart = SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 36,
                    color: theme.hintColor.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Need at least 2 months of data\nfor a trend chart.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.hintColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      } else {
        insightsWidget = const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10.0),
            child: Text(
              "No absences recorded in the data.",
              style: TextStyle(fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
        );
        theActualMonthlyChart = const SizedBox(height: 10);
        dayOfWeekChartWidget = const SizedBox.shrink();
      }
    } else {
      insightsWidget = Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_chart_outlined,
                size: 42,
                color: theme.hintColor.withOpacity(0.6),
              ),
              const SizedBox(height: 14),
              Text(
                'Absence trends unavailable',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  'Detailed trends need raw attendance logs\nwith dates (not aggregated).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
      theActualMonthlyChart = const SizedBox(height: 10);
      dayOfWeekChartWidget = const SizedBox.shrink();
    }

    Widget trendContent = _buildSectionCard(
      context: context,
      title: canShowTrend ? '🔍 Absence Trend' : '🔍 Absence Insights',
      padding: EdgeInsets.zero,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 0,
              ),
              child: insightsWidget,
            ),
            if (trendInsight != null && !isLocked)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      trendInsightIcon,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        trendInsight!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (canShowTrend && allAbsences.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildModernHeader(theme, "📅 Weekly Distribution"),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 24, 24),
                child: dayOfWeekChartWidget,
              ),
              _buildModernHeader(theme, "📈 Monthly Trajectory"),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 24, 24),
                child: theActualMonthlyChart,
              ),
            ],
          ],
        ),
      ),
    );

    // ✨ THE FLAWLESS, JITTER-FREE OVERLAY & PROPERLY CENTERED CTA
    if (isLocked) {
      return Stack(
        alignment: Alignment.center,
        children: [
          AbsorbPointer(child: trendContent),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    theme.scaffoldBackgroundColor.withOpacity(0.0),
                    theme.scaffoldBackgroundColor.withOpacity(0.85),
                    theme.scaffoldBackgroundColor.withOpacity(1.0),
                  ],
                  stops: const [0.35, 0.7, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: UnlockTrendCTA(
                onPressed: () {
                  _showRewardedAdDialog(
                    context: context,
                    title: 'Your Personal Absence Insights',
                    content:
                        'Unlock absence trends and patterns from your attendance history for whole an hour.😎',
                    onReward: () {
                      context.read<AdProvider>().unlockAbsenceTrendForOneHour();
                    },
                  );
                },
              ),
            ),
          ),
        ],
      );
    }

    return trendContent;
  }

  Widget _buildModernHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
          color: theme.hintColor.withOpacity(0.7),
        ),
      ),
    );
  }

  Widget _buildRecencyInsight(
    ThemeData theme,
    String label,
    String value,
    Color baseColor,
    bool hasAbsences,
  ) {
    final Color color = hasAbsences
        ? baseColor
        : theme.hintColor.withOpacity(0.5);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required Widget child,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(16.0),
    Gradient? gradient,
  }) {
    final theme = Theme.of(context);
    return CustomCard(
      padding: EdgeInsets.zero,
      gradient: gradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              left: 16.0,
              right: 16.0,
              bottom: 8.0,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5),
          if (padding != null)
            Padding(padding: padding, child: child)
          else
            child,
        ],
      ),
    );
  }
}

class UnlockTrendCTA extends StatefulWidget {
  final VoidCallback onPressed;
  const UnlockTrendCTA({super.key, required this.onPressed});

  @override
  State<UnlockTrendCTA> createState() => _UnlockTrendCTAState();
}

class _UnlockTrendCTAState extends State<UnlockTrendCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final glow = 0.6 + (_controller.value * 0.4);

        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(glow * 0.6),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: widget.onPressed,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withOpacity(0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_graph_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reveal Your Absence Pattern',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Watch an ad • Or unlock Pro 👑',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
