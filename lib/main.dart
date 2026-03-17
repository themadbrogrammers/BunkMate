import 'package:bunkmate/screens/splash_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:bunkmate/firebase_options.dart';

// Providers
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/settings_provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';

// Screens
// import 'package:bunkmate/screens/main_screen.dart';

// Services
import 'package:bunkmate/services/hive_service.dart';
import 'package:bunkmate/services/notification_service.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/services/ad_lifecycle_observer.dart';
import 'package:bunkmate/services/ad_service.dart';
// import 'package:bunkmate/services/attendance_calculator.dart';

// Navigation
import 'package:bunkmate/navigation/route_observer.dart';

// Models
// import 'package:bunkmate/models/schedule_entry.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// =======================================================
/// BACKGROUND TASK — FAST, LIGHTWEIGHT ALERTS
/// =======================================================

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    const workTaskName = 'dailyAttendanceCheck8AM';

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await NotificationService.init();

      if (taskName != workTaskName) return Future.value(true);

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('proactive_alerts') ?? false;

      if (!enabled) return Future.value(true);

      final buffer = prefs.getInt('cached_max_droppable');
      final required = prefs.getInt('cached_required_attend');

      if (buffer == null || required == null) return Future.value(true);

      final appDir = await getApplicationDocumentsDirectory();
      await HiveService.init(appDir.path);

      final schedule = HiveService.getSchedule();
      final today = DateTime.now().weekday;
      final todaysClasses = schedule.where((e) => e.dayOfWeek == today).length;

      if (todaysClasses == 0) {
        if (Hive.isBoxOpen('schedule')) await Hive.close();
        return Future.value(true);
      }

      // SMART MESSAGE
      String title;
      int notificationId;

      if (required > 0) {
        title = '🚨 Danger Zone!';
        notificationId = 1001;
      } else if (buffer <= 2) {
        title = '⚠️ Caution!';
        notificationId = 1002;
      } else if (buffer >= 15) {
        title = '🏖️ Buffer Rich!';
        notificationId = 1003;
      } else {
        title = '📊 Attendance Update';
        notificationId = 1004;
      }

      String body;

      if (required > 0) {
        body =
            "$todaysClasses classes today. You must attend $required consecutive classes.";
      } else {
        final afterSkipBuffer = buffer - todaysClasses;

        if (afterSkipBuffer < 0) {
          body =
              "$todaysClasses classes today. 🚫 Do NOT bunk today or you'll fall below safe attendance.";
        } else if (afterSkipBuffer == 0) {
          body =
              "$todaysClasses classes today. ⚠️ Skipping all leaves ZERO buffer.";
        } else if (afterSkipBuffer >= todaysClasses) {
          body = "$todaysClasses classes today. ✅ You can safely bunk today.";
        } else {
          body =
              "$todaysClasses classes today. Skipping all leaves $afterSkipBuffer safe skips.";
        }
      }

      await NotificationService.showNotification(
        id: notificationId,
        title: title,
        body: body,
      );

      if (Hive.isBoxOpen('schedule')) await Hive.close();

      return Future.value(true);
    } catch (_) {
      if (Hive.isBoxOpen('schedule')) await Hive.close();
      return Future.value(false);
    }
  });
}

// bool _adsBootstrapped = false;

// void _bootstrapAdsFromRemoteConfig() {
//   if (_adsBootstrapped) return;

//   _adsBootstrapped = true;

//   // always preload
//   AdService.instance.loadAppOpenAd();

//   final rc = RemoteConfigService.instance;

//   if (!rc.adsEnabled) return;

//   if (rc.interstitialEnabled) {
//     AdService.instance.createInterstitialAd();
//   }

//   if (rc.rewardedEnabled) {
//     AdService.instance.createRewardedAd();
//   }
// }

bool _adsInitialized = false;

void _bootstrapAdsFromRemoteConfig() {
  final rc = RemoteConfigService.instance;

  if (!rc.adsEnabled) return;

  if (_adsInitialized) return;
  _adsInitialized = true;

  // preload always
  Future.delayed(const Duration(milliseconds: 400), () {
    AdService.instance.loadAppOpenAd();
  });

  if (rc.interstitialEnabled) {
    AdService.instance.createInterstitialAd();
  }

  if (rc.rewardedEnabled) {
    AdService.instance.createRewardedAd();
  }
}

/// =======================================================
/// MAIN — FAST, SAFE BOOTSTRAP
/// =======================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    // await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(
      PurchasesConfiguration("goog_KbCKzQPsACvgXDDrJEWPYDzmZkw"),
    );
    // final customerInfo = await Purchases.getCustomerInfo();
    // print("RC: entitlements = ${customerInfo.entitlements.all}");
    // print(
    //   "RC: transactions = ${customerInfo.nonSubscriptionTransactions.length}",
    // );
    // debugPrint("🚀 MY REVENUECAT USER ID: ${customerInfo.originalAppUserId}");
  } catch (e) {
    debugPrint("RevenueCat Init Error: $e");
  }

  final prefs = await SharedPreferences.getInstance();

  final appDir = await getApplicationDocumentsDirectory();
  await HiveService.init(appDir.path);

  await RemoteConfigService.instance.init();

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs: prefs)),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs: prefs)),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => PremiumProvider()..load()),
        ChangeNotifierProvider(create: (_) => AdProvider(prefs: prefs)),
      ],
      child: const AttendanceAlchemistApp(),
    ),
  );

  _initBackgroundServices();
}

/// =======================================================
/// NON-BLOCKING BACKGROUND INITIALIZATION
/// =======================================================
Future<void> _initBackgroundServices() async {
  try {
    // MobileAds.instance.initialize();
    // MobileAds.instance.updateRequestConfiguration(
    //   RequestConfiguration(testDeviceIds: ['6DD18E6C438BDBE680E9BD26F8B4B32B']),
    // );

    // RemoteConfigService.instance.addListener(() {
    //   final rc = RemoteConfigService.instance;

    //   if (!_adsInitialized && rc.adsEnabled) {
    //     _adsInitialized = true;

    //     if (rc.appOpenEnabled) {
    //       AdService.instance.loadAppOpenAd();
    //     }

    //     if (rc.interstitialEnabled) {
    //       AdService.instance.createInterstitialAd();
    //     }

    //     if (rc.rewardedEnabled) {
    //       AdService.instance.createRewardedAd();
    //     }
    //   }
    // });

    // RemoteConfigService.instance.addListener(_bootstrapAdsFromRemoteConfig);

    // cold start
    // _bootstrapAdsFromRemoteConfig();

    // AdLifecycleObserver();

    NotificationService.init();
  } catch (e) {
    debugPrint('Init error: $e');
  }
}

/// =======================================================
/// APP ROOT & DYNAMIC THEME ENGINE
/// =======================================================
class AttendanceAlchemistApp extends StatefulWidget {
  const AttendanceAlchemistApp({super.key});

  @override
  State<AttendanceAlchemistApp> createState() => _AttendanceAlchemistAppState();
}

class _AttendanceAlchemistAppState extends State<AttendanceAlchemistApp>
    with WidgetsBindingObserver {
  late final AdLifecycleObserver _adObserver;
  bool _themeResolved = false;
  bool _adsBooted = false;
  bool _lastPremium = false;
  bool _lastLoading = true;

  Future<void> _initAdsSafely() async {
    if (_adsBooted) return;
    _adsBooted = true;

    try {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: ['6DD18E6C438BDBE680E9BD26F8B4B32B'],
        ),
      );
      RemoteConfigService.instance.addListener(_bootstrapAdsFromRemoteConfig);
      _bootstrapAdsFromRemoteConfig();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1️⃣ Ads — AFTER first frame
      await _initAdsSafely();

      // 2️⃣ Lifecycle observer — AFTER context is stable
      _adObserver = AdLifecycleObserver(context);
    });
  }

  @override
  void dispose() {
    _adObserver.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_themeResolved) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final themeProvider = context.read<ThemeProvider>();
      final premium = context.read<PremiumProvider>();
      final adProvider = context.read<AdProvider>();

      // ❌ REMOVED the AdService sync from here because it was getting trapped!

      themeProvider.resolveStartupTheme(
        allowSavedTheme: premium.isPremium || adProvider.isDarkThemeUnlocked,
      );

      _themeResolved = true;
    });
  }

  // ✨ DYNAMIC LIGHT THEME GENERATOR
  ThemeData _buildLightTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: seedColor,
      scaffoldBackgroundColor: const Color(0xFFF9FAFB),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.black54),
      ),
    );
  }

  // ✨ DYNAMIC DARK THEME GENERATOR
  ThemeData _buildDarkTheme(Color seedColor) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: seedColor,
      scaffoldBackgroundColor: const Color(0xFF0D1117),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final premium = context.watch<PremiumProvider>();

    // Sync AdService only when values change
    if (premium.isLoadingPricing != _lastLoading ||
        premium.isPremium != _lastPremium) {
      AdService.instance.updatePremiumStatus(
        premium.isPremium,
        premium.isLoadingPricing,
      );

      context.read<AdProvider>().updatePremiumStatus(premium.isPremium);

      _lastPremium = premium.isPremium;
      _lastLoading = premium.isLoadingPricing;
    }

    final Color appSeedColor = premium.isPremium
        ? Colors.deepPurpleAccent
        : Colors.blue;

    return MaterialApp(
      title: premium.isPremium ? 'BunkER Pro' : 'BunkMate',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(appSeedColor),
      darkTheme: _buildDarkTheme(appSeedColor),
      themeMode: themeProvider.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 600),
      themeAnimationCurve: Curves.easeInOutCubic,
      navigatorObservers: [routeObserver],
      home: const SplashScreen(),
    );
  }
}
