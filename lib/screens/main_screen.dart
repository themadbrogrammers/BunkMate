import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/settings_provider.dart';

// --- Imports for Pages and Toast ---
import 'package:bunkmate/screens/home_page.dart';
import 'package:bunkmate/screens/gpa_alchemist_screen.dart';
import 'package:bunkmate/screens/analysis_page.dart';
import 'package:bunkmate/screens/planner_page.dart';
import 'package:bunkmate/screens/settings_page.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/widgets/bouncing_tip_widget.dart';
import 'package:bunkmate/providers/premium_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const BorderRadius _navRadius = BorderRadius.all(Radius.circular(32));

  int _selectedIndex = 0;
  bool _launchActionCompleted = false;

  bool _hasDiscoveredAppSwitcher = false;
  bool _showTooltip = false;

  final GlobalKey<HomePageState> _homeKey = GlobalKey();
  final GlobalKey<AnalysisPageState> _analysisKey = GlobalKey();
  final GlobalKey<PlannerPageState> _plannerKey = GlobalKey();
  final GlobalKey<SettingsPageState> _settingsKey = GlobalKey();

  final List<Widget?> _cachedPages = List.filled(4, null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _homeKey.currentState?.setActive(true);
      _initAndPerformLaunchAction();
    });
    _checkFirstTimeAppSwitcher();
  }

  // ✨ LOGIC: Check SharedPreferences
  Future<void> _checkFirstTimeAppSwitcher() async {
    final prefs = await SharedPreferences.getInstance();

    final discovered = prefs.getBool('has_discovered_app_switcher') ?? false;

    if (!mounted) return;

    setState(() {
      _hasDiscoveredAppSwitcher = discovered;
    });

    // ✨ MOVE DELAY HERE
    if (!discovered) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _showTooltip = true;
          });
        }
      });
    }
  }

  // ✨ LOGIC: Mark as Discovered
  Future<void> _markAppSwitcherDiscovered() async {
    if (!_hasDiscoveredAppSwitcher) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_discovered_app_switcher', true);
      if (mounted) {
        setState(() {
          _hasDiscoveredAppSwitcher = true;
        });
      }
    }
  }

  Widget _buildPage(int index) {
    return _cachedPages[index] ??= switch (index) {
      0 => HomePage(key: _homeKey),
      1 => AnalysisPage(key: _analysisKey),
      2 => PlannerPage(key: _plannerKey),
      3 => SettingsPage(key: _settingsKey),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _initAndPerformLaunchAction() async {
    if (_launchActionCompleted || !mounted) return;

    final settingsProvider = context.read<SettingsProvider>();
    await settingsProvider.initializationComplete;

    if (!mounted) return;
    _performLaunchAction();
    _launchActionCompleted = true;
  }

  void _performLaunchAction() {
    final settingsProvider = context.read<SettingsProvider>();
    final attendanceProvider = context.read<AttendanceProvider>();

    switch (settingsProvider.launchOption) {
      case AppLaunchOption.resume:
        attendanceProvider.loadSavedData().then((loaded) {
          if (!loaded && mounted) {
            showTopToast(
              '⚠️ No saved data found to resume.',
              backgroundColor: Colors.orange.shade700,
            );
          }
        });
        break;

      case AppLaunchOption.clipboard:
        Clipboard.getData(Clipboard.kTextPlain).then((data) {
          if (data?.text?.isNotEmpty == true && mounted) {
            attendanceProvider.setRawData(
              data!.text!,
              newFileName: "Pasted from Clipboard",
            );
          }
        });
        break;

      case AppLaunchOption.none:
      default:
        break;
    }
  }

  void _onItemTapped(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    if (index == _selectedIndex) {
      HapticFeedback.mediumImpact();

      switch (index) {
        case 0:
          _homeKey.currentState?.scrollToTop();
          break;
        case 1:
          _analysisKey.currentState?.scrollToTop();
          break;
        case 2:
          _plannerKey.currentState?.scrollToTop();
          break;
        case 3:
          _settingsKey.currentState?.scrollToTop();
          break;
      }

      if (index == 0) {
        _homeKey.currentState?.setActive(true);
      }
    } else {
      HapticFeedback.lightImpact();
      setState(() => _selectedIndex = index);
      _homeKey.currentState?.setActive(index == 0);
    }
  }

  void _showAppSwitcherMenu(BuildContext context) {
    HapticFeedback.heavyImpact();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 90),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E).withOpacity(0.9)
                      : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.4 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: dart_ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAppSwitcherTile(
                          context: context,
                          title: 'BunkMate',
                          subtitle: 'Attendance Tracker',
                          icon: Icons.backpack_rounded,
                          color: theme.colorScheme.primary,
                          isSelected: true,
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                        Divider(
                          height: 1,
                          color: theme.dividerColor.withOpacity(0.1),
                        ),
                        _buildAppSwitcherTile(
                          context: context,
                          title: 'GPA Lab',
                          subtitle: 'Grade Forecaster',
                          icon: Icons.science_rounded,
                          color: Colors.purpleAccent,
                          isSelected: false,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GpaAlchemistScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            alignment: Alignment.bottomLeft,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildAppSwitcherTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: isSelected
            ? color.withOpacity(isDark ? 0.1 : 0.05)
            : Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✨ Watch premium status to know if the ad is currently rendering
    final isPremium = context.watch<PremiumProvider>().isPremium;

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _selectedIndex,
            children: List.generate(4, (index) {
              if (index == _selectedIndex || _cachedPages[index] != null) {
                return _buildPage(index);
              }
              return const SizedBox.shrink();
            }),
          ),
          bottomNavigationBar: _buildFloatingIslandNav(),
        ),

        // ✨ THE FLOATING COACH MARK TOOLTIP
        if (!_hasDiscoveredAppSwitcher && _showTooltip)
          Positioned(
            // ✨ SMART POSITIONING:
            // If Premium (No Ad) -> Hovers right above Nav Bar (96)
            // If Free (Has Ad) -> Pushes up to clear the 50px Banner Ad (156)
            bottom: isPremium ? 96.0 : 156.0,
            left: 20,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: _showTooltip ? 1 : 0.95,
                duration: const Duration(milliseconds: 400),
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 400),
                  child: BouncingTipWidget(
                    text: 'Hold to open GPA Lab',
                    isActive: !_hasDiscoveredAppSwitcher && _showTooltip,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingIslandNav() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E1E1E).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            borderRadius: _navRadius,
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(isDark ? 0.25 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          child: RepaintBoundary(
            child: ClipRRect(
              borderRadius: _navRadius,
              child: BackdropFilter(
                filter: dart_ui.ImageFilter.blur(sigmaX: 9, sigmaY: 9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IslandNavItem(
                        index: 0,
                        selectedIndex: _selectedIndex,
                        icon: Icons.home_rounded,
                        label: 'Home',
                        onTap: () => _onItemTapped(0),
                        // ✨ LOGIC: Inform the app that they successfully held it down
                        onLongPress: () {
                          _markAppSwitcherDiscovered();
                          _showAppSwitcherMenu(context);
                        },
                      ),
                      IslandNavItem(
                        index: 1,
                        selectedIndex: _selectedIndex,
                        icon: Icons.insights_rounded,
                        label: 'Analysis',
                        onTap: () => _onItemTapped(1),
                      ),
                      IslandNavItem(
                        index: 2,
                        selectedIndex: _selectedIndex,
                        icon: Icons.rocket_launch_rounded,
                        label: 'Planner',
                        onTap: () => _onItemTapped(2),
                      ),
                      IslandNavItem(
                        index: 3,
                        selectedIndex: _selectedIndex,
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                        onTap: () => _onItemTapped(3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IslandNavItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const IslandNavItem({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 18 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.hintColor.withOpacity(0.6),
              size: 26,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
