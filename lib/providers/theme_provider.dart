import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  final SharedPreferences prefs;

  static const _themePrefKey = 'user_theme';

  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  bool _startupResolved = false;

  // void resolveStartupTheme({required bool allowSavedTheme}) {
  //   if (_startupResolved) return;
  //   _startupResolved = true;

  //   loadSavedTheme();
  //   if (!allowSavedTheme && _themeMode == ThemeMode.dark) {
  //     _themeMode = ThemeMode.light;
  //     notifyListeners();
  //   }
  // } //checkdarmode

  void resolveStartupTheme({bool allowSavedTheme = true}) {
    if (_startupResolved) return;
    _startupResolved = true;

    loadSavedTheme();
  }

  ThemeProvider({required this.prefs});

  void loadSavedTheme() {
    final saved = prefs.getString(_themePrefKey);

    _themeMode = saved == 'dark' ? ThemeMode.dark : ThemeMode.light;

    notifyListeners();
  }

  void applyTheme(ThemeMode mode, {bool persist = false}) {
    _themeMode = mode;

    if (persist) {
      prefs.setString(_themePrefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }

    notifyListeners();
  }

  void toggleTheme({bool persist = false}) {
    applyTheme(isDarkMode ? ThemeMode.light : ThemeMode.dark, persist: persist);
  }
}
