import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:bunkmate/screens/main_screen.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/settings/settings_coordinator.dart';
import 'package:bunkmate/helpers/update_result.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:bunkmate/widgets/whats_new_list.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  // bool _animationFinished = false;
  // bool _minimumTimePassed = false;

  // Adjust duration as needed (e.g., 2-3 seconds total)
  final int _minSplashTimeMs = 1600; // Minimum time splash is visible
  final int _lottieDurationMs = 1500; // Expected duration of Lottie animation

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _lottieDurationMs),
    );

    // Timer(Duration(milliseconds: _minSplashTimeMs), () {
    //   if (!mounted)
    //     return; //Your timer runs even if the widget is disposed early.
    //   _minimumTimePassed = true;
    //   _navigateToHome();
    // });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final coordinator = SettingsCoordinator();

    // 🔥 HARD FETCH — NO CACHE
    await RemoteConfigService.instance.fetchAndActivate();
    final result = await coordinator.checkAppUpdate(allowCache: false);
    // final result = await coordinator.checkAppUpdate();

    if (!mounted) return;

    if (result == UpdateResult.force) {
      _showForceUpdateDialog();
      return;
    }

    // await Future.delayed(Duration(milliseconds: _minSplashTimeMs));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
    unawaited(RemoteConfigService.instance.fetchAndActivate());
  }

  // Future<void> _boot() async {
  //   final coordinator = SettingsCoordinator();
  //   // await RemoteConfigService.instance.init();

  //   final result = await coordinator.checkAppUpdate();

  //   if (!mounted) return;

  //   if (result == UpdateResult.force) {
  //     _showForceUpdateDialog();
  //     return; // 🚫 HARD STOP
  //   }

  //   await Future.delayed(Duration(milliseconds: _minSplashTimeMs));

  //   if (!mounted) return;

  //   Navigator.pushReplacement(
  //     context,
  //     PageRouteBuilder(
  //       pageBuilder: (_, __, ___) => const MainScreen(),
  //       transitionDuration: const Duration(milliseconds: 600),
  //       transitionsBuilder: (_, animation, __, child) =>
  //           FadeTransition(opacity: animation, child: child),
  //     ),
  //   );
  //   // unawaited(RemoteConfigService.instance.fetchAndActivate());
  // }

  void _showForceUpdateDialog() {
    final remote = RemoteConfigService.instance;

    final updateUrl = remote.getString('update_url');
    final latestVersion = remote.getString('latest_version_name');

    final whatsNewItems = remote.getWhatsNewItems();
    final whatsNewTitle = remote.whatsNewTitle.isNotEmpty
        ? remote.whatsNewTitle
        : 'What’s New ✨';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.red.shade900.withOpacity(0.45),
                          Colors.orange.shade800.withOpacity(0.18),
                        ]
                      : [
                          Colors.red.shade100.withOpacity(0.75),
                          Colors.orange.shade50.withOpacity(0.35),
                        ],
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 🔥 ICON
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.35),
                            blurRadius: 22,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.system_update_alt_rounded,
                        size: 42,
                        color: Colors.redAccent,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // 🔥 TITLE
                    Text(
                      'Update Required',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'This version of BunkMate is no longer supported.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.hintColor,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),

                    // VERSION BADGE
                    if (latestVersion.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          'Latest version $latestVersion',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // WHAT'S NEW
                    if (whatsNewItems.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          whatsNewTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      WhatsNewList(items: whatsNewItems),
                      const SizedBox(height: 22),
                    ],

                    // ACTION BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.flash_on_rounded),
                        label: const Text(
                          'Update Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () async {
                          if (updateUrl.isNotEmpty) {
                            await launchUrl(
                              Uri.parse(updateUrl),
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // void _navigateToHome() {
  //   // Navigate only if BOTH animation is done (or controller ready) AND minimum time passed
  //   if (_minimumTimePassed && mounted) {
  //     Navigator.of(context).pushReplacement(
  //       PageRouteBuilder(
  //         pageBuilder: (context, animation, secondaryAnimation) =>
  //             const MainScreen(),
  //         transitionDuration: const Duration(
  //           milliseconds: 600,
  //         ), // Adjust fade duration
  //         transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //           return FadeTransition(opacity: animation, child: child);
  //         },
  //       ),
  //     );
  //   }
  // }

  // void _navigateToHome() {
  //   if (!_minimumTimePassed || !mounted) return;

  //   // 🚫 If force update dialog is showing, do NOT navigate
  //   if (ModalRoute.of(context)?.isCurrent == false) {
  //     return;
  //   }

  //   Navigator.of(context).pushReplacement(
  //     PageRouteBuilder(
  //       pageBuilder: (context, animation, secondaryAnimation) =>
  //           const MainScreen(),
  //       transitionDuration: const Duration(milliseconds: 600),
  //       transitionsBuilder: (context, animation, secondaryAnimation, child) {
  //         return FadeTransition(opacity: animation, child: child);
  //       },
  //     ),
  //   );
  // }

  @override
  Widget build(BuildContext context) {
    // Get current theme brightness for potential color adjustments
    final Color backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      // Use Scaffold for background color matching theme
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- Your Lottie Animation ---
            Lottie.asset(
              'assets/animations/splash_animation.json', // Your animation file
              controller: _controller,
              height: 200, // Adjust size
              width: 200, // Adjust size
              repeat: true,
              onLoaded: (composition) {
                // Configure the AnimationController with the Lottie file's duration
                // Ensure controller duration matches Lottie duration
                _controller
                  ..duration = composition.duration
                  ..repeat();
              },
              // Optional: Handle errors if animation fails to load
              errorBuilder: (context, error, stackTrace) {
                // _animationFinished = true;
                // _navigateToHome();
                return const SizedBox(height: 200); // Placeholder size
              },
            ),
            // const SizedBox(height: 20),
            // // --- Optional: App Name ---
            // Text(
            //   'Attendance Alchemist',
            //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            //     fontWeight: FontWeight.bold,
            //     color: Theme.of(context).colorScheme.primary,
            //   ),
            // ),
            // const SizedBox(height: 80), // Space at the bottom
          ],
        ),
      ),
    );
  }
}
