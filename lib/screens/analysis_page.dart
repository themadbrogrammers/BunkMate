import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:collection/collection.dart';

import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart'; // ✨ REQUIRED
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/widgets/subject_bar_chart.dart';
import 'package:bunkmate/widgets/overall_donut_chart.dart';
import 'package:bunkmate/widgets/native_ad_card.dart';
import 'package:bunkmate/mixins/scroll_to_top_mixin.dart';
import 'package:bunkmate/widgets/banner_ad_widget.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/analysis/trend_analysis_section.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => AnalysisPageState();
}

class AnalysisPageState extends State<AnalysisPage> with ScrollToTopMixin {
  bool _showSubjectTable = false;
  bool _advisorPulse = false;
  String? _lastResultSignature;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AttendanceProvider, PremiumProvider>(
      // ✨ Watch both!
      builder: (context, provider, premium, child) {
        final isPremium = premium.isPremium; // ✨ Grab premium status
        final results = provider.result;
        final String resultSignature =
            '${results.currentPercentage}-${results.requiredToAttend}-${results.maxDroppableHours}';

        if (_lastResultSignature != resultSignature) {
          _advisorPulse = false;
          _lastResultSignature = resultSignature;
        }

        final bool hasData =
            results.dataParsedSuccessfully && results.subjectStats.isNotEmpty;
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '📈 Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                // ✨ VIP PRO BADGE IN APP BAR
                if (isPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        // ✨ NEON PURPLE GRADIENT
                        colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurpleAccent.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors
                            .white, // ✨ White text looks way better on purple
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
            foregroundColor: theme.textTheme.titleLarge?.color,
            automaticallyImplyLeading: false,
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasData
                    ? _buildAnalysisContent(
                        context,
                        provider,
                        theme,
                        isPremium,
                      ) // Pass isPremium down
                    : _buildPlaceholder(context, theme, provider.errorMessage),
              ),
              // ✨ STRICT AD CHECK: Only show if NOT premium!
              if (!isPremium)
                SafeArea(
                  top: false,
                  child: isPremium
                      ? const SizedBox.shrink()
                      : BannerAdWidget(
                          adUnitId: AdService.instance.analysisBannerAdUnitId,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder(
    BuildContext context,
    ThemeData theme,
    String? errorMessage,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final bool isError = errorMessage != null && errorMessage.isNotEmpty;

    // Define dynamic content based on state
    final String title = isError ? 'Analysis Unavailable' : 'Awaiting Data';
    final String message = isError
        ? 'Error: $errorMessage\nPlease check your data format on the Home page.'
        : 'Go to the Home page, input your data, and calculate first to unlock your detailed analysis!';
    final IconData icon = isError
        ? Icons.error_outline_rounded
        : Icons.analytics_rounded;

    // Define glowing colors based on theme and state
    final Color baseColor = isError
        ? Colors.redAccent
        : (isDark ? Colors.cyanAccent : Colors.blueAccent);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✨ PREMIUM TOUCH: Glowing Icon Badge
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(isDark ? 0.2 : 0.15),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(icon, size: 64, color: baseColor),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: isError ? baseColor : null, // Tint title if error
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Subtitle
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Analysis Content ---
  Widget _buildAnalysisContent(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    bool isPremium,
  ) {
    final sortedSubjects = provider.result.subjectStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16.0,
        8.0,
        16.0,
        isPremium ? MediaQuery.of(context).padding.bottom + 25.0 : 32.0,
      ),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- 1. Smart Advisor (Now looks incredible) ---
          _buildSmartAdvisorSection(context, provider, theme),
          const SizedBox(height: 24),

          // --- 2. Trend Analysis ---
          const TrendAnalysisSection(),
          const SizedBox(height: 24),

          // ✨ STRICT NATIVE AD CHECK: Only show if NOT premium!
          if (!isPremium) ...[const NativeAdCard(), const SizedBox(height: 24)],

          // --- 3. Subject Breakdown ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '📚 Subject Breakdown',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.dividerColor.withOpacity(0.1),
                  ),
                ),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.grid_view_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.table_rows_rounded, size: 18),
                    ),
                  ],
                  selected: {_showSubjectTable},
                  onSelectionChanged: (val) =>
                      setState(() => _showSubjectTable = val.first),
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  showSelectedIcon: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          AnimatedCrossFade(
            firstChild: _buildSubjectList(
              context,
              provider,
              theme,
              sortedSubjects,
            ),
            secondChild: _buildSubjectDataTable(
              context,
              provider,
              theme,
              sortedSubjects,
            ),
            crossFadeState: _showSubjectTable
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 24),

          // --- 4. Comparison Chart ---
          _buildSectionCard(
            context: context,
            title: '📊 Comparison Chart',
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.05),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: SizedBox(
              height: (sortedSubjects.length * 35.0 + 60).clamp(160.0, 350.0),
              child: SubjectBarChart(
                subjectStats: provider.result.subjectStats,
                targetPercentage: provider.targetPercentage.toDouble(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- 5. Overall Donut Chart ---
          _buildSectionCard(
            context: context,
            title: '🍩 Overall Breakdown',
            padding: const EdgeInsets.symmetric(vertical: 20.0),
            child: OverallDonutChart(result: provider.result),
          ),
        ],
      ),
    );
  }

  // --- PREMIUM AI ADVISOR SECTION ---
  Widget _buildSmartAdvisorSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final result = provider.result;
    final target = provider.targetPercentage.toDouble();

    final subjects = result.subjectStats.values
        .where((s) => s.conducted > 0)
        .toList();
    final criticalSubjects = subjects
        .where((s) => s.percentage < target)
        .sortedBy<num>((s) => s.percentage);
    final cautionSubjects = subjects
        .where((s) => s.percentage >= target && s.percentage < (target + 5.0))
        .sortedBy<num>((s) => s.percentage);
    final safeSubjects = subjects
        .where((s) => s.percentage >= (target + 5.0))
        .sortedBy<num>((s) => -s.percentage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Section Label
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.6),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'AI SMART ADVISOR',
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: 2.0,
                fontWeight: FontWeight.w900,
                color: theme.hintColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 1. MAIN HERO STATUS CARD (Upgraded)
        _buildHeroStatusCard(result, target, theme),
        const SizedBox(height: 16),

        // 2. CRITICAL SECTION (Red)
        if (criticalSubjects.isNotEmpty) ...[
          _buildInsightHeader("🚨 ACTION REQUIRED", Colors.redAccent),
          ...criticalSubjects.take(3).map((subj) {
            double needed = (target / 100.0 * subj.conducted) - subj.attended;
            int consecutiveNeeded = (needed > 0 && (1 - target / 100.0) > 0)
                ? (needed / (1 - target / 100.0)).ceil()
                : 0;
            return _buildActionCard(
              "${subj.name} (${subj.percentage.toStringAsFixed(1)}%)",
              consecutiveNeeded > 0
                  ? "Attend next ~$consecutiveNeeded classes straight to recover."
                  : "Attendance low. Avoid all skips.",
              Icons.bolt_rounded,
              Colors.redAccent,
              theme,
            );
          }),
        ],

        // 3. CAUTION SECTION (Orange)
        if (cautionSubjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInsightHeader("⚠️ CAUTION ZONE", Colors.orangeAccent),
          ...cautionSubjects.take(2).map((subj) {
            double allowed =
                (subj.attended - (target / 100.0 * subj.conducted)) /
                (target / 100.0);
            int skipsAllowed = allowed > 0 ? allowed.floor() : 0;
            return _buildActionCard(
              subj.name,
              "Buffer is thin. You can only afford ~$skipsAllowed skip(s).",
              Icons.warning_amber_rounded,
              Colors.orangeAccent,
              theme,
            );
          }),
        ],

        // 4. SAFE/ELITE SECTION (Green)
        if (safeSubjects.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInsightHeader(
            "✅ PERFORMANCE ELITE",
            Colors.greenAccent.shade400,
          ),
          _buildEliteRow(safeSubjects, target, theme),
        ],

        if (subjects.isEmpty)
          const Center(child: Text("No specific advice generated yet.")),
      ],
    );
  }

  // --- UPGRADED: Hero Status Card ---
  Widget _buildHeroStatusCard(dynamic result, double target, ThemeData theme) {
    final bool isSafe = result.requiredToAttend <= 0;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color mainColor = isSafe
        ? Colors.cyanAccent.shade400
        : Colors.pinkAccent.shade400;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? mainColor.withOpacity(0.05)
            : mainColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: mainColor.withOpacity(isDark ? 0.3 : 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: mainColor.withOpacity(isDark ? 0.1 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background Glow
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: mainColor.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: mainColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        isSafe ? "MISSION CLEAR" : "SYSTEM CRITICAL",
                        style: TextStyle(
                          color: isDark ? mainColor : Colors.black87,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Icon(
                      isSafe ? Icons.check_circle_rounded : Icons.error_rounded,
                      color: mainColor,
                      size: 28,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  isSafe
                      ? "Overall attendance is SAFE at ${result.currentPercentage.toStringAsFixed(1)}%."
                      : "Immediate action: Attend ${result.requiredToAttend} more hours to hit target.",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isSafe && result.maxDroppableHours > 0
                      ? "You have a solid buffer of ${result.maxDroppableHours} hours. Keep it up."
                      : "Every class counts right now. Stay consistent.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UPGRADED: Actionable Subject Card ---
  Widget _buildActionCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? color.withOpacity(0.05) : color.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDark ? 0.2 : 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEliteRow(
    List<dynamic> safeSubjects,
    double target,
    ThemeData theme,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: safeSubjects.map((s) {
          double allowed =
              (s.attended - (target / 100.0 * s.conducted)) / (target / 100.0);
          int skips = allowed > 0 ? allowed.floor() : 0;
          return Container(
            margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${s.percentage.toStringAsFixed(1)}% • $skips skips left",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInsightHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 16),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  // --- List/Table Builders (Unchanged Logic, refined padding) ---
  Widget _buildSubjectList(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    List<MapEntry<String, SubjectStatsDetailed>> subjects,
  ) {
    return Column(
      children: subjects
          .mapIndexed(
            (index, entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildSubjectAnalysisItem(
                context,
                entry.key,
                entry.value,
                provider.targetPercentage.toDouble(),
                theme,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildSubjectDataTable(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    List<MapEntry<String, SubjectStatsDetailed>> subjects,
  ) {
    return CustomCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingRowColor: MaterialStateProperty.all(
            theme.colorScheme.primary.withOpacity(0.05),
          ),
          columns: const [
            DataColumn(
              label: Text(
                'Subject',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                'Att/Con',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              numeric: true,
            ),
            DataColumn(
              label: Text('%', style: TextStyle(fontWeight: FontWeight.bold)),
              numeric: true,
            ),
          ],
          rows: subjects.map((e) {
            final stats = e.value;
            final isSafe = stats.percentage >= provider.targetPercentage;
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    stats.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(
                  Text('${stats.attended.toInt()}/${stats.conducted.toInt()}'),
                ),
                DataCell(
                  Text(
                    '${stats.percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isSafe ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSubjectAnalysisItem(
    BuildContext context,
    String name,
    SubjectStatsDetailed stats,
    double target,
    ThemeData theme,
  ) {
    final bool isDark = theme.brightness == Brightness.dark;
    final double percentage = stats.percentage;
    final Color statusColor = percentage < target
        ? (isDark ? Colors.redAccent : Colors.red.shade700)
        : (percentage < target + 5.0 ? Colors.orange : Colors.green);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${stats.attended.toInt()} attended of ${stats.conducted.toInt()} classes',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircularPercentIndicator(
                        radius: 24.0,
                        lineWidth: 4.5,
                        percent: (percentage / 100.0).clamp(0.0, 1.0),
                        center: Text(
                          "${percentage.toInt()}%",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        progressColor: statusColor,
                        backgroundColor: statusColor.withOpacity(0.1),
                        circularStrokeCap: CircularStrokeCap.round,
                        animation: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
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
