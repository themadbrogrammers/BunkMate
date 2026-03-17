import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart'; // Required for kDebugMode
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bunkmate/helpers/toast_helper.dart'; // Optional: for error messages
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/navigation/app_visibility_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class AdService {
  // --- Singleton Pattern ---
  AdService._privateConstructor();
  static final AdService instance = AdService._privateConstructor();

  final ValueNotifier<bool> nativeAdLoaded = ValueNotifier(false);

  InterstitialAd? _interstitialAd;
  int _interstitialLoadAttempts = 0;
  final int _maxInterstitialLoadAttempts = 3;

  RewardedAd? _rewardedAd;
  int _rewardedLoadAttempts = 0;
  final int _maxRewardedLoadAttempts = 3;

  AppOpenAd? _appOpenAd;
  bool _isShowingAppOpenAd = false;
  DateTime? _lastAppOpenShown;
  DateTime? _lastFullscreenAdTime;
  Timer? _rewardedReloadTimer;

  static const Duration _minGapBetweenAppOpenAds = Duration(minutes: 5);

  bool _isPremium = false;
  bool _isLoadingPricing = true;
  bool _fullscreenShowing = false;
  bool get isFullscreenShowing => _fullscreenShowing;
  bool get isInterstitialReady => _interstitialAd != null;

  void updatePremiumStatus(bool isPremium, bool isLoading) {
    _isPremium = isPremium;
    _isLoadingPricing = isLoading; // Sync the lock

    if (_isPremium) {
      _appOpenAd?.dispose();
      _appOpenAd = null;

      _rewardedReloadTimer?.cancel();
      _rewardedAd?.dispose();
      _rewardedAd = null;
    }
  }

  // --- Ad Unit IDs ---
  // IMPORTANT: REPLACE WITH YOUR ACTUAL IDs BEFORE RELEASE
  // Use Test IDs during development: https://developers.google.com/admob/android/test-ads

  // --- ANDROID ---

  static final String _androidBannerIdHome = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/4105700579'
      : '';
  static final String _androidBannerIdAnalysis = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/4105700579'
      : '';
  static final String _androidBannerIdPlanner = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/4105700579'
      : '';
  static final String _androidBannerIdSchedule = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/4105700579'
      : '';

  static final String _androidInterstitialId = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/8948730078'
      : '';
  static final String _androidRewardedId = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/1479537235'
      : '';

  static final String _androidAppOpenId = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/7797533575'
      : '';

  static final String _androidNativeId = Platform.isAndroid
      ? 'ca-app-pub-9604718472722741/4161540896'
      : '';

  // --- iOS ---
  static final String _iosBannerIdHome = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/HOME_BANNER_IOS' // <-- REPLACE
      : '';
  static final String _iosBannerIdAnalysis = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/ANALYSIS_BANNER_IOS' // <-- REPLACE
      : '';
  static final String _iosBannerIdPlanner = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/PLANNER_BANNER_IOS' // <-- REPLACE
      : '';

  static final String _iosInterstitialId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/INTERSTITIAL_IOS' // <-- REPLACE
      : '';
  static final String _iosRewardedId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/REWARDED_IOS' // <-- REPLACE
      : '';

  static final String _iosAppOpenId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/APP_OPEN_IOS'
      : '';

  static final String _iosNativeId = Platform.isIOS
      ? 'ca-app-pub-YOUR_PUB_ID/NATIVE_IOS'
      : '';

  // --- Getters for Platform Specific IDs ---
  String get homeBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdHome : _iosBannerIdHome;
  String get analysisBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdAnalysis : _iosBannerIdAnalysis;
  String get plannerBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdPlanner : _iosBannerIdPlanner;
  String get scheduleBannerAdUnitId =>
      Platform.isAndroid ? _androidBannerIdSchedule : _iosBannerIdPlanner;

  String get interstitialAdUnitId =>
      Platform.isAndroid ? _androidInterstitialId : _iosInterstitialId;
  String get rewardedAdUnitId =>
      Platform.isAndroid ? _androidRewardedId : _iosRewardedId;

  String get appOpenAdUnitId =>
      Platform.isAndroid ? _androidAppOpenId : _iosAppOpenId;

  String get nativeAdUnitId =>
      Platform.isAndroid ? _androidNativeId : _iosNativeId;

  // --- Interstitial Ad Logic ---
  void createInterstitialAd() {
    if (!RemoteConfigService.instance.interstitialEnabled) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          _interstitialAd?.fullScreenContentCallback =
              _buildInterstitialCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitialLoadAttempts++;
          _interstitialAd = null;
          if (_interstitialLoadAttempts <= _maxInterstitialLoadAttempts) {
            Future.delayed(
              Duration(seconds: 2 * _interstitialLoadAttempts),
              createInterstitialAd,
            );
            // Retry loading
          }
        },
      ),
    );
  }

  FullScreenContentCallback<InterstitialAd> _buildInterstitialCallbacks() {
    return FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullscreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullscreenShowing = false;
        _lastFullscreenAdTime = DateTime.now();
        ad.dispose();
        createInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullscreenShowing = false;
        ad.dispose();
        createInterstitialAd();
      },
    );
  }

  void showInterstitialAd() {
    if (_fullscreenShowing) return;
    if (!RemoteConfigService.instance.interstitialEnabled) return;

    if (_interstitialAd == null) {
      if (_interstitialLoadAttempts <= _maxInterstitialLoadAttempts) {
        createInterstitialAd();
      }
      return;
    }
    final ad = _interstitialAd;
    if (ad == null) return;

    _interstitialAd = null;
    ad.show();
  }

  // --- Rewarded Ad Logic ---
  void createRewardedAd() {
    if (!RemoteConfigService.instance.rewardedEnabled) return;

    // already loaded → do nothing
    if (_rewardedAd != null) return;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;

          // 🔁 reward ads silently expire after ~1 hour
          // preload again BEFORE that happens
          _rewardedReloadTimer?.cancel();
          _rewardedReloadTimer = Timer(const Duration(minutes: 50), () {
            _rewardedAd?.dispose();
            _rewardedAd = null;
            createRewardedAd();
          });
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewardedAd = null;
          _rewardedLoadAttempts++;

          if (_rewardedLoadAttempts <= _maxRewardedLoadAttempts) {
            Future.delayed(
              Duration(seconds: 2 * _rewardedLoadAttempts),
              createRewardedAd,
            );
          }
        },
      ),
    );
  }

  void showRewardedAd({required VoidCallback onReward}) {
    if (!RemoteConfigService.instance.rewardedEnabled) {
      onReward(); // still unlock feature
      return;
    }

    if (_rewardedAd == null) {
      createRewardedAd();
      showErrorToast('Preparing ad… try again in a moment.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullscreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullscreenShowing = false;
        _lastFullscreenAdTime = DateTime.now();
        ad.dispose();
        createRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullscreenShowing = false;
        ad.dispose();
        createRewardedAd();
      },
    );

    // Set immersive mode before showing
    // _rewardedAd!.setImmersiveMode(true); // Uncomment if needed

    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        onReward(); // <<< Execute the reward callback
      },
    );
    _rewardedAd = null; // Ad is consumed
  }

  void loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          // debugPrint('✅ APP OPEN AD LOADED');
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          _appOpenAd = null;

          // 🔁 retry with backoff
          Future.delayed(const Duration(minutes: 3), loadAppOpenAd);
        },
      ),
    );
  }

  Future<void> showAppOpenAdIfAvailable() async {
    // ✨ FIX: Physical lock. Refuse to show if they are Pro OR if RC is still checking!
    if (_isPremium || _isLoadingPricing) return;

    if (!RemoteConfigService.instance.appOpenEnabled) return;
    if (_appOpenAd == null) return;
    if (_isShowingAppOpenAd) return;

    final prefs = await SharedPreferences.getInstance();

    final today = DateTime.now();
    final todayKey = '${today.year}-${today.month}-${today.day}';

    final lastDate = prefs.getString('last_app_open_date');

    if (lastDate != todayKey) {
      prefs.setString('last_app_open_date', todayKey);
      prefs.setInt('ads_today_app_open', 0);
    }

    final count = prefs.getInt('ads_today_app_open') ?? 0;
    if (count >= 8) return;

    if (_lastAppOpenShown != null &&
        DateTime.now().difference(_lastAppOpenShown!) <
            _minGapBetweenAppOpenAds) {
      return;
    }

    _isShowingAppOpenAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        _fullscreenShowing = true;
      },
      onAdDismissedFullScreenContent: (ad) {
        _fullscreenShowing = false;
        _lastFullscreenAdTime = DateTime.now();
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        _lastAppOpenShown = DateTime.now();
        loadAppOpenAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _fullscreenShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _isShowingAppOpenAd = false;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();

    prefs.setInt('ads_today_app_open', count + 1);
  }

  void onAppResumed(BuildContext context) {
    // ✨ FIX: Duplicate the physical lock here to prevent premature triggering
    if (_isPremium || _isLoadingPricing) return;

    if (!RemoteConfigService.instance.appOpenEnabled) return;
    if (_fullscreenShowing) return;

    final adProvider = context.read<AdProvider>();

    if (!adProvider.allowAppOpenAd) return;

    if (_lastFullscreenAdTime != null &&
        DateTime.now().difference(_lastFullscreenAdTime!) <
            const Duration(seconds: 45)) {
      return;
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      showAppOpenAdIfAvailable();
    });
  }
}
