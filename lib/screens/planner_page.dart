import 'dart:ui' as dart_ui; // ✨ NEEDED FOR FROSTED GLASS
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/mixins/scroll_to_top_mixin.dart';
import 'package:bunkmate/services/hive_service.dart';
import 'package:bunkmate/widgets/banner_ad_widget.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/planner/planner_input_controller.dart';
import 'package:bunkmate/planner/planner_sections.dart';
import 'package:bunkmate/navigation/route_observer.dart';
import 'package:bunkmate/widgets/native_ad_card.dart';
import 'package:bunkmate/helpers/button_color_extensions.dart';

class PlannerPage extends StatefulWidget {
  const PlannerPage({super.key});

  @override
  State<PlannerPage> createState() => PlannerPageState();
}

class PlannerPageState extends State<PlannerPage>
    with ScrollToTopMixin, RouteAware {
  late final PlannerInputController inputs;
  bool _projectionPulse = false;
  String? _lastProjectionSignature;
  int _plannerInteractions = 0;

  @override
  void initState() {
    super.initState();
    inputs = PlannerInputController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AttendanceProvider>();

      inputs.customAttend.text = p.plannerFutureClassesToAttend > 0
          ? '${p.plannerFutureClassesToAttend}'
          : '';
      inputs.remainingTime.text = '${p.projectionRemainingTime}';
      inputs.classesPerWeek.text = '${p.projectionClassesPerWeek}';
      inputs.whatIfClasses.text = '${p.whatIfNumClasses}';
      inputs.holidayAttendBefore.text = '${p.holidayAttendBefore}';
      inputs.holidayDays.text = '${p.holidayDays}';
      inputs.holidayTotalClasses.text = '${p.holidayTotalClassesToMiss}';
    });
  }

  void _onAnalyzeSkip(AttendanceProvider provider, String subjectName) {
    if (!provider.result.subjectStats.containsKey(subjectName)) {
      showErrorToast(
        "Subject '$subjectName' not found in your attendance data. Please ensure names match exactly.",
      );
      return;
    }

    provider.setWhatIfSubject(subjectName);
    provider.setWhatIfAction('miss');
    provider.setWhatIfNumClasses(1);
    provider.runWhatIfSimulation();
    _plannerInteractions++;

    showTopToast(
      "Running simulation for skipping 1 class of '$subjectName'...",
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    inputs.dispose();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPushNext() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (_plannerInteractions >= 6) {
      final adProvider = context.read<AdProvider>();
      if (adProvider.shouldShowInterstitial) {
        Future.delayed(const Duration(milliseconds: 300), () {
          AdService.instance.showInterstitialAd();
        });
      }
    }

    _plannerInteractions = 0;
  }

  @override
  void didPopNext() {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Consumer2<AttendanceProvider, PremiumProvider>(
      // ✨ Watch BOTH providers
      builder: (context, provider, premium, child) {
        final theme = Theme.of(context);
        final bool hasBaseData = provider.result.dataParsedSuccessfully;
        final bool isPremium = premium.isPremium; // ✨ Grab Premium status

        return Scaffold(
          // ✨ PREMIUM TOUCH: Glassmorphic AppBar with VIP Badge
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Future Planner 🚀',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                // ✨ PREMIUM TOUCH: The "PRO" Badge
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
            elevation: 0,
            backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.transparent),
              ),
            ),
            automaticallyImplyLeading: false,
          ),
          body: Column(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: !hasBaseData
                      ? _buildPlaceholder(context, theme)
                      : _buildPlannerContent(
                          context,
                          provider,
                          theme,
                          isPremium,
                        ), // Pass isPremium down
                ),
              ),
              // ✨ STRICT AD CHECK: Only show if NOT premium!
              if (!isPremium)
                SafeArea(
                  top: false,
                  child: isPremium
                      ? const SizedBox.shrink()
                      : BannerAdWidget(
                          adUnitId: AdService.instance.plannerBannerAdUnitId,
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _triggerProjectionPulse() {
    if (_projectionPulse) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _projectionPulse = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() => _projectionPulse = false);
        }
      });
    });
  }

  // --- ✨ PREMIUM TOUCH: Vibrant Placeholder Widget ---
  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? Colors.purpleAccent : Colors.deepPurple;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(Icons.auto_awesome_rounded, size: 64, color: color),
            ),
            const SizedBox(height: 24),
            Text(
              'Awaiting Data',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Head to the Home page and calculate your attendance first to unlock the simulation engine!',
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

  // --- Main Planner Content ---
  // --- Main Planner Content ---
  Widget _buildPlannerContent(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
    bool isPremium, // ✨ Accept isPremium parameter
  ) {
    final projectionSignature = [
      provider.projectionRemainingTime,
      provider.projectionClassesPerWeek,
      provider.projectionMode,
      provider.projectionFinalPercentage.toStringAsFixed(2),
    ].join('|');

    if (_lastProjectionSignature == null) {
      _lastProjectionSignature = projectionSignature;
    } else if (_lastProjectionSignature != projectionSignature) {
      _lastProjectionSignature = projectionSignature;
      _triggerProjectionPulse();
      _plannerInteractions++;
    }

    final customCalcResult = provider.calculateCustomMissable();

    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        16.0,
        8.0,
        16.0,
        isPremium ? MediaQuery.of(context).padding.bottom + 30.0 : 40.0,
      ),
      child: Column(
        children: [
          _buildTodaysClassesSection(context, provider, theme),

          // ✨ PREMIUM TOUCH: Removed grey lines, using spatial hierarchy
          const SizedBox(height: 24),

          // 🔮 PROJECTION
          CustomCard(
            child: PlannerSections.projection(
              context: context,
              provider: provider,
              theme: theme,
              inputs: inputs,
              projectionPulse: _projectionPulse,
              onPulse: _triggerProjectionPulse,
              inputDecoration: _inputDecoration,
              segmentedButtonStyle: _segmentedButtonStyle,
            ),
          ),

          const SizedBox(height: 24),

          // ✨ STRICT NATIVE AD CHECK: Only show if NOT premium!
          if (!isPremium) ...[const NativeAdCard(), const SizedBox(height: 24)],

          // ✨ CUSTOM SCENARIO
          CustomCard(
            child: PlannerSections.customScenario(
              context: context,
              provider: provider,
              theme: theme,
              inputs: inputs,
              customCalcResult: customCalcResult,
              inputDecoration: _inputDecoration,
              resultPlaceholder: _buildResultPlaceholder,
            ),
          ),

          const SizedBox(height: 24),

          // 🧪 ADVANCED WHAT-IF
          CustomCard(
            child: PlannerSections.advancedWhatIf(
              context: context,
              provider: provider,
              theme: theme,
              inputs: inputs,
              inputDecoration: _inputDecoration,
              elevatedButtonStyle: _elevatedButtonStyle,
            ),
          ),

          const SizedBox(height: 24),

          // 🏖️ HOLIDAY PLANNER
          CustomCard(
            child: PlannerSections.holidayPlanner(
              context: context,
              provider: provider,
              theme: theme,
              inputs: inputs,
              inputDecoration: _inputDecoration,
              elevatedButtonStyle: _elevatedButtonStyle,
            ),
          ),
        ],
      ),
    );
  }

  // --- ✨ PREMIUM TOUCH: Glowing Interactive Tickets ---
  Widget _buildTodaysClassesSection(
    BuildContext context,
    AttendanceProvider provider,
    ThemeData theme,
  ) {
    final schedule = HiveService.getSchedule();
    final today = DateTime.now().weekday;
    final todaysClasses = schedule.where((e) => e.dayOfWeek == today).toList();

    final now = TimeOfDay.now();
    final upcomingClasses = todaysClasses.where((e) {
      final timeParts = e.startTime.split(':');
      final classTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
      return (classTime.hour > now.hour) ||
          (classTime.hour == now.hour && classTime.minute >= now.minute);
    }).toList();

    upcomingClasses.sort((a, b) => a.startTime.compareTo(b.startTime));
    final isDark = theme.brightness == Brightness.dark;

    return CustomCard(
      gradient: LinearGradient(
        colors: isDark
            ? [
                theme.colorScheme.surface,
                theme.colorScheme.surface.withOpacity(0.8),
              ]
            : [Colors.white, theme.colorScheme.surface],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
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
                  Icons.bolt_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Today\'s Classes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tap any upcoming class to simulate skipping it.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 20),
          if (upcomingClasses.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No upcoming classes right now. You\'re free! 🎉',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          if (upcomingClasses.isNotEmpty)
            SizedBox(
              height: 120, // Taller to fit new design
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none, // Allows shadows to glow
                itemCount: upcomingClasses.length,
                itemBuilder: (context, index) {
                  final entry = upcomingClasses[index];

                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 16),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _onAnalyzeSkip(provider, entry.subjectName);
                        final adProvider = context.read<AdProvider>();
                        final premium = context.read<PremiumProvider>();

                        if (!premium.isPremium &&
                            adProvider.shouldShowInterstitial) {
                          Future.delayed(const Duration(milliseconds: 500), () {
                            AdService.instance.showInterstitialAd();
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: theme.colorScheme.primary.withOpacity(
                            isDark ? 0.1 : 0.05,
                          ),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? theme.colorScheme.primaryContainer
                                          .lighten()
                                    : theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                entry.startTime,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              entry.subjectName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Helper for placeholder text in result areas
  Widget _buildResultPlaceholder(ThemeData theme, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          text,
          style: TextStyle(fontStyle: FontStyle.italic, color: theme.hintColor),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // --- STYLING HELPERS ---
  InputDecoration _inputDecoration(
    ThemeData theme, {
    String? label,
    String? hint,
    bool isDropdown = false,
  }) {
    final isDarkMode = theme.brightness == Brightness.dark;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      hintText: hint,
      filled: true,
      fillColor: isDarkMode
          ? theme.colorScheme.surface.withOpacity(0.5)
          : Colors.black.withOpacity(0.04),
      floatingLabelBehavior: label != null
          ? FloatingLabelBehavior.always
          : FloatingLabelBehavior.never,
      alignLabelWithHint: true,

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.primary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      contentPadding: EdgeInsets.fromLTRB(
        16,
        (label != null ? 20 : 14),
        16,
        (label != null ? 8 : 14),
      ),
    );
  }

  ButtonStyle _elevatedButtonStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      backgroundColor: isDark
          ? theme.colorScheme.primaryContainer.lighten()
          : theme.colorScheme.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      textStyle: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: -0.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  ButtonStyle _segmentedButtonStyle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return SegmentedButton.styleFrom(
      selectedBackgroundColor: theme.colorScheme.primary.withOpacity(
        isDark ? 0.2 : 0.1,
      ),
      selectedForegroundColor: theme.colorScheme.primary,
      side: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
