import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:bunkmate/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _loaded = false;
  Timer? _refreshTimer;

  bool? _currentAdIsDark;
  Timer? _themeChangeDebounce; // ✨ THE SAFETY TIMER (Crucial for AdMob Health)

  @override
  void initState() {
    super.initState();
    RemoteConfigService.instance.addListener(_onConfigChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final isDark = Provider.of<ThemeProvider>(
          context,
          listen: false,
        ).isDarkMode;
        _currentAdIsDark = isDark;
        _loadAd(isDark);
      }
    });

    // Refresh ad every 30 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      _reloadAd();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;

    if (_currentAdIsDark == null) {
      _currentAdIsDark = isDark;
      _loadAd(isDark);
    } else if (_currentAdIsDark != isDark) {
      _currentAdIsDark = isDark;

      // ✨ CANCEL previous requests if the user is spamming the button
      _themeChangeDebounce?.cancel();

      // ✨ Wait 800 milliseconds before actually requesting the new ad
      _themeChangeDebounce = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          _reloadAd();
        }
      });
    }
  }

  void _onConfigChanged() {
    if (mounted) _reloadAd();
  }

  void _reloadAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
    _loaded = false;
    if (mounted) {
      setState(() {});
      final isDark = Provider.of<ThemeProvider>(
        context,
        listen: false,
      ).isDarkMode;
      _loadAd(isDark);
    }
  }

  void _loadAd(bool isDark) {
    if (!mounted) return;

    final adsEnabled = RemoteConfigService.instance.nativeEnabled;

    if (!adsEnabled) {
      _loaded = false;
      _nativeAd?.dispose();
      _nativeAd = null;
      if (mounted) setState(() {});
      return;
    }

    if (_nativeAd != null || _loaded) return;

    _nativeAd = NativeAd(
      adUnitId: AdService.instance.nativeAdUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: isDark
            ? const Color(0xFF1E1E24)
            : Colors.grey.shade100,
        cornerRadius: 16.0,
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark ? Colors.white : Colors.black87,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark ? Colors.white70 : Colors.black54,
          size: 14.0,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: isDark ? Colors.white70 : Colors.black54,
          size: 14.0,
        ),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.blue.shade700,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeAd = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _themeChangeDebounce?.cancel(); // ✨ Clean up timer to prevent memory leaks
    RemoteConfigService.instance.removeListener(_onConfigChanged);
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _nativeAd == null) return const SizedBox.shrink();

    final isDark = _currentAdIsDark ?? true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 340,
        width: double.infinity,
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
