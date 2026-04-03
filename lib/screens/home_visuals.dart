import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'dart:ui' as dart_ui;
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/widgets/dropzone_widget.dart';
import 'package:bunkmate/widgets/saves_modal.dart';
import 'package:bunkmate/widgets/native_ad_card.dart';
import 'package:bunkmate/widgets/banner_ad_widget.dart';
import 'package:bunkmate/widgets/unrecognized_format_card.dart';
import 'package:bunkmate/widgets/path_to_target_dialog.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/helpers/button_color_extensions.dart';
import 'home_page.dart';
import 'home_logic.dart';
import 'home_helpers.dart';

class HomeVisuals {
  static PreferredSizeWidget buildAppBar(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final isDarkMode = context.select<ThemeProvider, bool>((t) => t.isDarkMode);
    // ✨ Watch for Premium Status!
    final premium = context.watch<PremiumProvider>();
    final hasData = provider.rawData.isNotEmpty;
    final theme = Theme.of(context);

    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            premium.isPremium ? 'BunkER' : 'BunkMate',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          // ✨ PREMIUM TOUCH: The "PRO" Badge
          if (premium.isPremium) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  color:
                      Colors.white, // ✨ White text looks way better on purple
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
      automaticallyImplyLeading: false,
      elevation: 0,
      backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          tooltip: 'Toggle Theme',
          onPressed: () => _handleThemeToggle(state, context),
        ),
        if (hasData)
          IconButton(
            icon: const Icon(
              Icons.delete_sweep_outlined,
              color: Colors.redAccent,
            ),
            tooltip: 'Clear Data',
            onPressed: () => _showClearDataDialog(state, context, provider),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  static Widget buildInputCard(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final theme = Theme.of(context);
    final String dataSourceStatus =
        provider.fileName ??
        (provider.rawData.isNotEmpty ? "Pasted Data" : "No Data Loaded");

    return CustomCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Input Attendance Data',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: Icon(
                  state.showRawDataInput
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: theme.colorScheme.secondary,
                ),
                onPressed: () => state.setState(
                  () => state.showRawDataInput = !state.showRawDataInput,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: TextField(
              controller: state.rawDataController,
              maxLines: 8,
              minLines: 5,
              decoration: InputDecoration(
                hintText: 'Paste or type attendance data...',
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), // Softer corners
                  borderSide: BorderSide.none, // Clean, borderless look
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.5),
                    width: 2,
                  ),
                ),
              ),
              onChanged: provider.updateRawDataWithoutCalc,
            ),
            secondChild: const DropzoneWidget(),
            crossFadeState: state.showRawDataInput
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
            child: Center(
              child: Text(
                'Source: $dataSourceStatus',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.save_alt_rounded, size: 18),
                label: const Text('Saves'),
                onPressed: provider.isLoading
                    ? null
                    : () => _showSavesModal(context),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Paste'),
                onPressed: provider.isLoading
                    ? null
                    : () => HomeLogic.handlePaste(state),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildGaugeSection(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    if (provider.errorMessage != null ||
        !provider.result.dataParsedSuccessfully ||
        provider.result.totalConducted <= 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final target = provider.targetPercentage.toDouble();
    final current = provider.result.currentPercentage.clamp(0.0, 100.0);
    final statusColor = HomeLogic.getResultStatusColor(provider);

    return Opacity(
      opacity: provider.isLoading ? 0.5 : 1.0,
      child: CustomCard(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Text(
              'Current Standing',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.hintColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.65,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ✨ PREMIUM TOUCH: Glowing ambient orb behind the gauge
                      Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.20),
                              blurRadius: 40,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      // The Gauge itself
                      IgnorePointer(
                        child: SfRadialGauge(
                          axes: <RadialAxis>[
                            RadialAxis(
                              minimum: 0,
                              maximum: 100,
                              showLabels: false,
                              showTicks: false,
                              startAngle: 180,
                              endAngle: 0,
                              axisLineStyle: AxisLineStyle(
                                thickness: 0.2,
                                thicknessUnit: GaugeSizeUnit.factor,
                                color: theme.disabledColor.withOpacity(0.15),
                                cornerStyle: CornerStyle.bothCurve,
                              ),
                              pointers: <GaugePointer>[
                                RangePointer(
                                  value: current,
                                  width: 0.2,
                                  sizeUnit: GaugeSizeUnit.factor,
                                  cornerStyle: CornerStyle.bothCurve,
                                  enableAnimation: true,
                                  animationDuration: 1200,
                                  animationType: AnimationType.easeOutBack,
                                  gradient: SweepGradient(
                                    colors: [
                                      statusColor.withOpacity(0.5),
                                      statusColor,
                                    ],
                                    stops: const [0.1, 1.0],
                                  ),
                                ),
                                MarkerPointer(
                                  value: target,
                                  markerType: MarkerType.invertedTriangle,
                                  markerHeight: 12,
                                  markerWidth: 12,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white70
                                      : Colors.black54,
                                  offsetUnit: GaugeSizeUnit.factor,
                                  markerOffset: -0.05,
                                  enableAnimation: true,
                                  animationDuration: 1200,
                                ),
                              ],
                              annotations: <GaugeAnnotation>[
                                GaugeAnnotation(
                                  widget: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // ✨ PREMIUM TOUCH: Animated Number Counter
                                      TweenAnimationBuilder<double>(
                                        tween: Tween<double>(
                                          begin: 0,
                                          end:
                                              provider.result.currentPercentage,
                                        ),
                                        duration: const Duration(
                                          milliseconds: 1200,
                                        ),
                                        curve: Curves.easeOutQuart,
                                        builder: (context, value, child) {
                                          return Text(
                                            '${value.toStringAsFixed(1)}%',
                                            style: theme.textTheme.displaySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: statusColor,
                                                  letterSpacing: -1.0,
                                                ),
                                          );
                                        },
                                      ),
                                      Text(
                                        'Target: ${target.toInt()}%',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme.hintColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                  angle: 90,
                                  positionFactor: 0.1,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildTargetCard(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bool canCalculate =
        provider.rawData.isNotEmpty && !provider.isLoading;

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Target Attendance',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Unified Stepper Control ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.dividerColor.withOpacity(isDark ? 0.2 : 0.1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TargetStepperButton(
                  icon: Icons.remove_rounded,
                  increment: false,
                  onTap: () => _updateTarget(state, provider, -1),
                ),
                Expanded(
                  child: Center(
                    child: _buildTargetInput(state, context, provider),
                  ),
                ),
                TargetStepperButton(
                  icon: Icons.add_rounded,
                  increment: true,
                  onTap: () => _updateTarget(state, provider, 1),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // --- Massive Hero Action Button ---
          SizedBox(
            width: double.infinity,
            height: 56, // Premium height
            child: ElevatedButton(
              onPressed: canCalculate
                  ? () => HomeLogic.handleCalculate(state)
                  : null,
              style: ElevatedButton.styleFrom(
                elevation: canCalculate ? 5 : 0,
                shadowColor: theme.colorScheme.primary.withOpacity(0.4),

                backgroundColor: isDark
                    ? theme.colorScheme.primaryContainer.lighten()
                    : theme.colorScheme.primary,

                foregroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: provider.isLoading
                  ? const Text(
                      "¯|_(ツ)_/¯",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 22),
                        SizedBox(width: 12),
                        Text(
                          "Calculate Insights",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildResultsArea(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    return Column(
      key: state.resultsKey,
      children: [
        if (provider.result.totalConducted > 0)
          Stack(
            children: [
              Opacity(
                opacity: provider.isLoading ? 0.35 : 1.0,
                child: Column(
                  children: [
                    const Divider(height: 24, thickness: 0.5),
                    AnimatedScale(
                      scale: state.pulseResult ? 1.015 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          boxShadow: state.pulseResult
                              ? [
                                  BoxShadow(
                                    color: HomeLogic.getResultStatusColor(
                                      provider,
                                    ).withOpacity(0.25),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                        child: _buildResultsAwesomeSection(context, provider),
                      ),
                    ),
                  ],
                ),
              ),
              if (provider.isLoading)
                const Positioned.fill(
                  child: Center(
                    child: Text(
                      "Processing...",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        if (!provider.isLoading && provider.isUnrecognizedFormat)
          UnrecognizedFormatCard(rawData: provider.rawInputSnapshot)
        else if (!provider.isLoading && provider.errorMessage != null)
          _buildErrorBox(context, provider.errorMessage!),
      ],
    );
  }

  static Widget buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👋 Get started',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste your attendance data or drop a file to see where you stand.\n\nWe’ll tell you exactly how many classes you can skip — or need to attend.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  static Widget buildNativeAd(BuildContext context) {
    // Read the premium status directly
    final isPremium = context.watch<PremiumProvider>().isPremium;

    if (isPremium) {
      return const SizedBox.shrink();
    }

    return const NativeAdCard();
  }

  static Widget buildBottomBanner(BuildContext context) {
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return SafeArea(
      top: false,
      child: isPremium
          ? const SizedBox.shrink()
          : BannerAdWidget(
              key: const ValueKey('home_banner'),
              adUnitId: AdService.instance.homeBannerAdUnitId,
            ),
    );
  }

  // --- Internal UI Helpers ---

  static void _updateTarget(
    HomePageState state,
    AttendanceProvider provider,
    int delta,
  ) {
    HapticFeedback.selectionClick();
    SystemSound.play(SystemSoundType.click);
    final current =
        int.tryParse(state.targetPercentController.text) ??
        provider.targetPercentage;
    state.targetPercentController.text = (current + delta)
        .clamp(0, 100)
        .toString();
  }

  static Widget _buildTargetInput(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) {
    return GestureDetector(
      onTap: () {
        state.setState(() => state.editingTarget = true);
        state.targetFocusNode.requestFocus();
      },
      onHorizontalDragUpdate: (details) {
        state.dragAccumulator += details.delta.dx;
        const pixelsPerStep = 6;
        if (state.dragAccumulator.abs() < pixelsPerStep) return;
        final steps = (state.dragAccumulator / pixelsPerStep).truncate();
        state.dragAccumulator -= steps * pixelsPerStep;
        final current =
            int.tryParse(state.targetPercentController.text) ??
            provider.targetPercentage;
        state.targetPercentController.text = (current + steps)
            .clamp(0, 100)
            .toString();
        HapticFeedback.selectionClick();
      },
      onHorizontalDragEnd: (_) {
        state.dragAccumulator = 0;
        state.editingTarget = false;
        HomeLogic.commitTargetPercentage(state);
      },
      child: AbsorbPointer(
        absorbing: !state.editingTarget,
        child: SizedBox(
          width: 90,
          child: TextField(
            focusNode: state.targetFocusNode,
            controller: state.targetPercentController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 3,
            decoration: InputDecoration(
              counterText: "",
              suffixText: "%",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onEditingComplete: () {
              state.editingTarget = false;
              HomeLogic.commitTargetPercentage(state);
            },
          ),
        ),
      ),
    );
  }

  static Widget _buildResultsAwesomeSection(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final result = provider.result;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final target = provider.targetPercentage.toDouble();
    final currentPercent = result.currentPercentage.clamp(0.0, 100.0);
    final bool isAboveTarget = currentPercent >= target;
    final int skips = result.maxDroppableHours;
    final int required = result.requiredToAttend;
    final classesPerWeek = provider.projectionClassesPerWeek;

    final int daysPerWeek = provider.projectionDaysPerWeek;

    String? conversionTooltip;
    if (classesPerWeek > 0 && daysPerWeek > 0) {
      final double classesPerDay = classesPerWeek / daysPerWeek;
      // final int rounded = classesPerDay.round();
      final int rounded = classesPerDay.ceil();

      conversionTooltip = "$rounded hr${rounded == 1 ? '' : 's'} = 1 day";
    }

    // Calculate weeks context for skips
    // String skipsWeeksContext = "";
    // if (skips > 0 && classesPerWeek > 0 && required <= 0) {
    //   final weeks = (skips / classesPerWeek);
    //   skipsWeeksContext =
    //       " (~${weeks.toStringAsFixed(1)} week${weeks == 1.0 ? '' : 's'})";
    // }

    String skipsTimeContext = "";

    if (skips > 0 && required <= 0) {
      final int classesPerWeek = provider.projectionClassesPerWeek;

      if (classesPerWeek > 0 && daysPerWeek > 0) {
        final double classesPerDay = classesPerWeek / daysPerWeek;

        final int fullDays = (skips / classesPerDay).floor();
        final int remainingHours = skips - (fullDays * classesPerDay).round();

        if (fullDays > 0 && remainingHours > 0) {
          skipsTimeContext =
              "$fullDays day${fullDays == 1 ? '' : 's'} + "
              "$remainingHours hr${remainingHours == 1 ? '' : 's'}";
        } else if (fullDays > 0) {
          skipsTimeContext = "$fullDays day${fullDays == 1 ? '' : 's'}";
        } else {
          skipsTimeContext =
              "$remainingHours hr${remainingHours == 1 ? '' : 's'}";
        }
      }
    }

    // Determine Status, Colors, Icons & Message
    String statusText;
    Color statusColor;
    IconData statusIcon;
    Color gradientStart, gradientEnd;
    String statusMessage; // Dedicated message variable
    IconData messageIcon; // Dedicated message icon

    String primaryValue;
    String primaryLabel;
    IconData primaryIcon;
    String? primarySubText;

    if (required > 0) {
      // Below Target State
      statusText = "Below Target";
      statusColor = isDarkMode ? Colors.red.shade300 : Colors.red.shade700;
      statusIcon = Icons.warning_amber_rounded;
      gradientStart = isDarkMode ? Colors.red.shade400 : Colors.red.shade200;
      gradientEnd = isDarkMode ? Colors.red.shade800 : Colors.red.shade500;
      messageIcon = Icons.unpublished_outlined; // Use relevant icon
      statusMessage =
          'Attend ${required} more consecutive class(es) to reach ${target.toStringAsFixed(0)}%.';

      primaryValue = required.toString();
      primaryLabel = "Need to Attend";
      primaryIcon = messageIcon; // Match primary icon
      primarySubText = "consecutively";
    } else {
      // Above Target State
      primaryValue = skips.toString();
      primaryLabel = "Max Future Skips";
      primaryIcon = Icons.directions_run_outlined;
      // primarySubText = skipsWeeksContext;
      // primarySubText = skipsDaysContext;

      primarySubText = skipsTimeContext;

      final double projectedConducted = (result.totalConducted + skips)
          .toDouble();

      final double projectedPercentAfterSkips = projectedConducted > 0
          ? (result.totalAttended / projectedConducted) * 100
          : currentPercent;

      const int untouchableSkips = 20;

      if (skips < 5) {
        // 🟠 CAUTION
        statusText = "Caution Zone";
        statusColor = isDarkMode
            ? Colors.orange.shade300
            : Colors.orange.shade700;
        statusIcon = Icons.error_outline_rounded;
        gradientStart = isDarkMode
            ? Colors.orange.shade400
            : Colors.orange.shade200;
        gradientEnd = isDarkMode
            ? Colors.orange.shade800
            : Colors.orange.shade500;
        messageIcon = Icons.shield_outlined;

        statusMessage =
            "You're close! Only $skips more skip${skips == 1 ? '' : 's'} allowed — you'd end up at ${projectedPercentAfterSkips.toStringAsFixed(1)}%.";
      } else if (skips >= untouchableSkips) {
        HapticFeedback.heavyImpact();
        // 🗿 UNTOUCHABLE
        statusText = "Invincible 🗿";
        statusColor = isDarkMode
            ? Colors.tealAccent.shade400
            : Colors.teal.shade700;
        statusIcon = Icons.workspace_premium_rounded;
        gradientStart = isDarkMode
            ? Colors.teal.shade400
            : Colors.teal.shade200;
        gradientEnd = isDarkMode
            ? Colors.green.shade900
            : Colors.green.shade600;
        messageIcon = Icons.emoji_events_rounded;

        statusMessage =
            "You’re massively ahead. Have time for your own self mate live this huge buffer of $skips hours & still be around ${projectedPercentAfterSkips.toStringAsFixed(1)}%.";
      } else {
        // 🟢 SAFE
        statusText = "Safe";
        statusColor = isDarkMode
            ? Colors.green.shade300
            : Colors.green.shade600;
        statusIcon = Icons.verified_user_outlined;
        gradientStart = isDarkMode
            ? Colors.green.shade400
            : Colors.green.shade200;
        gradientEnd = isDarkMode
            ? Colors.green.shade800
            : Colors.green.shade500;
        messageIcon = Icons.verified_user;

        statusMessage =
            "Plenty of buffer! You can skip $skips more hour(s) and still be around ${projectedPercentAfterSkips.toStringAsFixed(1)}%.";
      }
    }

    // --- Card Build ---
    return Card(
      elevation: 0, // Turn off default elevation
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ), // Rounder corners
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // ✨ PREMIUM TOUCH: Multi-stop rich gradient
          gradient: LinearGradient(
            colors: [
              gradientStart.withOpacity(isDarkMode ? 0.4 : 0.2),
              gradientEnd.withOpacity(isDarkMode ? 0.1 : 0.05),
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.5, 1.0],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // ✨ PREMIUM TOUCH: Outer ambient glow
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(isDarkMode ? 0.15 : 0.25),
              blurRadius: 24,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
          ],
          border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            // --- Header with Status ---
            Container(
              /* ... Status header setup ... */
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientStart.withOpacity(0.5),
                    gradientEnd.withOpacity(0.3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(statusIcon, color: statusColor, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),

            // --- Main Content Padding ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20.0, 24.0, 20.0, 20.0),
              child: Column(
                children: [
                  // --- PRIMARY METRIC DISPLAY ---
                  // ✨ PREMIUM TOUCH: Breathing Icon Background
                  Tooltip(
                    message: conversionTooltip ?? '',
                    triggerMode: TooltipTriggerMode.tap,
                    waitDuration: const Duration(milliseconds: 300),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(seconds: 2),
                      curve: Curves.easeInOutSine,
                      builder: (context, scale, child) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor.withOpacity(0.15 * scale),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.2 * scale),
                                blurRadius: 16 * scale,
                                spreadRadius: 4 * scale,
                              ),
                            ],
                          ),
                          child: Icon(
                            primaryIcon,
                            size: 38,
                            color: statusColor,
                          ),
                        );
                      },
                    ),
                  ),

                  // Icon(
                  //   primaryIcon,
                  //   size: 36,
                  //   color: statusColor.withOpacity(0.85),
                  // ),
                  const SizedBox(height: 8),
                  FittedBox(
                    /* ... Primary value text ... */
                    fit: BoxFit.scaleDown,
                    child: Text(
                      primaryValue,
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: statusColor.withOpacity(0.3),
                            offset: const Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                  Text(
                    primaryLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (primarySubText != null && primarySubText.isNotEmpty)
                    Padding(
                      /* ... Subtext ... */
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        primarySubText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor.withOpacity(0.8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 24), // Space after primary metric
                  // --- ** NEW INTEGRATED MESSAGE BOX ** ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(isDarkMode ? 0.25 : 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.4)),
                    ),
                    // --- Use a Column inside the message box ---
                    child: Column(
                      children: [
                        Row(
                          // Original message row
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment
                              .center, // Align items vertically
                          children: [
                            Icon(messageIcon, color: statusColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              // Allow text to wrap
                              child: Text(
                                statusMessage,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                        // --- Conditionally Add "Show Path" Button HERE ---
                        if (required > 0)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 10.0,
                            ), // Space above button
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.map_outlined,
                                size: 16,
                              ), // Slightly smaller icon
                              label: const Text('Show Recovery Path'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme
                                    .colorScheme
                                    .secondary, // Or use statusColor
                                side: BorderSide(
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.5),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ), // Adjust padding
                                textStyle: theme
                                    .textTheme
                                    .labelMedium, // Adjust text style if needed
                                visualDensity: VisualDensity
                                    .compact, // Make button tighter
                              ),
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                showDialog(
                                  context: context,
                                  builder: (_) => PathToTargetDialog(
                                    requiredClasses: required,
                                    currentAttended: result.totalAttended,
                                    currentConducted: result.totalConducted,
                                    targetPercentage: target / 100.0,
                                    classesPerWeek:
                                        provider.projectionClassesPerWeek,
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ), // --- END INTEGRATED MESSAGE BOX ---

                  const SizedBox(height: 24), // Space after message box
                  // --- Secondary Metrics Row ---
                  IntrinsicHeight(
                    child: Row(
                      /* ... Secondary metrics setup ... */
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Current %",
                            '${result.currentPercentage.toStringAsFixed(2)}%',
                            // '${currentPercent.toStringAsFixed(2)}%',
                            isAboveTarget
                                ? Icons.trending_up
                                : Icons.trending_down,
                            isAboveTarget
                                ? (isDarkMode
                                      ? Colors.green.shade300
                                      : Colors.green.shade700)
                                : (isDarkMode
                                      ? Colors.red.shade300
                                      : Colors.red.shade700),
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 0.5),
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Attended",
                            result.totalAttended.toStringAsFixed(0),
                            Icons.how_to_reg_outlined,
                          ),
                        ),
                        const VerticalDivider(width: 1, thickness: 0.5),
                        Expanded(
                          child: _buildSecondaryMetric(
                            context,
                            "Conducted",
                            result.totalConducted.toStringAsFixed(0),
                            Icons.event_available_outlined,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Progress Bar (Optional - could be removed if message box is enough) ---
                  // Keep it for now, as it provides visual context for the 'buffer'
                  if (required <= 0) ...[
                    // Use collection-if
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        Text(
                          "Buffer Until Target (${target.toStringAsFixed(0)}%)",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LinearPercentIndicator(
                          /* ... Same setup as before ... */
                          percent:
                              ((currentPercent - target) / (100.0 - target))
                                  .clamp(0.0, 1.0),
                          lineHeight: 12.0,
                          progressColor: statusColor,
                          backgroundColor: statusColor.withOpacity(0.2),
                          barRadius: const Radius.circular(6),
                          animateFromLastPercent: true,
                          animation: true,
                          animationDuration: 800,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          /* ... Target/100% labels ... */
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${target.toStringAsFixed(0)}%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                              Text(
                                '100%',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildSecondaryMetric(
    BuildContext context,
    String label,
    String value,
    IconData icon, [
    Color? valueColor,
  ]) {
    /* ... same as before ... */
    final theme = Theme.of(context);
    final color = valueColor ?? theme.textTheme.bodyLarge?.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color?.withOpacity(0.7) ?? theme.hintColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  static Widget _buildErrorBox(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text("⚠️ Error: $message", textAlign: TextAlign.center),
    );
  }

  static void _showSavesModal(BuildContext context) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const SavesModal(),
    );
  }

  // static void _handleThemeToggle(
  //   HomePageState state,
  //   BuildContext context,
  // ) async {
  //   FocusManager.instance.primaryFocus?.unfocus();
  //   FocusScope.of(context).unfocus();
  //   SystemChannels.textInput.invokeMethod('TextInput.hide');

  //   final themeProvider = context.read<ThemeProvider>();
  //   final adProvider = context.read<AdProvider>();
  //   final premium = context.read<PremiumProvider>();

  //   HapticFeedback.lightImpact();

  //   // ✅ Premium users: instant toggle
  //   if (premium.isPremium) {
  //     themeProvider.toggleTheme(persist: true);
  //     return;
  //   }

  //   // ✅ Already unlocked today
  //   if (adProvider.isDarkThemeUnlocked) {
  //     themeProvider.toggleTheme(persist: true);
  //     return;
  //   }

  //   // 🛑 Block spam
  //   if (state.isThemeUnlockInProgress) return;
  //   state.isThemeUnlockInProgress = true;

  //   final originalTheme = themeProvider.themeMode;

  //   // 👀 TEMP preview (tease)
  //   themeProvider.applyTheme(ThemeMode.dark);

  //   // ⏱ Short preview window
  //   await Future.delayed(const Duration(milliseconds: 1010));

  //   // 🔄 Revert if still locked
  //   if (!state.mounted) return;
  //   themeProvider.applyTheme(originalTheme);

  //   Future.delayed(const Duration(milliseconds: 470), () {
  //     if (!state.mounted) return;
  //     FocusManager.instance.primaryFocus?.unfocus();

  //     showRewardedAdDialog(
  //       context: context,
  //       title: 'Unlock Dark Mode',
  //       content:
  //           'Unlock a world of quiet elegance—Dark Mode awaits your consent. 🗿',
  //       onReward: () {
  //         adProvider.unlockDarkThemeForToday();
  //         themeProvider.applyTheme(ThemeMode.dark, persist: true);
  //       },
  //     );
  //   });

  //   // 🔓 Allow future attempts *after dialog closes*
  //   Future.delayed(const Duration(milliseconds: 300), () {
  //     state.isThemeUnlockInProgress = false;
  //   });
  // } //checkdarkmode

  static void _handleThemeToggle(HomePageState state, BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    HapticFeedback.lightImpact();

    // Directly toggle the theme instantly without any ads or delays
    final themeProvider = context.read<ThemeProvider>();
    themeProvider.toggleTheme(persist: true);
  }

  static void _showClearDataDialog(
    HomePageState state,
    BuildContext context,
    AttendanceProvider provider,
  ) async {
    FocusScope.of(context).unfocus();

    bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Colors.red.shade900.withOpacity(0.35),
                        Colors.red.shade800.withOpacity(0.15),
                      ]
                    : [
                        Colors.red.shade100.withOpacity(0.6),
                        Colors.red.shade50.withOpacity(0.3),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.15),
                  ),
                  child: const Icon(
                    Icons.delete_forever_rounded,
                    size: 34,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Clear All Data?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This will permanently remove your current and saved attendance data.\n\nThis action cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Clear Data',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm == true && state.mounted) {
      provider.clearData();
      state.rawDataController.clear();
      showTopToast('🧹 Data Cleared.');
    }
  }
}
