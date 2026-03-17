import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/settings_provider.dart';

// --- Imports for Pages and Toast ---
import 'package:bunkmate/screens/home_page.dart';
import 'package:bunkmate/screens/analysis_page.dart';
import 'package:bunkmate/screens/planner_page.dart';
import 'package:bunkmate/screens/settings_page.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const BorderRadius _navRadius = BorderRadius.all(Radius.circular(32));

  int _selectedIndex = 0;
  bool _launchActionCompleted = false;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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

  const IslandNavItem({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
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
