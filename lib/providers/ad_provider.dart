import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunkmate/services/remote_config_service.dart';

class AdProvider with ChangeNotifier {
  final SharedPreferences prefs;
  static const _firstInstallTimeKey = 'first_install_time';
  static const _lastAdShownDateKey = 'last_interstitial_date';
  static const _absenceTrendUnlockTimeKey = 'absence_trend_unlock_time';
  static const _holidayUnlockTimeKey = 'holiday_unlock_time';

  DateTime? _absenceTrendUnlockedAt;
  DateTime? _holidayUnlockedAt;

  Duration get _newUserGracePeriod {
    final hours = RemoteConfigService.instance.newUserGraceHours;

    return Duration(hours: hours);
  }

  AdProvider({required this.prefs}) {
    _initFirstInstallTime();
    _loadDailyUnlocks();
    _loadAbsenceTrendUnlock();
    _loadHolidayUnlock();
  }

  bool _isPremium = false;

  void updatePremiumStatus(bool value) {
    _isPremium = value;
  }

  void _loadAbsenceTrendUnlock() {
    final millis = prefs.getInt(_absenceTrendUnlockTimeKey);
    if (millis != null) {
      _absenceTrendUnlockedAt = DateTime.fromMillisecondsSinceEpoch(millis);
    }
  }

  void cleanupExpiredAbsenceTrendUnlock() {
    if (_absenceTrendUnlockedAt == null) return;

    if (DateTime.now().difference(_absenceTrendUnlockedAt!).inMinutes >= 60) {
      _absenceTrendUnlockedAt = null;
      prefs.remove(_absenceTrendUnlockTimeKey);
      notifyListeners();
    }
  }

  // --- Holiday Analysis Unlock Logic ---
  void _loadHolidayUnlock() {
    final millis = prefs.getInt(_holidayUnlockTimeKey);
    if (millis != null) {
      _holidayUnlockedAt = DateTime.fromMillisecondsSinceEpoch(millis);
    }
  }

  bool get isHolidayAnalysisUnlocked {
    if (_holidayUnlockedAt == null) return false;
    final diff = DateTime.now().difference(_holidayUnlockedAt!);
    return diff.inMinutes < 60; // Unlocked for 60 minutes
  }

  Future<void> unlockHolidayAnalysisForOneHour() async {
    _holidayUnlockedAt = DateTime.now();
    await prefs.setInt(
      _holidayUnlockTimeKey,
      _holidayUnlockedAt!.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  static const _darkUnlockDateKey = 'dark_theme_unlock_date';

  bool _isDarkThemeUnlocked = false;
  bool get isDarkThemeUnlocked => _isDarkThemeUnlocked;
  bool _hasShownInterstitialThisSession = false;

  void resetSession() {
    _hasShownInterstitialThisSession = false;
    _calculationsSinceAd = 0;
  }

  // --- Absence Trend (SESSION ONLY) ---
  // bool _isAbsenceTrendUnlocked = false;
  // bool get isAbsenceTrendUnlocked => _isAbsenceTrendUnlocked;
  bool get isAbsenceTrendUnlocked {
    if (_absenceTrendUnlockedAt == null) return false;

    final diff = DateTime.now().difference(_absenceTrendUnlockedAt!);

    return diff.inMinutes < 60;
  }

  bool get isNewUser {
    final ts = prefs.getInt(_firstInstallTimeKey);
    if (ts == null) return false;

    final install = DateTime.fromMillisecondsSinceEpoch(ts);

    return DateTime.now().difference(install) < _newUserGracePeriod;
  }

  void _initFirstInstallTime() {
    if (!prefs.containsKey(_firstInstallTimeKey)) {
      prefs.setInt(_firstInstallTimeKey, DateTime.now().millisecondsSinceEpoch);
    }
  }

  // void unlockAbsenceTrend() {
  //   if (_isAbsenceTrendUnlocked) return;
  //   _isAbsenceTrendUnlocked = true;
  //   notifyListeners();
  // }

  Future<void> unlockAbsenceTrendForOneHour() async {
    _absenceTrendUnlockedAt = DateTime.now();

    await prefs.setInt(
      _absenceTrendUnlockTimeKey,
      _absenceTrendUnlockedAt!.millisecondsSinceEpoch,
    );

    notifyListeners();
  }

  void _loadDailyUnlocks() {
    final today = _todayKey();
    _isDarkThemeUnlocked = prefs.getString(_darkUnlockDateKey) == today;
  }

  void unlockDarkThemeForToday() {
    prefs.setString(_darkUnlockDateKey, _todayKey());
    _isDarkThemeUnlocked = true;
    notifyListeners();
  }

  void refreshDailyUnlocks() {
    _loadDailyUnlocks();
    notifyListeners();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  bool _trendHintShown = false;
  bool get trendHintShown => _trendHintShown;

  void markTrendHintShown() {
    if (_trendHintShown) return;
    _trendHintShown = true;
    notifyListeners();
  }

  int _calculationsSinceAd = 0;
  static const int _normalCalcThreshold = 3;

  int get _newUserCalcThreshold {
    final value = RemoteConfigService.instance.newUserCalcThreshold;

    return value;
  }

  static const int _maxAdsPerDay = 19;

  int get _calculationThreshold {
    return isNewUser ? _newUserCalcThreshold : _normalCalcThreshold;
  }

  DateTime? _lastInterstitialShowTime;
  static const Duration _normalCooldown = Duration(minutes: 3);
  Duration get _newUserCooldown {
    final minutes = RemoteConfigService.instance.newUserCooldownMinutes;

    return Duration(minutes: minutes);
  }

  Duration get _cooldown {
    return isNewUser ? _newUserCooldown : _normalCooldown;
  }

  void incrementCalculationCounter() {
    _calculationsSinceAd++;
  }

  bool get _canShowAdToday {
    final today = _todayKey();
    final last = prefs.getString(_lastAdShownDateKey);

    if (last != today) {
      prefs.setInt('ads_today_interstitial', 0);
      prefs.setString(_lastAdShownDateKey, today);
    }

    final count = prefs.getInt('ads_today_interstitial') ?? 0;
    return count < _maxAdsPerDay;
  }

  void _markAdShown() {
    final count = prefs.getInt('ads_today_interstitial') ?? 0;
    prefs.setInt('ads_today_interstitial', count + 1);
  }

  bool get allowAppOpenAd {
    if (_isPremium) return false;

    final rc = RemoteConfigService.instance;
    if (!rc.appOpenEnabled) return false;

    final ts = prefs.getInt(_firstInstallTimeKey);
    if (ts == null) return true;

    final install = DateTime.fromMillisecondsSinceEpoch(ts);

    // full grace window applies to app open ads
    if (DateTime.now().difference(install) < _newUserGracePeriod) {
      return false;
    }

    return true;
  }

  bool get shouldShowInterstitial {
    if (_isPremium) return false;

    final ts = prefs.getInt(_firstInstallTimeKey);
    if (ts != null) {
      final install = DateTime.fromMillisecondsSinceEpoch(ts);

      // First 70% of grace window → ZERO ads
      if (DateTime.now().difference(install) < _newUserGracePeriod * 0.3) {
        return false;
      }
    }

    final rc = RemoteConfigService.instance;
    if (!rc.interstitialEnabled) return false;

    final now = DateTime.now();

    if (!_canShowAdToday) return false;

    if (!_hasShownInterstitialThisSession &&
        _calculationsSinceAd < _calculationThreshold + 2) {
      return false;
    }

    if (_calculationsSinceAd < _calculationThreshold) {
      return false;
    }

    if (_lastInterstitialShowTime != null) {
      final diff = now.difference(_lastInterstitialShowTime!);
      if (diff < _cooldown) return false;
    }

    _calculationsSinceAd = 0;
    _lastInterstitialShowTime = now;
    _hasShownInterstitialThisSession = true;

    _markAdShown();

    return true;
  }
}
