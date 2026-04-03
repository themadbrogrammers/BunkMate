import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

enum AppLaunchOption { resume, clipboard, none }

class SettingsProvider with ChangeNotifier {
  final SharedPreferences prefs;

  static const String launchOptionKey = 'launchOption';
  static const String showResultOverlayKey = 'showOverlay';
  static const String proactiveAlertsKey = 'proactiveAlerts';
  static const String defaultTargetKey = 'defaultTarget';

  AppLaunchOption _launchOption = AppLaunchOption.resume; // Default to resume
  AppLaunchOption get launchOption => _launchOption;

  bool _showResultOverlay = true; // Default value
  bool get showResultOverlay => _showResultOverlay;

  bool _proactiveAlerts = false; // Default value
  bool get proactiveAlerts => _proactiveAlerts;

  int _defaultTarget = 75; // ✨ NEW: Default to 75%
  int get defaultTarget => _defaultTarget;

  // --- Initialization State ---
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  final Completer<void> _initCompleter = Completer<void>();
  Future<void> get initializationComplete => _initCompleter.future;

  SettingsProvider({required this.prefs}) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      String savedLaunchOptionName =
          prefs.getString(launchOptionKey) ?? AppLaunchOption.resume.name;

      _launchOption = AppLaunchOption.values.firstWhere(
        (e) => e.name == savedLaunchOptionName,
        orElse: () => AppLaunchOption.resume,
      );

      _showResultOverlay =
          prefs.getBool(showResultOverlayKey) ?? true; // Default true

      _proactiveAlerts =
          prefs.getBool(proactiveAlertsKey) ?? false; // Default false

      _defaultTarget = prefs.getInt(defaultTargetKey) ?? 75;

      _isInitialized = true;
      debugPrint(
        "Settings Loaded: Launch Option = $_launchOption, Target = $_defaultTarget%",
      );

      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }

      notifyListeners();

      // Optional: Show toast based on initial load (might be annoying, consider removing)
      // if (_launchOption == AppLaunchOption.resume) {
      //   showTopToast("🔄 Resumed last save");
      // } else if (_launchOption == AppLaunchOption.clipboard) {
      //   showTopToast("📋 Pasting from clipboard");
      // }
    } catch (e, stacktrace) {
      debugPrint("Error loading settings: $e\n$stacktrace");
      _launchOption = AppLaunchOption.resume;
      _showResultOverlay = true;
      _proactiveAlerts = false;
      _isInitialized = true;

      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e, stacktrace); // Signal error
      }
      notifyListeners();
    }
  }

  // --- Update Methods ---
  Future<void> setLaunchOption(AppLaunchOption option) async {
    if (_launchOption != option) {
      _launchOption = option;
      await prefs.setString(launchOptionKey, option.name);
      showTopToast("Launch Option set to ${option.name}");
      notifyListeners();
    }
  }

  Future<void> setShowResultOverlay(bool show) async {
    if (_showResultOverlay != show) {
      _showResultOverlay = show;
      await prefs.setBool(showResultOverlayKey, show);
      notifyListeners();
    }
  }

  Future<void> setProactiveAlerts(bool show) async {
    if (_proactiveAlerts != show) {
      _proactiveAlerts = show;
      await prefs.setBool(proactiveAlertsKey, show);
      notifyListeners();
      // Remember: Logic to register/cancel the background task is in SettingsPage's _onProactiveAlertsChanged
    }
  }

  Future<void> setDefaultTarget(int target) async {
    if (_defaultTarget != target && target >= 0 && target <= 100) {
      _defaultTarget = target;
      await prefs.setInt(defaultTargetKey, target);
      notifyListeners();
    }
  }

  Future<void> resetAllSettings() async {
    // Clear all preferences managed by this app.
    // Be careful if other parts of the app use SharedPreferences independently.
    // Consider removing specific keys instead of clear() if necessary.
    // await prefs.remove(launchOptionKey);
    // await prefs.remove(showResultOverlayKey);
    // await prefs.remove(proactiveAlertsKey);
    // Add removes for any other settings keys used ONLY by this provider.

    // A full clear might be okay if this provider manages ALL settings.
    await prefs.clear();

    // Reload settings, which will apply defaults and notify listeners
    await _loadSettings();
    showTopToast("Settings reset to defaults"); // User feedback
  }
}
