import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/navigation/app_visibility_service.dart';
import 'package:bunkmate/navigation/route_observer.dart';
import 'package:bunkmate/mixins/scroll_to_top_mixin.dart';
import 'package:bunkmate/coordinators/home_launch_coordinator.dart';

// New internal imports
import 'home_logic.dart';
import 'home_visuals.dart';
import 'home_helpers.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> with ScrollToTopMixin {
  // --- Controllers & Focus ---
  final TextEditingController targetPercentController = TextEditingController();
  final TextEditingController rawDataController = TextEditingController();
  final FocusNode targetFocusNode = FocusNode();

  // --- State Flags ---
  bool showRawDataInput = false;
  bool pulseResult = false;
  bool celebrationPlayed = false;
  bool isThemeUnlockInProgress = false;
  bool editingTarget = false;
  double dragAccumulator = 0;

  // --- Lifecycle & Orchestration Flags ---
  // bool scrolledAfterCalc = false;
  // bool calcTriggered = false;
  // bool scrollAfterPaste = false;
  bool routeSubscribed = false;
  bool isActive = false;

  final GlobalKey resultsKey = GlobalKey();
  SharedPreferences? prefs;

  @override
  void initState() {
    super.initState();
    context.read<AttendanceProvider>().addListener(_onProviderUpdate);

    AppVisibilityService.instance.onRouteVisible = () {
      if (!mounted) return;
      // context.read<AttendanceProvider>().resetOverlayFlag(); //check
      context.read<AdProvider>().cleanupExpiredAbsenceTrendUnlock();
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      prefs = await SharedPreferences.getInstance();
      HomeLogic.initializeControllers(this);

      // Await the launch coordinator
      await HomeLaunchCoordinator.handle(context: context, prefs: prefs!);

      // ADD THIS: If data loaded automatically on launch, jump to results
      // final provider = context.read<AttendanceProvider>();
      // if (provider.rawData.isNotEmpty && provider.result.totalConducted > 0) {
      //   HomeLogic.orchestrateScroll(this);
      // }
    });
  }

  void setActive(bool value) {
    isActive = value;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    isActive = route?.isCurrent ?? true;

    if (!routeSubscribed && route is PageRoute) {
      AppVisibilityService.instance.subscribe(routeObserver, route);
      routeSubscribed = true;
    }
  }

  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = resultsKey.currentContext;
      if (ctx == null) return;

      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    });
  }

  void _onProviderUpdate() {
    if (!mounted || !isActive || !AppVisibilityService.instance.isRouteVisible) return;

    final provider = Provider.of<AttendanceProvider>(context, listen: false);

    if (!provider.isLoading &&
        ((provider.result.dataParsedSuccessfully &&
                provider.result.totalConducted > 0) ||
            provider.isUnrecognizedFormat ||
            provider.errorMessage != null)) {
      _scrollToResults();
    }

    if (!provider.isLoading) {
      // 1. Run Success Logic first (this handles Haptics/Ads/Overlays)
      if (provider.result.dataParsedSuccessfully) {
        HomeLogic.handleSuccessState(this, provider, () {
          if (mounted) setState(() {});
        });
      }

      // 2. Run Scroll Logic SECOND
      // We check if data exists or if there is an error to show the user

      // if (provider.result.dataParsedSuccessfully ||
      //     provider.isUnrecognizedFormat ||
      //     provider.errorMessage != null) {
      //   // Scroll only if it was a user action (Paste or Calc)
      //   if (calcTriggered || scrollAfterPaste) {
      //     HomeLogic.orchestrateScroll(this);
      //   }
      // }
    }
  }

  @override
  void dispose() {
    AppVisibilityService.instance.unsubscribe(routeObserver);
    context.read<AttendanceProvider>().removeListener(_onProviderUpdate);
    targetPercentController.dispose();
    rawDataController.dispose();
    targetFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AttendanceProvider>();

    // Keep controllers in sync with provider data
    HomeLogic.syncControllersWithProvider(this, provider);

    return Scaffold(
      appBar: HomeVisuals.buildAppBar(this, context, provider),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeVisuals.buildInputCard(this, context, provider),
                    if (provider.rawData.isEmpty)
                      HomeVisuals.buildEmptyState(context),
                    const SizedBox(height: 16),
                    HomeVisuals.buildNativeAd(context),
                    const SizedBox(height: 16),
                    HomeVisuals.buildGaugeSection(this, context, provider),
                    const SizedBox(height: 22),
                    HomeVisuals.buildTargetCard(this, context, provider),
                    const SizedBox(height: 30),
                    HomeVisuals.buildResultsArea(this, context, provider),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          HomeVisuals.buildBottomBanner(context),
        ],
      ),
    );
  }
}
