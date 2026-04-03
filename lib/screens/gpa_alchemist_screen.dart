import 'dart:ui' as dart_ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/widgets/banner_ad_widget.dart';
import 'package:bunkmate/widgets/native_ad_card.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import 'package:bunkmate/providers/gpa_provider.dart';
import 'package:bunkmate/services/gpa_pdf_parser.dart';
import 'package:bunkmate/models/gpa_models.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:bunkmate/widgets/saves_modal.dart';
import 'package:bunkmate/helpers/button_color_extensions.dart';
import 'package:bunkmate/providers/theme_provider.dart';

class GpaAlchemistScreen extends StatefulWidget {
  const GpaAlchemistScreen({super.key});

  @override
  State<GpaAlchemistScreen> createState() => _GpaAlchemistScreenState();
}

class _GpaAlchemistScreenState extends State<GpaAlchemistScreen> {
  final Map<String, Color> gradeColors = {
    "A++": const Color(0xFF10b981),
    "A+": const Color(0xFF22c55e),
    "A": const Color(0xFF84cc16),
    "B+": const Color(0xFFa3e635),
    "B": const Color(0xFFeab308),
    "C+": const Color(0xFFf59e0b),
    "C": const Color(0xFFf97316),
    "D+": const Color(0xFFef4444),
    "D": const Color(0xFFdc2626),
    "E+": const Color(0xFFb91c1c),
    "E": const Color(0xFF991b1b),
    "F": const Color(0xFF7f1d1d),
  };

  int _touchedGradeIndex = -1;

  Future<void> _handleExport(
    BuildContext context,
    GpaProvider provider,
    bool isPremium,
  ) async {
    HapticFeedback.mediumImpact();

    void executeExport() async {
      try {
        showTopToast('⏳ Generating export file...');
        final jsonString = provider.exportToJson();

        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/gpa_lab_backup.json');
        await file.writeAsString(jsonString);

        await Share.shareXFiles([XFile(file.path)], subject: 'GPA Lab Backup');
      } catch (e) {
        showErrorToast('Failed to export data.');
      }
    }

    if (isPremium) {
      executeExport();
    } else {
      showTopToast('🎥 Loading Ad to Export...');
      AdService.instance.showRewardedAd(
        onReward: () {
          executeExport();
        },
      );
    }
  }

  Future<void> _handleImport(BuildContext context, GpaProvider provider) async {
    HapticFeedback.lightImpact();
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        final success = provider.importFromJson(jsonString);
        if (success) {
          showTopToast(
            '✅ Data imported successfully!',
            backgroundColor: Colors.green,
          );
        } else {
          showErrorToast('Invalid backup file format.');
        }
      }
    } catch (e) {
      showErrorToast('Failed to read file.');
    }
  }

  // ✨ GORGEOUS NEW CONTROL CENTER (Replaces 3 Dots)
  void _showControlCenter(
    BuildContext context,
    GpaProvider gpaProvider,
    bool isPremium,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: theme.hintColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Control Center',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 24),
              _buildMenuTile(
                context,
                icon: Icons.save_rounded,
                title: 'Manage Saves',
                subtitle: 'Load and save your data',
                color: theme.colorScheme.primary,
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const SavesModal(isGpaMode: true),
                  );
                },
              ),
              _buildMenuTile(
                context,
                icon: Icons.file_download_outlined,
                title: 'Import Backup',
                subtitle: 'Restore from a JSON file',
                color: Colors.blueAccent,
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImport(context, gpaProvider);
                },
              ),
              _buildMenuTile(
                context,
                icon: Icons.file_upload_outlined,
                title: 'Export Data',
                subtitle: isPremium
                    ? 'Save to your device'
                    : 'Watch an ad to export',
                color: Colors.green,
                isPremiumAction: !isPremium,
                onTap: () {
                  Navigator.pop(ctx);
                  _handleExport(context, gpaProvider, isPremium);
                },
              ),
              const Divider(height: 32),
              _buildMenuTile(
                context,
                icon: Icons.delete_sweep_rounded,
                title: 'Clear All Data',
                subtitle: 'Wipe everything and start fresh',
                color: Colors.redAccent,
                onTap: () async {
                  Navigator.pop(ctx);
                  final confirm = await _showCustomDeleteDialog(
                    context,
                    title: 'Clear All Data?',
                    content:
                        'This will permanently remove all your saved semesters and courses.\n\nThis action cannot be undone.',
                    confirmText: 'Clear Data',
                  );
                  if (confirm == true) gpaProvider.clearAllData();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isPremiumAction = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
      ),
      trailing: isPremiumAction
          ? const Icon(Icons.play_circle_outline_rounded, color: Colors.amber)
          : const Icon(Icons.chevron_right_rounded, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final gpaProvider = context.watch<GpaProvider>();
    final premium = context.watch<PremiumProvider>();
    final isPremium = premium.isPremium;

    return DefaultTabController(
      length: 3,
      // ✨ FIX: Wrap the entire scaffold in a gesture detector to kill keyboard on tap anywhere!
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF0D1117)
              : const Color(0xFFF5F7FA),
          appBar: AppBar(
            backgroundColor: isDark
                ? const Color(0xFF0D1117)
                : const Color(0xFFF5F7FA),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: theme.colorScheme.primary,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            // ✨ GORGEOUS BRANDED TITLE WITH PRO BADGE
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'GPA Lab',
                  // ✨ FIX: Inherits your global BunkMate font!
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    foreground: Paint()
                      ..shader =
                          LinearGradient(
                            colors: [Colors.blue.shade500, Colors.purpleAccent],
                          ).createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
                    letterSpacing: -0.5,
                  ),
                ),
                // ✨ PREMIUM TOUCH: The "PRO" Badge
                if (isPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
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
            actions: [
              // ✨ THE NEW DARK MODE TOGGLE
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: child.key == const ValueKey('dark')
                        ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                        : Tween<double>(begin: 0.75, end: 1).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark ? 'dark' : 'light'),
                    color: theme.colorScheme.primary,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  // ✨ Calls your global theme provider to flip the switch
                  context.read<ThemeProvider>().toggleTheme();
                },
              ),

              // ✨ GORGEOUS NEW TOP MENU ICON (Already there)
              IconButton(
                icon: Icon(
                  Icons.dashboard_customize_rounded,
                  color: theme.colorScheme.primary,
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showControlCenter(context, gpaProvider, isPremium);
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: TabBar(
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor: theme.hintColor,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'Semesters'),
                Tab(text: 'Analysis'),
                Tab(text: 'Planner'),
              ],
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildSemestersTab(
                      context,
                      gpaProvider,
                      theme,
                      isDark,
                      isPremium,
                    ),
                    _buildAnalysisTab(
                      context,
                      gpaProvider,
                      theme,
                      isDark,
                      isPremium,
                    ),
                    _buildPlannerTab(context),
                  ],
                ),
              ),
              if (!isPremium)
                SafeArea(
                  top: false,
                  child: BannerAdWidget(
                    adUnitId: AdService.instance.analysisBannerAdUnitId,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // ✨ TAB 1: SEMESTERS & CALCULATION (ZERO LAG NOW!)
  // ====================================================================
  Widget _buildSemestersTab(
    BuildContext context,
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
    bool isPremium,
  ) {
    // ✨ FIX: Removed the wrapper SingleChildScrollView!
    // Using ReorderableListView natively with headers and footers prevents ALL lag.
    return ReorderableListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      onReorder: (oldIndex, newIndex) {
        HapticFeedback.lightImpact();
        provider.reorderSemesters(oldIndex, newIndex);
      },
      // --- THE HEADER ---
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: CustomCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Cumulative GPA',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        provider.cgpa.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.primary,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (!isPremium) ...[const NativeAdCard(), const SizedBox(height: 24)],

          CustomCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: Colors.amber,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Calculate',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Import your result PDF to auto-fill grades.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    GpaPdfParser.pickAndParsePdf(context);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.upload_file_rounded,
                            size: 42,
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to Upload PDF',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Semester Data',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Drag to reorder',
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
      // --- THE LIST ---
      itemCount: provider.semesters.length,
      itemBuilder: (context, index) {
        final sem = provider.semesters[index];
        return _buildSemesterCard(context, sem, provider, theme, isDark);
      },
      // --- THE FOOTER ---
      footer: Padding(
        padding: const EdgeInsets.only(top: 16.0),
        child: Center(
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              provider.addSemester();
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Semester Manually',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? theme.colorScheme.primary
                  : theme.colorScheme.primary.lighten(0.05),
              foregroundColor: isDark ? Colors.black : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // ✨ SEMESTER CARD BUILDER (Redesigned & Premium)
  // ====================================================================
  Widget _buildSemesterCard(
    BuildContext context,
    Semester sem,
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    return Padding(
      key: ValueKey(sem.id),
      padding: const EdgeInsets.only(bottom: 16.0),
      child: CustomCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.toggleCollapse(sem.id);
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    // ✨ REMOVED DRAG ICON - Long-press anywhere on the card will now drag it automatically!
                    AnimatedRotation(
                      turns: sem.isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: theme.hintColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: sem.name,
                        maxLength: 15,
                        buildCounter:
                            (
                              context, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                        onChanged: (val) =>
                            provider.updateSemesterName(sem.id, val),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'SGPA',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.hintColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          sem.sgpa.toStringAsFixed(2),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    // ✨ MOVED DELETE BUTTON HERE
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        final confirm = await _showCustomDeleteDialog(
                          context,
                          title: 'Delete Semester?',
                          content:
                              'Are you sure you want to permanently delete "${sem.name}" and all its courses?',
                          confirmText: 'Delete',
                        );
                        if (confirm == true) provider.removeSemester(sem.id);
                      },
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              child: sem.isCollapsed
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Divider(
                            color: theme.dividerColor.withOpacity(0.1),
                            height: 1,
                          ),
                          const SizedBox(height: 16),

                          if (sem.courses.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                'No courses added yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),

                          ...sem.courses
                              .map(
                                (course) => _buildCourseRow(
                                  course,
                                  sem.id,
                                  provider,
                                  theme,
                                ),
                              )
                              .toList(),

                          const SizedBox(height: 16),

                          // ✨ FULL WIDTH "ADD COURSE" BUTTON
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              provider.addCourse(sem.id);
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text(
                              'Add Course',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary
                                  .withOpacity(0.1),
                              foregroundColor: theme.colorScheme.primary,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // ✨ SINGLE COURSE ROW (DE-CONGESTED MINI-CARD)
  // ====================================================================
  Widget _buildCourseRow(
    Course course,
    String semId,
    GpaProvider provider,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.03),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );

    return Container(
      key: ValueKey(course.id),
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.02)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          // TOP ROW: Course Name
          TextFormField(
            initialValue: course.name,
            onChanged: (val) =>
                provider.updateCourse(semId, course.id, name: val),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            decoration: inputDecoration.copyWith(hintText: 'Course Name'),
          ),
          const SizedBox(height: 8),

          // BOTTOM ROW: Credits, Grade, Delete
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: course.credits > 0
                      ? course.credits.toString()
                      : '',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) {
                    final creds = double.tryParse(val) ?? 0.0;
                    provider.updateCourse(semId, course.id, credits: creds);
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: inputDecoration.copyWith(hintText: 'Credits'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: course.grade.isNotEmpty ? course.grade : "A++",
                      isExpanded: true,
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: theme.hintColor,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      dropdownColor: theme.colorScheme.surface,
                      items: GpaProvider.gradesList.map((String grade) {
                        return DropdownMenuItem<String>(
                          value: grade,
                          child: Text(grade),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          provider.updateCourse(
                            semId,
                            course.id,
                            grade: newValue,
                          );
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                color: theme.hintColor.withOpacity(0.5),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  provider.removeCourse(semId, course.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // ✨ TAB 2: ANALYSIS (STATS & CHARTS)
  // ====================================================================
  Widget _buildAnalysisTab(
    BuildContext context,
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
    bool isPremium,
  ) {
    if (provider.semesters.isEmpty ||
        provider.semesters.every((s) => s.courses.isEmpty)) {
      return Center(
        child: Text(
          'No data to analyze.\nAdd semesters and courses first!',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.hintColor, fontSize: 16),
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKeyStatsCard(provider, theme, isDark),
          const SizedBox(height: 24),
          if (!isPremium) ...[const NativeAdCard(), const SizedBox(height: 24)],
          _buildSgpaTrendChart(context, provider, theme, isDark),
          const SizedBox(height: 24),
          _buildGradeDistributionChart(provider, theme, isDark),
        ],
      ),
    );
  }

  // ====================================================================
  // ✨ TAB 3: GOAL PLANNER
  // ====================================================================
  Widget _buildPlannerTab(BuildContext context) {
    return const SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: GoalPlannerCard(),
    );
  }

  // ====================================================================
  // ✨ ANALYSIS WIDGETS
  // ====================================================================
  Widget _buildKeyStatsCard(
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    double totalCredits = 0;
    int totalCourses = 0;
    int passedCourses = 0;

    Semester? bestSem;
    Semester? worstSem;

    for (var sem in provider.semesters) {
      if (sem.sgpa > 0) {
        if (bestSem == null || sem.sgpa > bestSem.sgpa) bestSem = sem;
        if (worstSem == null || sem.sgpa < worstSem.sgpa) worstSem = sem;
      }
      for (var c in sem.courses) {
        if (c.credits > 0) {
          totalCredits += c.credits;
          totalCourses++;
          if (c.grade != 'F') passedCourses++;
        }
      }
    }

    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Key Statistics',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow(
            'Total Credits Earned',
            totalCredits.toStringAsFixed(1),
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            'Total Courses Passed',
            '$passedCourses / $totalCourses',
            theme,
            isDark,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            'Highest SGPA',
            bestSem != null
                ? '${bestSem.sgpa.toStringAsFixed(2)} (${bestSem.name})'
                : 'N/A',
            theme,
            isDark,
            color: Colors.green,
          ),
          const SizedBox(height: 12),
          _buildStatRow(
            'Lowest SGPA',
            worstSem != null
                ? '${worstSem.sgpa.toStringAsFixed(2)} (${worstSem.name})'
                : 'N/A',
            theme,
            isDark,
            color: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    ThemeData theme,
    bool isDark, {
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.hintColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? (isDark ? Colors.white : Colors.black87),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGradeDistributionChart(
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    Map<String, int> gradeCounts = {};
    int totalGrades = 0;

    for (var sem in provider.semesters) {
      for (var c in sem.courses) {
        if (c.credits > 0 && c.grade.isNotEmpty) {
          gradeCounts[c.grade] = (gradeCounts[c.grade] ?? 0) + 1;
          totalGrades++;
        }
      }
    }

    if (gradeCounts.isEmpty) return const SizedBox.shrink();

    final sortedGrades = gradeCounts.keys.toList()
      ..sort(
        (a, b) => GpaProvider.gradesList
            .indexOf(a)
            .compareTo(GpaProvider.gradesList.indexOf(b)),
      );
    List<PieChartSectionData> sections = [];
    int index = 0;

    for (String grade in sortedGrades) {
      final count = gradeCounts[grade]!;
      final isTouched = index == _touchedGradeIndex;
      final double radius = isTouched ? 70.0 : 55.0;
      final double percentage = (count / totalGrades) * 100;

      sections.add(
        PieChartSectionData(
          value: count.toDouble(),
          title: isTouched
              ? count.toString()
              : (percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : ''),
          color: gradeColors[grade] ?? theme.colorScheme.primary,
          radius: radius,
          titleStyle: TextStyle(
            fontSize: isTouched ? 18 : 12,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            width: 2,
          ),
        ),
      );
      index++;
    }

    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Overall Grade Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                pieTouchData: PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedGradeIndex = -1;
                        return;
                      }
                      _touchedGradeIndex =
                          pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });
                  },
                ),
                sections: sections,
                centerSpaceRadius: 45,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: sortedGrades.map((grade) {
              final count = gradeCounts[grade]!;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: gradeColors[grade] ?? theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$grade ($count)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSgpaTrendChart(
    BuildContext context,
    GpaProvider provider,
    ThemeData theme,
    bool isDark,
  ) {
    final validSemesters = provider.semesters.where((s) => s.sgpa > 0).toList();
    if (validSemesters.isEmpty) return const SizedBox.shrink();

    final spots = validSemesters.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.sgpa);
    }).toList();

    return CustomCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SGPA Trend',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withOpacity(0.1),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < validSemesters.length) {
                          String label = validSemesters[index].name;
                          final match = RegExp(r'\d+').firstMatch(label);
                          if (match != null && label.length > 10) {
                            label = 'S${match.group(0)}';
                          } else if (label.length > 6) {
                            label = '${label.substring(0, 6)}..';
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 8,
                            child: Text(
                              label,
                              style: TextStyle(
                                color: theme.hintColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 2,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          space: 4,
                          child: Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              color: theme.hintColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (validSemesters.length - 1).toDouble().clamp(
                  0.0,
                  double.infinity,
                ),
                minY: 0,
                maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: theme.colorScheme.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                            radius: 5,
                            color: theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.3),
                          theme.colorScheme.primary.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) =>
                        isDark ? Colors.white : Colors.black87,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final semName = validSemesters[spot.x.toInt()].name;
                        return LineTooltipItem(
                          '$semName\n',
                          TextStyle(
                            color: isDark ? Colors.black54 : Colors.white70,
                            fontSize: 11,
                          ),
                          children: [
                            TextSpan(
                              text: spot.y.toStringAsFixed(2),
                              style: TextStyle(
                                color: isDark ? Colors.black : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showCustomDeleteDialog(
    BuildContext context, {
    required String title,
    required String content,
    required String confirmText,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark
            ? const Color(0xFF2A1C1C)
            : Colors.white, // Deep red tint for danger
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                content,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: theme.hintColor.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: theme.hintColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// ✨ GOAL PLANNER CARD WIDGET
// ====================================================================
class GoalPlannerCard extends StatefulWidget {
  const GoalPlannerCard({super.key});

  @override
  State<GoalPlannerCard> createState() => _GoalPlannerCardState();
}

class _GoalPlannerCardState extends State<GoalPlannerCard> {
  late TextEditingController _targetController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<GpaProvider>();
    _targetController = TextEditingController(
      text: provider.targetCgpa > 0 ? provider.targetCgpa.toString() : '',
    );
  }

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  void _setQuickTarget(double target, GpaProvider provider) {
    HapticFeedback.lightImpact();
    _targetController.text = target.toString();
    provider.setTargetCgpa(target);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<GpaProvider>();

    final requiredSgpa = provider.getRequiredSgpa();
    String requiredText = requiredSgpa.toStringAsFixed(2);
    String subText = 'in your future semesters.';
    Color reqColor = theme.colorScheme.primary;

    if (requiredSgpa > 10) {
      requiredText = "Over 10.0";
      subText = "This target seems impossible. 😔";
      reqColor = Colors.redAccent;
    } else if (requiredSgpa <= 0 && provider.targetCgpa > 0) {
      requiredText = "Any Grade!";
      subText = "You've already surpassed this target! 🎉";
      reqColor = Colors.green;
    } else if (provider.targetCgpa == 0 ||
        provider.futureSemesterCredits.isEmpty) {
      requiredText = "0.00";
    }

    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: isDark
          ? Colors.white.withOpacity(0.05)
          : Colors.black.withOpacity(0.04),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );

    return CustomCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.purpleAccent,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'GPA Goal Planner',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Set a target CGPA and see what it takes to get there.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Target CGPA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                  fontSize: 13,
                ),
              ),
              Row(
                children: [8.0, 8.5, 9.0]
                    .map(
                      (val) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InkWell(
                          onTap: () => _setQuickTarget(val, provider),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              val.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            decoration: inputDecoration.copyWith(hintText: 'e.g., 8.50'),
            onChanged: (val) {
              final target = double.tryParse(val) ?? 0.0;
              provider.setTargetCgpa(target);
            },
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Future Semesters & Credits',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.hintColor,
                  fontSize: 13,
                ),
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  provider.addFutureSemester();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  child: Text(
                    '+ Add Sem',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (provider.futureSemesterCredits.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'No future semesters added.',
                style: TextStyle(
                  color: theme.hintColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                ),
              ),
            ),

          ...provider.futureSemesterCredits.asMap().entries.map((entry) {
            final index = entry.key;
            final credits = entry.value;
            return Padding(
              key: ValueKey('future_sem_$index'),
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      'Sem ${provider.semesters.length + index + 1}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      initialValue: credits > 0 ? credits.toString() : '',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      decoration: inputDecoration.copyWith(
                        hintText: 'Credits (e.g., 25)',
                      ),
                      onChanged: (val) {
                        final parsed = double.tryParse(val) ?? 0.0;
                        provider.updateFutureCredits(index, parsed);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: Colors.redAccent.withOpacity(0.7),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      provider.removeFutureSemester(index);
                    },
                  ),
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.05)),
            ),
            child: Column(
              children: [
                Text(
                  'To reach your goal, you\'ll need to average:',
                  style: TextStyle(
                    color: theme.hintColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$requiredText ${requiredSgpa > 0 && requiredSgpa <= 10 ? 'SGPA' : ''}',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: reqColor,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ],
            ),
          ),

          const Divider(height: 48),

          Text(
            'What if you average a different SGPA?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.hintColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Slide to see how your final CGPA would change.',
            style: TextStyle(color: theme.hintColor, fontSize: 12),
          ),
          const SizedBox(height: 16),

          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.2),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withOpacity(0.2),
              trackHeight: 6,
            ),
            child: Slider(
              value: provider.projectedSgpa,
              min: 0,
              max: 10,
              divisions: 100,
              label: provider.projectedSgpa.toStringAsFixed(2),
              onChanged: (val) => provider.setProjectedSgpa(val),
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Projected SGPA',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.projectedSgpa.toStringAsFixed(2),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Resulting CGPA',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    provider.getResultingCgpa().toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
