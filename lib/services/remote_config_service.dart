import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'; // For ChangeNotifier
import 'dart:convert';

class RemoteConfigService with ChangeNotifier {
  // --- Singleton Pattern ---
  RemoteConfigService._privateConstructor();
  static final RemoteConfigService instance =
      RemoteConfigService._privateConstructor();
  // ---

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // --- Default value ---
  // This is the value used if fetching fails or before it completes.
  // Set it to `false` for maximum safety. If it can't reach Firebase,
  // it will default to ads OFF.
  // final Map<String, dynamic> _defaultValues = {'ads_enabled': false};

  final Map<String, dynamic> _defaultValues = {
    'ads_enabled': false,
    'app_open_ads_enabled': false,
    'interstitial_ads_enabled': false,
    'rewarded_ads_enabled': false,
    'native_ads_enabled': false,

    'new_user_grace_hours': 4,
    'new_user_calc_threshold': 8,
    'new_user_cooldown_minutes': 8,

    'latest_version_code': 1,
    'latest_version_name': '1.0.0',
    'update_url': '',
    'force_update': false,
    'whats_new_title': '',
    'whats_new_items': '[]',
    'min_supported_version_code': 1,

    'erp_attendance_logic':
        '{"version":1,"attended":{"present":1.0,"od":1.0,"makeup":1.0,"absent":0.0},"conducted":{"present":1.0,"od":0.0,"makeup":0.0,"absent":1.0}}',
  };

  // --- Getter ---
  bool get adsEnabled => _remoteConfig.getBool('ads_enabled');

  bool get appOpenEnabled =>
      adsEnabled && _remoteConfig.getBool('app_open_ads_enabled');

  bool get interstitialEnabled =>
      adsEnabled && _remoteConfig.getBool('interstitial_ads_enabled');

  bool get rewardedEnabled =>
      adsEnabled && _remoteConfig.getBool('rewarded_ads_enabled');

  bool get nativeEnabled =>
      adsEnabled && _remoteConfig.getBool('native_ads_enabled');

  int get newUserGraceHours => getInt('new_user_grace_hours');

  int get newUserCalcThreshold => getInt('new_user_calc_threshold');

  int get newUserCooldownMinutes => getInt('new_user_cooldown_minutes');

  int get minSupportedVersion =>
      _remoteConfig.getInt('min_supported_version_code');

  String get erpAttendanceLogic => getString('erp_attendance_logic');

  // --- ADD THESE METHODS ---
  int getInt(String key) {
    return _remoteConfig.getInt(key);
  }

  String getString(String key) {
    return _remoteConfig.getString(key);
  }

  bool getBool(String key) {
    // Good to have for consistency
    return _remoteConfig.getBool(key);
  }

  List<Map<String, dynamic>> getWhatsNewItems() {
    try {
      final raw = _remoteConfig.getString('whats_new_items');
      if (raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      return List<Map<String, dynamic>>.from(decoded);
    } catch (_) {
      return [];
    }
  }

  String get whatsNewTitle => _remoteConfig.getString('whats_new_title');

  // Duration get _newUserCooldown {
  //   final minutes = RemoteConfigService.instance.getInt(
  //     'new_user_cooldown_minutes',
  //   );

  //   return Duration(minutes: minutes == 0 ? 8 : minutes);
  // }

  Future<void> init() async {
    try {
      // 1. Set in-app default values
      await _remoteConfig.setDefaults(_defaultValues);

      // 2. Set config settings for fetching (e.g., how often to refresh)
      // For an emergency switch, you want a short refresh time.
      // For normal use, 12 hours is fine. Let's use 1 hour.
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          // This controls how long the app uses a cached value before
          // trying to fetch a new one.
          minimumFetchInterval: Duration(minutes: 15),
          // minimumFetchInterval: Duration.zero,
        ),
      );

      // 3. Fetch and Activate
      // await _remoteConfig.fetchAndActivate();

      // Notify listeners that the value might have updated
      notifyListeners();
    } catch (e) {
      debugPrint('RemoteConfig init failed: $e');
    }
  }

  Future<bool> fetchAndActivate() async {
    try {
      final updated = await _remoteConfig.fetchAndActivate();
      if (updated) notifyListeners();
      return updated;
    } catch (_) {
      return false;
    }
  }
}
