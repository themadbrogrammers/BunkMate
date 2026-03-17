import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/services/remote_config_service.dart';
import 'package:provider/provider.dart';

class BannerAdWidget extends StatefulWidget {
  final String adUnitId;

  const BannerAdWidget({
    super.key,
    required this.adUnitId, // Make it required
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  // Reload ad if the adUnitId changes (e.g., navigating between pages with banners)
  @override
  void didUpdateWidget(covariant BannerAdWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.adUnitId != oldWidget.adUnitId) {
      print("Ad Unit ID changed, reloading banner.");
      _loadAd(); // Reload with the new ID
    }
  }

  void _loadAd() {
    if (!RemoteConfigService.instance.adsEnabled) {
      print(
        "BannerAdWidget: Ads are disabled by Remote Config. Skipping banner load.",
      );
      return;
    }

    final adUnitId = widget.adUnitId;
    // final adUnitId = AdService.instance.bannerAdUnitId;
    if (adUnitId.isEmpty) {
      print("Banner Ad Unit ID is empty. Skipping banner ad load.");
      // Clean up previous ad if any
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) setState(() => _isLoaded = false);
      return;
    }

    // Dispose previous ad before loading new one
    _bannerAd?.dispose();
    _bannerAd = null;
    if (mounted) setState(() => _isLoaded = false); // Reset loaded state

    _bannerAd = BannerAd(
      adUnitId: adUnitId, // Use the specific ID
      request: const AdRequest(),
      size: AdSize.banner, // Or adaptive banner size
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('BannerAd loaded: ${ad.adUnitId}'); // Log which ad loaded
          if (mounted) {
            setState(() {
              // Check if the loaded ad still matches the current widget's ID
              // This handles cases where the ID changes quickly before load finishes
              if (_bannerAd == ad) {
                _isLoaded = true;
              } else {
                ad.dispose(); // Dispose the ad if it's not the current one needed
              }
            });
          } else {
            ad.dispose(); // Dispose if widget is no longer mounted
          }
        },
        onAdFailedToLoad: (ad, err) {
          print('BannerAd failed to load (${ad.adUnitId}): $err');
          ad.dispose();
          if (mounted && _bannerAd == ad) {
            // Only clear if it was the current attempt
            _bannerAd = null;
            _isLoaded = false; // Ensure it's marked as not loaded
            // Optionally add retry logic here if desired
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: RemoteConfigService.instance,
      builder: (_, __) {
        final rc = RemoteConfigService.instance;

        if (rc.adsEnabled && _bannerAd == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAd();
          });
        }

        if (!rc.adsEnabled || _bannerAd == null || !_isLoaded) {
          return const SizedBox.shrink();
        }

        return Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        );
      },
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   if (_bannerAd != null && _isLoaded) {
  //     return Container(
  //       alignment: Alignment.center,
  //       width: _bannerAd!.size.width.toDouble(),
  //       height: _bannerAd!.size.height.toDouble(),
  //       // Consider adding some vertical margin/padding if needed
  //       // margin: const EdgeInsets.symmetric(vertical: 4.0),
  //       child: AdWidget(ad: _bannerAd!),
  //     );
  //   } else {
  //     // return SizedBox(
  //     //   // Use standard banner height, or adaptive height logic if using adaptive banners
  //     //   height: AdSize.banner.height.toDouble(),
  //     //   width: AdSize.banner.width.toDouble(),
  //     //   // Optionally add a subtle background or indicator
  //     //   // child: Center(child: Text('Ad loading...', style: TextStyle(fontSize: 10))),
  //     // );
  //     return const SizedBox.shrink();
  //   }
  // }
}
