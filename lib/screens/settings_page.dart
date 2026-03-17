import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/settings_provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:bunkmate/widgets/custom_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:bunkmate/mixins/scroll_to_top_mixin.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/screens/schedule_page.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:bunkmate/settings/settings_coordinator.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/helpers/ad_helper.dart';
import 'package:bunkmate/helpers/update_result.dart';
import 'package:bunkmate/screens/bunker.dart';
import 'dart:math';
import 'package:bunkmate/widgets/whats_new_list.dart';
import 'package:bunkmate/widgets/premium_sheet.dart';
import 'package:bunkmate/providers/premium_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> with ScrollToTopMixin {
  String _appVersion = 'Loading...';
  bool _isCheckingUpdate = false;
  late final SettingsCoordinator coordinator;
  late final String _footerQuote;
  bool _easterEggTriggered = false;

  static const _quotes = [
    'Attendance is temporary.\nGrades are forever.',
    'Built for planners.\nLoved by bunkers.',
    'Low attendance.\nHigh clarity.',
    'You don’t skip classes.\nYou trade them.',
    'Attendance is a suggestion.\nDiscipline is a choice.',
    'Mate, Have a day with yourself ',
  ];

  @override
  void initState() {
    super.initState();
    coordinator = SettingsCoordinator();
    _footerQuote = _quotes[Random().nextInt(_quotes.length)];
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = 'Version ${info.version}';
      });
    }
  }

  Future<void> _launchURL(String urlString, {String? mailtoSubject}) async {
    Uri url;
    if (mailtoSubject != null) {
      url = Uri(
        scheme: 'mailto',
        path: urlString,
        query:
            'subject=${Uri.encodeComponent(mailtoSubject)}&body=${Uri.encodeComponent("\n\nApp Version: $_appVersion\n")}',
      );
    } else {
      url = Uri.parse(urlString);
    }
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (url.scheme == 'mailto') {
          showErrorToast('Could not find an email app to use.');
        } else {
          showErrorToast('Could not launch $url');
        }
      }
    } catch (e) {
      showErrorToast('Error: $e');
    }
  }

  void _showResetConfirmation(BuildContext context, SettingsProvider provider) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

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
                    Icons.restart_alt_rounded,
                    size: 38,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Reset All Settings?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This will restore all settings to their default values.\n\nThis action cannot be undone.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.warning_amber_rounded, size: 18),
                        label: const Text(
                          'Reset',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          provider.resetAllSettings();
                          Navigator.of(ctx).pop();
                          HapticFeedback.lightImpact();
                          showTopToast('Settings have been reset.');
                        },
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
  }

  // ✨ NEW: Dedicated Sheet to show What's New when already updated
  void _showWhatsNewSheet() {
    final remoteConfig = RemoteConfigService.instance;
    final whatsNewItems = remoteConfig.getWhatsNewItems();
    final whatsNewTitle = remoteConfig.whatsNewTitle.isNotEmpty
        ? remoteConfig.whatsNewTitle
        : 'Release Notes ✨';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  whatsNewTitle,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                WhatsNewList(items: whatsNewItems),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      "Awesome!",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUpdateDialog(
    String latestVersionName,
    String updateUrl,
    bool forceUpdate,
  ) {
    final remoteConfig = RemoteConfigService.instance;
    final whatsNewItems = remoteConfig.getWhatsNewItems();
    final whatsNewTitle = remoteConfig.whatsNewTitle.isNotEmpty
        ? remoteConfig.whatsNewTitle
        : 'Update Available ✨';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;

        return WillPopScope(
          onWillPop: () async => !forceUpdate,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.green.shade900.withOpacity(0.35),
                          Colors.green.shade800.withOpacity(0.15),
                        ]
                      : [
                          Colors.green.shade100.withOpacity(0.6),
                          Colors.green.shade50.withOpacity(0.3),
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
                      color: Colors.green.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.system_update_alt_rounded,
                      size: 38,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    forceUpdate ? 'Update Required' : 'Update Available',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: forceUpdate ? Colors.red : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (forceUpdate)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'This version is no longer supported.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version $latestVersionName',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          whatsNewTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      WhatsNewList(items: whatsNewItems),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (!forceUpdate)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text(
                              'Later',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      if (!forceUpdate) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: Text(
                            forceUpdate ? 'Update Now ⚡' : 'Get it Now 🤟🏻',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: forceUpdate
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            if (updateUrl.isNotEmpty) {
                              _launchURL(updateUrl);
                            } else {
                              showErrorToast('Update URL not configured yet.');
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
        );
      },
    );
  }

  // ✨ PREMIUM TOUCH: Glowing Section Headers
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 0, 8.0, 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(isDark ? 0.2 : 0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
              border: Border.all(
                color: color.withOpacity(isDark ? 0.4 : 0.2),
                width: 1,
              ),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final adProvider = context.read<AdProvider>();
    final premium = context.watch<PremiumProvider>();

    final bool isDark = themeProvider.isDarkMode;
    final bool showProactiveAlertsFeature = true;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            // ✨ PREMIUM TOUCH: VIP PRO BADGE IN APP BAR
            if (premium.isPremium) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor.withOpacity(0.85),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: dart_ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      // ✨ FIX: Removed the Stack entirely. Everything is now a single, clean scrollable list.
      body: ListView(
        physics: const BouncingScrollPhysics(),
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          16.0,
          16.0,
          16.0,
          24.0,
        ), // Reduced bottom padding
        children: [
          // ✨ PREMIUM TOUCH: App Hero Badge (Replaced with Premium Banner!)
          _buildPremiumHeroCard(context, premium, isDark),

          const SizedBox(height: 32),

          // --- My Schedule ---
          _buildSectionHeader(
            context,
            'My Schedule',
            Icons.calendar_month_rounded,
            Colors.cyan,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildSettingsTile(
              context: context,
              icon: Icons.edit_calendar_rounded,
              color: Colors.cyan.shade600,
              title: 'Manage Class Schedule',
              subtitle: 'Set your weekly recurring classes',
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                Navigator.of(
                  context,
                  rootNavigator: true,
                ).push(MaterialPageRoute(builder: (_) => const SchedulePage()));
              },
            ),
          ),
          const SizedBox(height: 28),

          // --- General ---
          _buildSectionHeader(
            context,
            'General',
            Icons.tune_rounded,
            Colors.blueGrey,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildSettingsToggle(
                  context: context,
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: Colors.blueAccent,
                  title: 'Dark Mode',
                  subtitle: 'Switch between light and dark themes',
                  value: isDark,
                  enableTileTap: true,
                  onChanged: (_) {
                    HapticFeedback.lightImpact();
                    themeProvider.toggleTheme(persist: true);
                  },
                ),

                _buildSettingsToggle(
                  context: context,
                  icon: Icons.fact_check_outlined,
                  color: Colors.green,
                  title: 'Show Result Pop-up',
                  subtitle: 'Display a summary after calculation',
                  value: settingsProvider.showResultOverlay,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    settingsProvider.setShowResultOverlay(value);
                  },
                ),

                // ✨ NEW: Default Target Slider ✨
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.track_changes_rounded,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Default Target',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Your goal when opening the app',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${settingsProvider.defaultTarget}%',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: theme.colorScheme.primary,
                          inactiveTrackColor: theme.colorScheme.primary
                              .withOpacity(0.2),
                          thumbColor: theme.colorScheme.primary,
                          overlayColor: theme.colorScheme.primary.withOpacity(
                            0.1,
                          ),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: settingsProvider.defaultTarget.toDouble(),
                          min: 50,
                          max: 100,
                          divisions: 50,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            settingsProvider.setDefaultTarget(val.toInt());
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                //thatsit

                if (showProactiveAlertsFeature)
                  _buildSettingsTile(
                    context: context,
                    icon: Icons.notifications_active_rounded,
                    color: premium.isPremium
                        ? Colors.amber.shade700
                        : const dart_ui.Color.fromARGB(255, 106, 0, 181),
                    title: 'Proactive Alerts',
                    subtitle: 'Get notified if you enter the danger zone',
                    trailingWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!premium.isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.deepPurpleAccent.withOpacity(0.5),
                              ),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: Colors.deepPurpleAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        Switch(
                          value:
                              premium.isPremium &&
                              settingsProvider.proactiveAlerts,
                          activeColor: isDark
                              ? Colors.deepPurple.shade500
                              : Colors.deepPurple.shade900,
                          onChanged: (value) {
                            if (!premium.isPremium) {
                              showPremiumPaywall(context);
                              return;
                            }
                            coordinator.toggleProactiveAlerts(
                              value,
                              settingsProvider,
                            );
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      if (!premium.isPremium) {
                        showPremiumPaywall(context);
                      } else {
                        coordinator.toggleProactiveAlerts(
                          !settingsProvider.proactiveAlerts,
                          settingsProvider,
                        );
                      }
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- On App Launch ---
          _buildSectionHeader(
            context,
            'On App Launch',
            Icons.rocket_launch_rounded,
            Colors.orangeAccent,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildSettingsRadio<AppLaunchOption>(
                  context: context,
                  icon: Icons.replay_rounded,
                  color: Colors.purpleAccent,
                  title: 'Resume Last Save',
                  subtitle: 'Automatically load your last saved data',
                  value: AppLaunchOption.resume,
                  groupValue: settingsProvider.launchOption,
                  onChanged: (value) {
                    if (value != null) {
                      HapticFeedback.lightImpact();
                      settingsProvider.setLaunchOption(value);
                    }
                  },
                ),
                _buildSettingsRadio<AppLaunchOption>(
                  context: context,
                  icon: Icons.content_paste_go_rounded,
                  color: Colors.orangeAccent,
                  title: 'Paste from Clipboard',
                  subtitle: 'Automatically paste and calculate',
                  value: AppLaunchOption.clipboard,
                  groupValue: settingsProvider.launchOption,
                  onChanged: (value) {
                    if (value != null) {
                      HapticFeedback.lightImpact();
                      settingsProvider.setLaunchOption(value);
                    }
                  },
                ),
                _buildSettingsRadio<AppLaunchOption>(
                  context: context,
                  icon: Icons.do_not_disturb_on_outlined,
                  color: Colors.grey,
                  title: 'Do Nothing',
                  subtitle: 'Start with a clean slate each time',
                  value: AppLaunchOption.none,
                  groupValue: settingsProvider.launchOption,
                  onChanged: (value) {
                    if (value != null) {
                      HapticFeedback.lightImpact();
                      settingsProvider.setLaunchOption(value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- Get in Touch ---
          _buildSectionHeader(
            context,
            'Get in Touch',
            Icons.forum_rounded,
            Colors.tealAccent.shade400,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.email_rounded,
                  color: Colors.teal,
                  title: 'Email Us for Support',
                  subtitle: 'We\'ll get back to you soon',
                  onTap: () {
                    _launchURL(
                      'themadbrogrammers@gmail.com',
                      mailtoSubject: 'BunkMate Feedback',
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.groups_rounded,
                  color: Colors.deepPurpleAccent,
                  title: 'Join the Discussion',
                  subtitle: 'Ideas, feedback, and general questions',
                  onTap: () {
                    _launchURL(
                      'https://github.com/themadbrogrammers/BunkER/discussions',
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.bug_report_rounded,
                  color: Colors.redAccent,
                  title: 'Report an Issue',
                  subtitle: 'Find a bug? Let us know on GitHub',
                  onTap: () {
                    _launchURL(
                      'https://github.com/themadbrogrammers-art/BunkER/issues',
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.star_rounded,
                  color: Colors.amber.shade600,
                  title: 'Rate the App',
                  subtitle: 'Enjoying the app? Leave a review!',
                  onTap: () {
                    _launchURL(
                      'https://play.google.com/store/apps/details?id=com.themadbrogrammers.bunkmate',
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- About & Legal ---
          _buildSectionHeader(
            context,
            'About & Legal',
            Icons.info_rounded,
            Colors.indigoAccent,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                _buildSettingsTile(
                  context: context,
                  icon: Icons.auto_awesome_rounded,
                  color: Colors.deepPurpleAccent,
                  title: 'What is BunkMate?',
                  subtitle: 'A quick intro to the app',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const AboutBunkMateSheet(),
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.system_update_rounded,
                  color: Colors.blueGrey,
                  title: 'Check for Updates',
                  subtitle: _appVersion,
                  onTap: _isCheckingUpdate
                      ? null
                      : () async {
                          setState(() => _isCheckingUpdate = true);
                          final result = await coordinator.checkAppUpdate();
                          if (!mounted) return;
                          setState(() => _isCheckingUpdate = false);

                          if (result == UpdateResult.optional) {
                            _showUpdateDialog(
                              RemoteConfigService.instance.getString(
                                'latest_version_name',
                              ),
                              RemoteConfigService.instance.getString(
                                'update_url',
                              ),
                              false,
                            );
                          } else {
                            HapticFeedback.lightImpact();
                            showTopToast('✅ You are on the latest version');
                            _showWhatsNewSheet();
                          }
                        },
                  trailingWidget: _isCheckingUpdate
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.privacy_tip_rounded,
                  color: Colors.green.shade700,
                  title: 'Privacy Policy',
                  subtitle: 'How we handle your data',
                  onTap: () {
                    _launchURL(
                      'https://thingdoms.web.app/bunkmate/privacy-policy',
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.gavel_rounded,
                  color: Colors.brown,
                  title: 'Terms of Service',
                  subtitle: 'The rules of use',
                  onTap: () {
                    _launchURL(
                      'https://thingdoms.web.app/bunkmate/terms-of-service',
                    );
                  },
                ),
                _buildSettingsTile(
                  context: context,
                  icon: Icons.copy_all_rounded,
                  color: Colors.indigoAccent,
                  title: 'Copy Debug Info',
                  subtitle: 'Helpful for support requests',
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await Clipboard.setData(
                      ClipboardData(
                        text:
                            'App Version: $_appVersion\n(Add other device info if needed)',
                      ),
                    );
                    showTopToast('Debug info copied to clipboard!');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // --- DANGER ZONE ---
          _buildSectionHeader(
            context,
            'Danger Zone',
            Icons.warning_rounded,
            Colors.redAccent,
          ),
          CustomCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildSettingsTile(
              context: context,
              icon: Icons.delete_forever_rounded,
              color: Colors.red.shade700,
              title: 'Reset All Settings',
              titleColor: Colors.red.shade700,
              subtitle: 'Restores all settings to their defaults',
              onTap: () => _showResetConfirmation(context, settingsProvider),
            ),
          ),

          const SizedBox(height: 40), // Extra space before footer
          // ✨ FIX: The footer is now safely at the very bottom of the list!
          SafeArea(
            top: false,
            child: GestureDetector(
              onLongPress: () {
                if (_easterEggTriggered) return;
                _easterEggTriggered = true;
                HapticFeedback.heavyImpact();
                showTopToast('🗿 You found the bunker.');
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AboutBunkMateSheet(),
                );
              },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _footerQuote,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        letterSpacing: 0.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '© ${DateTime.now().year} BunkMate ╭(◔ ◡ ◔)/\nMade with ❤️',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✨ THE NEW PREMIUM HERO CARD ✨
  Widget _buildPremiumHeroCard(
    BuildContext context,
    PremiumProvider premium,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () {
        if (!premium.isPremium) {
          HapticFeedback.mediumImpact();
          showPremiumPaywall(context);
        } else {
          HapticFeedback.lightImpact();
          showTopToast('🔮 You are a Pro BunkER🗿!');
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            // ✨ PRO = Deep Purple/Pink, FREE = Blue/Cyan
            colors: premium.isPremium
                ? [
                    Colors.deepPurpleAccent.shade400.withOpacity(
                      isDark ? 0.4 : 0.9,
                    ),
                    Colors.purpleAccent.withOpacity(isDark ? 0.2 : 0.7),
                  ]
                : [
                    Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(isDark ? 0.2 : 0.8),
                    Colors.cyan.withOpacity(isDark ? 0.1 : 0.6),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: premium.isPremium
                ? Colors.purpleAccent.withOpacity(0.5)
                : Colors.white.withOpacity(0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (premium.isPremium ? Colors.deepPurpleAccent : Colors.blue)
                  .withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                premium.isPremium
                    ? Icons.auto_awesome_rounded
                    : Icons.rocket_launch_rounded, // Changed crown to sparkles
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    premium.isPremium
                        ? 'BunkER PRO Active ✨'
                        : 'Unlock BunkER PRO 🗿',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    premium.isPremium
                        ? 'You have access to all premium features.'
                        : 'Remove ads, get 5 saves, and proactive alerts.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (!premium.isPremium) ...[
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Tile Builders (Unchanged logic, just keeping structure) ---
  Widget _buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Color? titleColor,
    required VoidCallback? onTap,
    Widget? trailingWidget,
  }) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: 1.0),
      duration: const Duration(milliseconds: 120),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: titleColor ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing:
            trailingWidget ??
            (onTap != null
                ? const Icon(Icons.arrow_forward_ios_rounded, size: 16)
                : null),
        onTap: () {
          if (onTap != null) {
            HapticFeedback.lightImpact();
            onTap();
          }
        },
        enabled: onTap != null,
      ),
    );
  }

  Widget _buildSettingsToggle({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    Widget? trailingWidget,
    bool enableTileTap = true,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing:
          trailingWidget ??
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: theme.colorScheme.primary,
          ),
      onTap: enableTileTap
          ? () {
              HapticFeedback.lightImpact();
              onChanged(!value);
            }
          : null,
    );
  }

  Widget _buildSettingsRadio<T>({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required T value,
    required T groupValue,
    required Function(T?) onChanged,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Radio<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
      ),
      onTap: () {
        if (value != groupValue) {
          onChanged(value);
        }
      },
    );
  }
}
