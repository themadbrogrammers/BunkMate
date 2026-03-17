import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:workmanager/workmanager.dart';

import 'package:bunkmate/providers/settings_provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/helpers/update_result.dart';
import 'package:bunkmate/helpers/update_cache.dart';
import 'package:bunkmate/services/notification_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsCoordinator {
  bool _isUnlockingDarkMode = false;

  // ----------------------------
  // UPDATE CHECK
  // ----------------------------
  // Future<void> checkForUpdates({
  //   required BuildContext context,
  //   required VoidCallback onStart,
  //   required VoidCallback onFinish,
  //   required void Function(String latestVersion, String url, bool forceUpdate)
  //   onUpdateAvailable,
  // }) async {
  //   onStart();

  //   try {
  //     final currentInfo = await PackageInfo.fromPlatform();
  //     final currentCode = int.tryParse(currentInfo.buildNumber) ?? 0;

  //     await RemoteConfigService.instance.fetchAndActivate();

  //     final latestCode = RemoteConfigService.instance.getInt(
  //       'latest_version_code',
  //     );
  //     final latestName = RemoteConfigService.instance.getString(
  //       'latest_version_name',
  //     );
  //     final updateUrl = RemoteConfigService.instance.getString('update_url');

  //     final forceUpdate = RemoteConfigService.instance.getBool('force_update');

  //     if (latestCode > currentCode && latestCode > 0) {
  //       onUpdateAvailable(latestName, updateUrl, forceUpdate);
  //     } else {
  //       showTopToast('✅ You have the latest version (${currentInfo.version})');
  //     }
  //   } catch (_) {
  //     showErrorToast('Could not check for updates.');
  //   } finally {
  //     onFinish();
  //   }
  // }
  static const updateCacheTTL = Duration(hours: 6);

  Future<UpdateResult> checkAppUpdate({bool allowCache = true}) async {
    final prefs = await SharedPreferences.getInstance();

    // ----------------------------
    // 1️⃣ Read cache
    // ----------------------------
    final cachedResult = prefs.getString(UpdateCacheKeys.result);
    final checkedAtMs = prefs.getInt(UpdateCacheKeys.checkedAt);
    final cachedBuild = prefs.getString('cached_build_number');

    // ----------------------------
    // 2️⃣ Get current app version
    // ----------------------------
    final info = await PackageInfo.fromPlatform();
    final currentBuild = info.buildNumber;
    final currentCode = int.tryParse(currentBuild) ?? 0;

    // ----------------------------
    // 3️⃣ Invalidate cache on update
    // ----------------------------
    if (cachedBuild != currentBuild) {
      await prefs.remove(UpdateCacheKeys.result);
      await prefs.remove(UpdateCacheKeys.checkedAt);
      await prefs.remove(UpdateCacheKeys.latestCode);
      await prefs.setString('cached_build_number', currentBuild);
    }

    // ----------------------------
    // 4️⃣ Use cache if valid
    // ----------------------------
    if (allowCache &&
        cachedResult != null &&
        checkedAtMs != null &&
        cachedBuild == currentBuild) {
      final checkedAt = DateTime.fromMillisecondsSinceEpoch(checkedAtMs);

      if (DateTime.now().difference(checkedAt) < updateCacheTTL) {
        return UpdateResult.from(cachedResult);
      }
    }

    // ----------------------------
    // 5️⃣ Live remote fetch
    // ----------------------------
    // if (!allowCache) {
    // await RemoteConfigService.instance.fetchAndActivate();
    // }

    final remote = RemoteConfigService.instance;

    final minSupported = remote.minSupportedVersion;
    final latestCode = remote.getInt('latest_version_code');
    final forceFlag = remote.getBool('force_update');

    late UpdateResult result;

    if (currentCode < minSupported) {
      result = UpdateResult.force;
    } else if (forceFlag && currentCode < latestCode) {
      result = UpdateResult.force;
    } else if (currentCode < latestCode) {
      result = UpdateResult.optional;
    } else {
      result = UpdateResult.none;
    }

    // ----------------------------
    // 6️⃣ Cache result
    // ----------------------------
    if (result != UpdateResult.force) {
      await prefs.setString(UpdateCacheKeys.result, result.value);
    }

    await prefs.setInt(
      UpdateCacheKeys.checkedAt,
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setInt(UpdateCacheKeys.latestCode, latestCode);

    return result;
  }

  void toggleDarkModeWithTease({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required AdProvider adProvider,
    required bool mounted,
    required VoidCallback showUnlockDialog,
  }) {
    // 🛑 HARD STOP: block spam
    if (_isUnlockingDarkMode) return;
    _isUnlockingDarkMode = true;

    final bool currentlyDark = themeProvider.isDarkMode;
    final bool tryingToTurnOn = !currentlyDark;

    HapticFeedback.lightImpact();

    try {
      // ✅ Turning OFF is always allowed
      if (!tryingToTurnOn) {
        themeProvider.applyTheme(ThemeMode.light, persist: true);
        return;
      }

      // ✅ Already unlocked
      if (adProvider.isDarkThemeUnlocked) {
        themeProvider.applyTheme(ThemeMode.dark, persist: true);
        return;
      }

      // 👀 PREVIEW (temporary, non-persistent)
      final originalTheme = themeProvider.themeMode;
      themeProvider.applyTheme(ThemeMode.dark);

      Future.delayed(const Duration(milliseconds: 1010), () {
        if (!mounted) return;

        // 🔍 Re-check lock state (important)
        final stillLocked = !context.read<AdProvider>().isDarkThemeUnlocked;
        if (!stillLocked) return;

        // 🔄 Revert
        themeProvider.applyTheme(originalTheme);

        // 🎬 Show unlock dialog after revert settles
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          FocusScope.of(context).unfocus();
          showUnlockDialog();
        });
      });
    } finally {
      // 🔓 Release lock slightly after flow finishes
      Future.delayed(const Duration(milliseconds: 1400), () {
        _isUnlockingDarkMode = false;
      });
    }
  }

  // ----------------------------
  // PROACTIVE ALERTS
  // ----------------------------
  void toggleProactiveAlerts(bool value, SettingsProvider provider) async {
    HapticFeedback.lightImpact();

    const taskName = 'dailyAttendanceCheck8AM';
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      final granted = await NotificationService.requestPermissionIfNeeded();

      if (!granted) {
        showErrorToast('Notification permission denied');
        await prefs.setBool('proactive_alerts', false);
        provider.setProactiveAlerts(false);
        return;
      }

      final now = DateTime.now();
      DateTime next8AM = DateTime(now.year, now.month, now.day, 8);
      if (now.isAfter(next8AM)) {
        next8AM = next8AM.add(const Duration(days: 1));
      }

      await Workmanager().registerPeriodicTask(
        taskName,
        taskName,
        frequency: const Duration(hours: 24),
        initialDelay: next8AM.difference(now),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );

      await Workmanager().registerOneOffTask(
        "debug_test_notification",
        "dailyAttendanceCheck8AM",
        initialDelay: const Duration(minutes: 5),
      );

      await prefs.setBool('proactive_alerts', true);
      provider.setProactiveAlerts(true);
      showTopToast('Proactive Alerts Enabled.');

      await NotificationService.showNotification(
        id: 999,
        title: 'Alerts Enabled ✅',
        body:
            'You will now receive smart attendance alerts on the mornings you have classes!',
      );
    } else {
      await Workmanager().cancelByUniqueName(taskName);
      await prefs.setBool('proactive_alerts', false);
      provider.setProactiveAlerts(false);
      showTopToast('Alerts Disabled.');
    }
  }
}
