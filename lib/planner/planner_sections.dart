import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/planner/planner_input_controller.dart';
import 'package:bunkmate/planner/planner_results_widgets.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/helpers/ad_helper.dart';

class PlannerSections {
  // --- ✨ PREMIUM HELPER: Glowing Section Headers ---
  // Uses Expanded to prevent long titles/subtitles from overflowing
  static Widget _buildSectionHeader({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(isDark ? 0.2 : 0.1),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
            border: Border.all(
              color: color.withOpacity(isDark ? 0.4 : 0.2),
              width: 1,
            ),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- ✨ Helper: Calculate Greatest Common Divisor ---
  static ({int attend, int skip}) safeDisplayRatio(
    int attend,
    int skip, {
    int maxCap = 5,
  }) {
    if (attend <= 0 || skip <= 0) {
      return (attend: attend, skip: skip);
    }

    final double targetDensity = attend / (attend + skip);

    ({int attend, int skip})? best;
    double bestError = double.infinity;

    for (int a = 1; a <= maxCap; a++) {
      for (int s = 1; s <= maxCap; s++) {
        final density = a / (a + s);

        // Must be safe
        if (density < targetDensity) continue;

        final error = (density - targetDensity).abs();

        // Prefer closer match, then smaller cycle
        if (best == null ||
            error < bestError ||
            (error == bestError && (a + s) < (best.attend + best.skip))) {
          best = (attend: a, skip: s);
          bestError = error;
        }
      }
    }

    return best ?? (attend: maxCap, skip: 1);
  }

  // =========================
  // CUSTOM SCENARIO
  // =========================
  static Widget customScenario({
    required BuildContext context,
    required AttendanceProvider provider,
    required ThemeData theme,
    required PlannerInputController inputs,
    required Map<String, dynamic> customCalcResult,
    required InputDecoration Function(
      ThemeData theme, {
      String? label,
      String? hint,
      bool isDropdown,
    })
    inputDecoration,
    required Widget Function(ThemeData theme, String text) resultPlaceholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme: theme,
          icon: Icons.auto_awesome_rounded,
          color: Colors.amber,
          title: 'Custom Scenario',
          subtitle: 'Test how attending future classes affects your buffer.',
        ),
        const SizedBox(height: 24),

        // Premium Input Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What if I attend...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: inputs.customAttend,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v) ?? 0;
                  provider.setPlannerFutureClasses(n);
                },
                decoration: inputDecoration(theme, hint: 'e.g., 10 classes'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          child: (customCalcResult['canCalculate'] == true)
              ? buildCustomCalcResult(context, customCalcResult)
              : (provider.plannerFutureClassesToAttend > 0
                    ? resultPlaceholder(
                        theme,
                        customCalcResult['error'] ?? 'Calculation error.',
                      )
                    : const SizedBox.shrink()),
        ),
      ],
    );
  }

  // =========================
  // ADVANCED WHAT-IF
  // =========================
  static Widget advancedWhatIf({
    required BuildContext context,
    required AttendanceProvider provider,
    required ThemeData theme,
    required PlannerInputController inputs,
    required InputDecoration Function(
      ThemeData theme, {
      String? label,
      String? hint,
      bool isDropdown,
    })
    inputDecoration,
    required ButtonStyle Function(ThemeData theme) elevatedButtonStyle,
  }) {
    final subjectNames = provider.result.subjectStats.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme: theme,
          icon: Icons.science_rounded,
          color: Colors.purpleAccent,
          title: 'Advanced What-If',
          subtitle: 'Simulate specific actions for precise control.',
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: provider.whatIfSelectedSubject,
                hint: const Text('-- Select Subject --'),
                isExpanded: true, // Prevents overflow for long subject names
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                items: subjectNames
                    .map(
                      (name) => DropdownMenuItem(
                        value: name,
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) provider.setWhatIfSubject(value);
                },
                decoration: inputDecoration(theme, label: 'Subject'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: DropdownButtonFormField<String>(
                      value: provider.whatIfAction,
                      isExpanded:
                          true, // Prevents overflow inside the smaller flex box
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: const [
                        DropdownMenuItem(
                          value: 'attend',
                          child: Text(
                            'Attend',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'miss',
                          child: Text(
                            'Miss',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) provider.setWhatIfAction(value);
                      },
                      decoration: inputDecoration(theme, label: 'Action'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: inputs.whatIfClasses,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v) ?? 1;
                        provider.setWhatIfNumClasses(n);
                      },
                      decoration: inputDecoration(theme, label: 'Classes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54, // Taller, premium button
          child: ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Run Simulation',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed:
                provider.isLoading || provider.whatIfSelectedSubject == null
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    provider.runWhatIfSimulation();
                  },
            style: elevatedButtonStyle(theme).copyWith(
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        if (provider.whatIfResult != null) ...[
          const SizedBox(height: 20),
          buildWhatIfResult(context, provider.whatIfResult!),
        ],
      ],
    );
  }

  // =========================
  // PROJECTION
  // =========================
  static Widget projection({
    required BuildContext context,
    required AttendanceProvider provider,
    required ThemeData theme,
    required PlannerInputController inputs,
    required bool projectionPulse,
    required VoidCallback onPulse,
    required InputDecoration Function(
      ThemeData theme, {
      String? label,
      String? hint,
      bool isDropdown,
    })
    inputDecoration,
    required ButtonStyle Function(ThemeData theme) segmentedButtonStyle,
  }) {
    final isWeeksMode = provider.projectionMode == 'weeks';
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme: theme,
          icon: Icons.timeline_rounded,
          color: Colors.blueAccent,
          title: 'Future Projection',
          subtitle: 'See where your attendance will land if nothing changes.',
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'weeks',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Weeks',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      icon: Icon(Icons.calendar_view_week_rounded),
                    ),
                    ButtonSegment(
                      value: 'days',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Days',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      icon: Icon(Icons.calendar_view_day_rounded),
                    ),
                  ],
                  selected: {provider.projectionMode},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    provider.setProjectionMode(s.first);
                    onPulse();
                  },
                  style: segmentedButtonStyle(theme),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputs.remainingTime,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null &&
                            n != provider.projectionRemainingTime) {
                          provider.setProjectionRemainingTime(n);
                          onPulse();
                        }
                      },
                      decoration: inputDecoration(
                        theme,
                        label: isWeeksMode
                            ? 'Remaining Weeks'
                            : 'Remaining Days',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: inputs.classesPerWeek,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v);
                        if (n != null) {
                          provider.setProjectionClassesPerWeek(n);
                          onPulse();
                        }
                      },
                      decoration: inputDecoration(
                        theme,
                        label: 'Classes / Week',
                      ),
                    ),
                  ),
                ],
              ),
              if (!isWeeksMode) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: provider.projectionDaysPerWeek,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: List.generate(6, (i) => 6 - i)
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            '$d day${d > 1 ? 's' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null && v != provider.projectionDaysPerWeek) {
                      provider.setProjectionDaysPerWeek(v);
                      onPulse();
                    }
                  },
                  decoration: inputDecoration(
                    theme,
                    label: 'Class Days / Week',
                    isDropdown: true,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        AnimatedScale(
          scale: projectionPulse ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: Column(
            children: [
              // ✨ FIX: Using Rows with Expanded instead of GridView to absolutely prevent pixel overflow
              Row(
                children: [
                  Expanded(
                    child: buildProjectionStatBox(
                      context,
                      'Remaining Classes',
                      provider.projectionTotalRemainingClasses.toString(),
                      isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      Icons.hourglass_bottom_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildProjectionStatBox(
                      context,
                      'Must Attend',
                      provider.projectionRequiredAttendance.toString(),
                      isDarkMode
                          ? Colors.green.shade300
                          : Colors.green.shade700,
                      Icons.check_circle_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: buildProjectionStatBox(
                      context,
                      'Can Skip',
                      provider.projectionAllowedSkips.toString(),
                      isDarkMode
                          ? Colors.orange.shade300
                          : Colors.orange.shade800,
                      Icons.directions_run_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: buildProjectionStatBox(
                      context,
                      'Projected Final %',
                      '${provider.projectionFinalPercentage.toStringAsFixed(2)}%',
                      provider.projectionFinalPercentage >=
                              provider.targetPercentage
                          ? (isDarkMode
                                ? Colors.green.shade300
                                : Colors.green.shade700)
                          : (isDarkMode
                                ? Colors.red.shade300
                                : Colors.red.shade700),
                      Icons.data_usage_rounded,
                    ),
                  ),
                ],
              ),

              // ✨ FIX: Smart Skip Ratio Advice added directly below the grid
              if (provider.projectionRequiredAttendance > 0 &&
                  provider.projectionAllowedSkips > 0) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (isDarkMode
                                ? Colors.blue.shade300
                                : Colors.blue.shade700)
                            .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color:
                          (isDarkMode
                                  ? Colors.blue.shade300
                                  : Colors.blue.shade700)
                              .withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: isDarkMode
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final int attends =
                                provider.projectionRequiredAttendance;
                            final int skips = provider.projectionAllowedSkips;

                            final ratio = safeDisplayRatio(
                              attends,
                              skips,
                              maxCap: 6,
                            );

                            final int simplifiedAttends = ratio.attend;
                            final int simplifiedSkips = ratio.skip;

                            return Text(
                              'To stay safe, maintain a ratio: Attend $simplifiedAttends class${simplifiedAttends == 1 ? '' : 'es'} then you can skip $simplifiedSkips class${simplifiedSkips == 1 ? '' : 'es'}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDarkMode
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // =========================
  // HOLIDAY PLANNER
  // =========================
  static Widget holidayPlanner({
    required BuildContext context,
    required AttendanceProvider provider,
    required ThemeData theme,
    required PlannerInputController inputs,
    required InputDecoration Function(
      ThemeData theme, {
      String? label,
      String? hint,
      bool isDropdown,
    })
    inputDecoration,
    required ButtonStyle Function(ThemeData theme) elevatedButtonStyle,
  }) {
    final isDaysMode = provider.holidayInputMode == 'days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme: theme,
          icon: Icons.flight_takeoff_rounded,
          color: Colors.tealAccent.shade400, // Pop of teal
          title: 'Holiday Planner',
          subtitle: 'Simulate the impact of upcoming time off.',
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              TextField(
                controller: inputs.holidayAttendBefore,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v) ?? 0;
                  provider.setHolidayAttendBefore(n);
                },
                decoration: inputDecoration(
                  theme,
                  label: 'Classes to Attend Before Leave?',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'days',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Days',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      icon: Icon(Icons.date_range_rounded),
                    ),
                    ButtonSegment(
                      value: 'classes',
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Classes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      icon: Icon(Icons.class_rounded),
                    ),
                  ],
                  selected: {provider.holidayInputMode},
                  onSelectionChanged: (s) {
                    HapticFeedback.selectionClick();
                    provider.setHolidayInputMode(s.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                child: isDaysMode
                    ? TextField(
                        key: const ValueKey('days'),
                        controller: inputs.holidayDays,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 1;
                          provider.setHolidayDays(n);
                        },
                        decoration: inputDecoration(
                          theme,
                          label: 'Days of Leave',
                        ),
                      )
                    : TextField(
                        key: const ValueKey('classes'),
                        controller: inputs.holidayTotalClasses,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) {
                          final n = int.tryParse(v) ?? 1;
                          provider.setHolidayTotalClassesToMiss(n);
                        },
                        decoration: inputDecoration(
                          theme,
                          label: 'Total Classes to Miss',
                        ),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54, // Taller, premium button
          child: ElevatedButton.icon(
            icon: const Icon(Icons.insights_rounded, size: 22),
            label: const Text(
              'Analyze Impact',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            // onPressed: provider.isLoading
            //     ? null
            //     : () {
            //         HapticFeedback.mediumImpact();
            //         FocusScope.of(context).unfocus();
            //         inputs.holidayDays.text = provider.holidayDays.toString();
            //         inputs.holidayTotalClasses.text = provider
            //             .holidayTotalClassesToMiss
            //             .toString();
            //         provider.calculateHolidayImpact();
            //       },
            onPressed: provider.isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    FocusScope.of(context).unfocus();

                    // 1. Define the core calculation logic
                    void executeAnalysis() {
                      inputs.holidayDays.text = provider.holidayDays.toString();
                      inputs.holidayTotalClasses.text = provider
                          .holidayTotalClassesToMiss
                          .toString();
                      provider.calculateHolidayImpact();
                    }

                    // 2. Read the providers
                    final premium = context.read<PremiumProvider>();
                    final adProvider = context.read<AdProvider>();

                    // 3. Check if Premium OR if the 1-hour unlock is active
                    if (premium.isPremium ||
                        adProvider.isHolidayAnalysisUnlocked) {
                      executeAnalysis();
                    } else {
                      // 4. Show the Rewarded Ad Dialog
                      showRewardedAdDialog(
                        context: context,
                        title: 'Unlock Holiday Analysis 🏖️',
                        content:
                            'Watch a quick ad to run this simulation. It will stay completely unlocked for 1 whole hour! 🗿',
                        onReward: () {
                          adProvider.unlockHolidayAnalysisForOneHour();
                          executeAnalysis();
                        },
                      );
                    }
                  },
            style: elevatedButtonStyle(theme).copyWith(
              shape: MaterialStateProperty.all(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        if (provider.holidayImpactResult != null) ...[
          const SizedBox(height: 20),
          buildHolidayResult(context, provider.holidayImpactResult!),
        ],
      ],
    );
  }
}
