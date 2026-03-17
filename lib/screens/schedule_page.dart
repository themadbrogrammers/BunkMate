import 'dart:ui' as dart_ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // ✨ NEW: For parsing dates into days of the week

import 'package:bunkmate/models/schedule_entry.dart';
import 'package:bunkmate/services/hive_service.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/widgets/banner_ad_widget.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/helpers/button_color_extensions.dart';

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  bool _isDeleting = false;
  bool _showGestureHint = false;

  List<ScheduleEntry> _schedule = [];
  final Map<int, String> _dayMap = {
    1: 'Monday',
    2: 'Tuesday',
    3: 'Wednesday',
    4: 'Thursday',
    5: 'Friday',
    6: 'Saturday',
    7: 'Sunday',
  };

  final Map<int, Color> _dayColors = {
    1: Colors.purpleAccent,
    2: Colors.blueAccent,
    3: Colors.tealAccent.shade700,
    4: Colors.greenAccent.shade700,
    5: Colors.orangeAccent,
    6: Colors.redAccent,
    7: Colors.pinkAccent,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    _loadSchedule();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_schedule_gesture_hint') ?? false;
      if (!seen && _schedule.length <= 2) {
        setState(() => _showGestureHint = true);
      }
    });
  }

  void _loadSchedule() {
    setState(() {
      _schedule = HiveService.getSchedule();
      if (_schedule.length > 2) _showGestureHint = false;
    });
  }

  // ✨ THE MAGIC AUTO-SYNC ENGINE ✨
  Future<void> _autoSyncSchedule(BuildContext context) async {
    final theme = Theme.of(context);
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final rawData = provider.rawData;

    if (rawData.trim().isEmpty) {
      showErrorToast('No data found! Please paste your attendance data first.');
      return;
    }

    HapticFeedback.mediumImpact();
    showTopToast('⏳ Scanning latest week...');

    final lines = rawData
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final headerIdx = lines.indexWhere(
      (l) => l.toLowerCase().contains('subject'),
    );

    if (headerIdx == -1 || lines.length <= headerIdx + 1) {
      showErrorToast('Could not find valid subject data to sync.');
      return;
    }

    final splitter = RegExp(r'\t| {2,}|,(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)');
    final headers = lines[headerIdx]
        .split(splitter)
        .map((h) => h.trim().toLowerCase())
        .toList();

    int subIdx = headers.indexWhere(
      (h) => h == 'subject name' || h == 'subject',
    );
    int dateIdx = headers.indexWhere((h) => h == 'date');
    int timeIdx = headers.indexWhere(
      (h) => h == 'starting time' || h == 'time',
    );

    if (subIdx == -1 || dateIdx == -1 || timeIdx == -1) {
      showErrorToast('Requires Subject, Date, and Time columns to auto-sync.');
      return;
    }

    final dateFormats = [
      DateFormat("yyyy-MM-dd"),
      DateFormat("dd-MM-yyyy"),
      DateFormat("d-M-yyyy"),
      DateFormat("MM/dd/yyyy"),
      DateFormat("M/d/yyyy"),
    ];

    // 1. Extract all valid classes with their specific Dates
    List<Map<String, dynamic>> allParsedClasses = [];

    for (int i = headerIdx + 1; i < lines.length; i++) {
      final values = lines[i].split(splitter).map((v) => v.trim()).toList();
      if (values.length <= [subIdx, dateIdx, timeIdx].reduce(max)) continue;

      final subject = values[subIdx];
      if (subject.isEmpty || subject.toLowerCase().contains('subject')) {
        continue;
      }

      // ✨ SMART FILTER: Ignore makeup classes so they don't pollute the weekly schedule
      if (subject.toUpperCase().contains('MAKEUP')) continue;
      if (values.any((v) => v.toUpperCase() == 'MAKEUP')) continue;

      // EXTRACT DATE & DAY OF WEEK
      final dateStr = values[dateIdx].toLowerCase();
      DateTime? rowDate;
      int dayOfWeek = -1;

      final dateRegex = RegExp(r'\d{2,4}[-/]\d{1,2}[-/]\d{2,4}');
      final match = dateRegex.firstMatch(dateStr);
      if (match != null) {
        final cleanDate = match.group(0)!.replaceAll(RegExp(r'[./]'), '-');
        for (var f in dateFormats) {
          try {
            rowDate = f.parseStrict(cleanDate);
            dayOfWeek = rowDate.weekday;
            break;
          } catch (_) {}
        }
      }

      if (rowDate == null || dayOfWeek == -1) continue;

      // EXTRACT & FORMAT TIME
      String timeStr = values[timeIdx];
      String formattedTime = timeStr;
      try {
        final timeUpper = timeStr.toUpperCase();
        final isPM = timeUpper.contains('PM');
        final isAM = timeUpper.contains('AM');
        final cleanTime = timeUpper.replaceAll(RegExp(r'[A-Z ]'), '');
        final parts = cleanTime.split(':');
        if (parts.isNotEmpty) {
          int h = int.parse(parts[0]);
          int m = parts.length > 1 ? int.parse(parts[1]) : 0;
          if (isPM && h < 12) h += 12;
          if (isAM && h == 12) h = 0;
          formattedTime =
              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
        }
      } catch (_) {}

      allParsedClasses.add({
        'subject': subject,
        'dayOfWeek': dayOfWeek,
        'time': formattedTime,
        'date': rowDate,
      });
    }

    if (allParsedClasses.isEmpty) {
      showErrorToast('Could not parse any dates to build the schedule.');
      return;
    }

    // 2. ✨ THE "LAST WEEK" ALGORITHM ✨
    // Find the MOST RECENT date that each Day of the Week occurred
    final Map<int, DateTime> mostRecentDates = {};
    for (var c in allParsedClasses) {
      int day = c['dayOfWeek'];
      DateTime date = c['date'];
      if (!mostRecentDates.containsKey(day) ||
          date.isAfter(mostRecentDates[day]!)) {
        mostRecentDates[day] = date;
      }
    }

    // 3. Filter to ONLY include classes from those specific most recent dates
    final finalClassesToSync = allParsedClasses.where((c) {
      return c['date'].isAtSameMomentAs(mostRecentDates[c['dayOfWeek']]!);
    }).toList();

    // 4. Save to Hive, avoiding duplicates
    final Set<String> uniqueSignatures = {};
    for (var e in _schedule) {
      uniqueSignatures.add('${e.dayOfWeek}-${e.startTime}-${e.subjectName}');
    }

    final Set<int> foundDays = {};
    int addedCount = 0;

    for (var c in finalClassesToSync) {
      int day = c['dayOfWeek'];
      String time = c['time'];
      String subject = c['subject'];

      final sig = '$day-$time-$subject';
      if (!uniqueSignatures.contains(sig)) {
        uniqueSignatures.add(sig);
        foundDays.add(day);

        final entry = ScheduleEntry()
          ..subjectName = subject
          ..dayOfWeek = day
          ..startTime = time;

        await HiveService.addEntry(entry);
        addedCount++;
      } else {
        foundDays.add(day); // Still register that we saw a class on this day
      }
    }

    _loadSchedule();

    if (addedCount > 0) {
      HapticFeedback.heavyImpact();
      // Check for missing typical weekdays (Mon-Fri)
      final missingDays = [
        1,
        2,
        3,
        4,
        5,
      ].where((d) => !foundDays.contains(d)).toList();

      if (missingDays.isNotEmpty) {
        final missingNames = missingDays.map((d) => _dayMap[d]).join(', ');
        showTopToast(
          '✅ Synced $addedCount classes!\n⚠️ Warning: No classes found for $missingNames.',
          backgroundColor: Colors.orange.shade700,
        );
      } else {
        showTopToast(
          '✨ Successfully synced your latest week ($addedCount classes)!',
          backgroundColor: Colors.green.shade600,
        );
      }
    } else {
      showTopToast(
        'Schedule is already up to date with your latest week!',
        backgroundColor: theme.colorScheme.primary,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Consumer<PremiumProvider>(
      builder: (context, premium, child) {
        final isPremium = premium.isPremium;

        return WillPopScope(
          onWillPop: () async {
            FocusScope.of(context).unfocus();
            return true;
          },
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'My Schedule',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isPremium) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.deepPurpleAccent,
                            Colors.purpleAccent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'PRO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              centerTitle: true,
              elevation: 0,
              backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.transparent),
                ),
              ),
              // ✨ AUTO SYNC BUTTON
              actions: [
                IconButton(
                  icon: const Icon(Icons.auto_awesome_rounded),
                  color: isDark ? Colors.purpleAccent : Colors.deepPurpleAccent,
                  tooltip: 'Auto Sync from Raw Data',
                  onPressed: () => _autoSyncSchedule(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: _schedule.isEmpty
                ? _buildPlaceholder(context, theme)
                : _buildScheduleList(context, theme, isPremium),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.selectionClick();
                _showScheduleEntryDialog(context);
              },
              backgroundColor: isDark
                  ? theme.colorScheme.primaryContainer.lighten()
                  : theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Class',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            bottomNavigationBar: isPremium
                ? const SizedBox.shrink()
                : SafeArea(
                    child: BannerAdWidget(
                      adUnitId: AdService.instance.scheduleBannerAdUnitId,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleSummary(ThemeData theme) {
    if (_schedule.isEmpty) return const SizedBox.shrink();

    final counts = <int, int>{};
    for (final e in _schedule) {
      counts[e.dayOfWeek] = (counts[e.dayOfWeek] ?? 0) + 1;
    }
    final busiest = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: _schedule.isEmpty ? 0 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
                    theme.colorScheme.primary.withOpacity(0.2),
                    theme.colorScheme.surface,
                  ]
                : [theme.colorScheme.primary.withOpacity(0.1), Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_schedule.length} Classes Scheduled',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Busiest day: ${_dayMap[busiest.key]} (${busiest.value})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList(
    BuildContext context,
    ThemeData theme,
    bool isPremium,
  ) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: KeyedSubtree(
            key: ValueKey(_schedule.length),
            child: _buildScheduleSummary(theme),
          ),
        ),
        if (_showGestureHint)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: CustomCard(
              child: Row(
                children: [
                  Icon(
                    Icons.swipe_left_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Pro tip: Swipe left to delete a class.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('seen_schedule_gesture_hint', true);
                      setState(() => _showGestureHint = false);
                      HapticFeedback.selectionClick();
                    },
                  ),
                ],
              ),
            ),
          ),
        ..._schedule.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildScheduleTile(context, theme, entry),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleTile(
    BuildContext context,
    ThemeData theme,
    ScheduleEntry entry,
  ) {
    final dayColor = _dayColors[entry.dayOfWeek] ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(entry.key),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            final dialogTheme = Theme.of(ctx);
            final dialogIsDark = dialogTheme.brightness == Brightness.dark;
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dialogIsDark
                        ? [
                            Colors.red.shade900.withOpacity(0.35),
                            Colors.red.shade800.withOpacity(0.15),
                          ]
                        : [
                            Colors.red.shade100.withOpacity(0.6),
                            Colors.red.shade50.withOpacity(0.3),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withOpacity(0.15),
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        size: 38,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Remove Class?',
                      style: dialogTheme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.subjectName,
                      style: dialogTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: dayColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This class will be removed from your weekly schedule.',
                      textAlign: TextAlign.center,
                      style: dialogTheme.textTheme.bodyMedium?.copyWith(
                        color: dialogTheme.hintColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text(
                              'Keep',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Remove',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );

        if (_isDeleting) return false;
        _isDeleting = true;

        if (confirmed == true) {
          await HiveService.deleteEntry(entry.key);
          setState(() => _schedule.remove(entry));
          showTopToast('🧹 Class removed');
          _isDeleting = false;
          return true;
        }

        _isDeleting = false;
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: dayColor.withOpacity(isDark ? 0.05 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 6, color: dayColor),
                Expanded(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _showScheduleEntryDialog(context, entry: entry);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.subjectName.isNotEmpty
                                        ? entry.subjectName
                                        : 'Unnamed Class',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 14,
                                        color: dayColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _dayMap[entry.dayOfWeek] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: dayColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        entry.startTime,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.dividerColor.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.edit_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Build Your Schedule',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Hit the Auto-Sync button in the top right to instantly generate your schedule from your raw data!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showScheduleEntryDialog(
    BuildContext context, {
    ScheduleEntry? entry,
  }) async {
    final provider = Provider.of<AttendanceProvider>(context, listen: false);
    final subjectNames = provider.result.subjectStats.keys.toList()..sort();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final formKey = GlobalKey<FormState>();
    String currentSubjectText = entry?.subjectName ?? '';

    int selectedDay = entry?.dayOfWeek ?? 1;
    TimeOfDay? selectedTime = entry != null
        ? TimeOfDay(
            hour: int.parse(entry.startTime.split(':')[0]),
            minute: int.parse(entry.startTime.split(':')[1]),
          )
        : null;

    return showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withOpacity(0.9),
                          ]
                        : [Colors.white, theme.colorScheme.surface],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withOpacity(
                                0.15,
                              ),
                            ),
                            child: Icon(
                              entry == null
                                  ? Icons.add_card_rounded
                                  : Icons.edit_calendar_rounded,
                              size: 32,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            entry == null ? 'Add Class' : 'Edit Class',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            entry == null
                                ? 'Add a class to your weekly rotation'
                                : 'Update your class details',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          Autocomplete<String>(
                            initialValue: TextEditingValue(
                              text: currentSubjectText,
                            ),
                            optionsBuilder: (value) {
                              if (value.text.isEmpty)
                                return const Iterable.empty();
                              return subjectNames.where(
                                (s) => s.toLowerCase().contains(
                                  value.text.toLowerCase(),
                                ),
                              );
                            },
                            onSelected: (selection) =>
                                currentSubjectText = selection,
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    autofocus: entry == null,
                                    onChanged: (val) =>
                                        currentSubjectText = val,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    decoration: InputDecoration(
                                      labelText: 'Subject Name',
                                      labelStyle: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      filled: true,
                                      fillColor: theme.colorScheme.primary
                                          .withOpacity(0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: theme.colorScheme.primary,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (v) =>
                                        currentSubjectText.trim().isEmpty
                                        ? 'Subject is required'
                                        : null,
                                  );
                                },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<int>(
                            value: selectedDay,
                            decoration: InputDecoration(
                              labelText: 'Day of Week',
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.primary.withOpacity(
                                0.05,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            items: _dayMap.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => selectedDay = v!),
                          ),
                          const SizedBox(height: 16),

                          Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(
                                0.05,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              title: const Text(
                                'Start Time',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                selectedTime == null
                                    ? 'Tap to select time'
                                    : selectedTime!.format(context),
                                style: TextStyle(
                                  color: selectedTime == null
                                      ? theme.hintColor
                                      : theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.access_time_filled_rounded,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                              ),
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: selectedTime ?? TimeOfDay.now(),
                                );
                                if (time != null) {
                                  setDialogState(() => selectedTime = time);
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 28),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? theme.colorScheme.primaryContainer
                                              .lighten()
                                        : theme.colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    entry == null
                                        ? Icons.check_circle_rounded
                                        : Icons.save_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    entry == null ? 'Add' : 'Save',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  onPressed: () async {
                                    HapticFeedback.lightImpact();
                                    FocusScope.of(context).unfocus();

                                    if (selectedTime == null) {
                                      showErrorToast('Please select a time');
                                      return;
                                    }

                                    if (formKey.currentState!.validate()) {
                                      final finalSubject = currentSubjectText
                                          .trim();
                                      if (finalSubject.isEmpty) return;

                                      final newEntry = ScheduleEntry()
                                        ..subjectName = finalSubject
                                        ..dayOfWeek = selectedDay
                                        ..startTime =
                                            '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';

                                      if (entry == null) {
                                        await HiveService.addEntry(newEntry);
                                        showTopToast(
                                          '✨ Class added to schedule',
                                        );
                                      } else {
                                        await HiveService.updateEntry(
                                          entry.key,
                                          newEntry,
                                        );
                                        showTopToast('📝 Class updated');
                                      }

                                      _loadSchedule();
                                      if (context.mounted)
                                        Navigator.of(ctx).pop();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
