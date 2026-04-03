import 'package:shared_preferences/shared_preferences.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomeLaunchCoordinator {
  static Future<void> handle({
    required BuildContext context,
    required SharedPreferences prefs,
  }) async {
    final provider = context.read<AttendanceProvider>();

    if (provider.rawData.isNotEmpty) return;

    final preference = prefs.getString('loadPreference') ?? 'none';

    if (preference == 'clipboard') {
      return;
    }

    if (preference == 'resume') {
      return;
    }
  }
}
