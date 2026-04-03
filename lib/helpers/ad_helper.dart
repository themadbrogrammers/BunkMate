import 'dart:ui' as dart_ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // ✨ NEW: For Consumer
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/widgets/premium_sheet.dart';
import 'package:bunkmate/providers/premium_provider.dart'; // ✨ NEW: To fetch the price

void _forceKillKeyboard() {
  FocusManager.instance.primaryFocus?.unfocus();
  FocusManager.instance.rootScope.requestFocus(FocusNode());
  SystemChannels.textInput.invokeMethod('TextInput.hide');
}

void showRewardedAdDialog({
  required BuildContext context,
  required String title,
  required String content,
  required VoidCallback onReward,
}) {
  _forceKillKeyboard();
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  HapticFeedback.mediumImpact();

  showDialog(
    context: context,
    barrierDismissible: true, // Allow tapping outside to close
    builder: (ctx) {
      bool isLoadingAd = false;

      return StatefulBuilder(
        builder: (context, setState) {
          // ✨ WRAP IN CONSUMER to get live price and watch purchase status
          return Consumer<PremiumProvider>(
            builder: (context, premium, child) {
              // ✨ AUTO-CLOSE TRICK: If they buy Pro in the bottom sheet,
              // this dialog will realize they are premium and close itself!
              if (premium.isPremium) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (Navigator.of(ctx).mounted && Navigator.of(ctx).canPop()) {
                    Navigator.of(ctx).pop();
                  }
                });
              }

              // ✨ Fetch the lowest Monthly price directly from Google Play!
              final monthlyProduct =
                  premium.getProductById('bunker_pro_monthly:monthly-base') ??
                  premium.getProductById('bunker_pro_monthly');
              final priceStr =
                  monthlyProduct?.priceString ??
                  '₹19.00'; // Fallback just in case

              return Dialog(
                alignment: const Alignment(0, -0.15),
                insetPadding: const EdgeInsets.symmetric(horizontal: 24),
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.deepPurpleAccent.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurpleAccent.withOpacity(
                          isDark ? 0.15 : 0.1,
                        ),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // --- Floating Close Button ---
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.dividerColor.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: theme.hintColor,
                            ),
                          ),
                        ),
                      ),

                      // --- Hero Icon ---
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurpleAccent.withOpacity(0.1),
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 42,
                          color: Colors.deepPurpleAccent,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // --- Title & Content ---
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        content,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.hintColor,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),

                      // --- PATH 1: THE PRO UPSELL (Highly Prominent) ---
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepPurpleAccent.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style:
                              ElevatedButton.styleFrom(
                                padding: EdgeInsets
                                    .zero, // Removed padding so Ink can fill it
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ).copyWith(
                                backgroundColor: MaterialStateProperty.all(
                                  Colors.transparent,
                                ),
                              ),
                          onPressed: () {
                            HapticFeedback.heavyImpact();
                            // ✨ FIX: We DO NOT pop the dialog anymore!
                            // It will stay open underneath the Premium Sheet.
                            showPremiumPaywall(context);
                          },
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Colors.deepPurpleAccent,
                                  Colors.purpleAccent,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ), // Adjusted for two lines
                              constraints: const BoxConstraints(minHeight: 60),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(
                                        Icons.diamond_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Unlock Forever with Pro',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  // ✨ NEW: Dynamic Price Display!
                                  Text(
                                    'Only $priceStr / month',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // --- OR DIVIDER ---
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.hintColor.withOpacity(0.5),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: theme.dividerColor.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- PATH 2: THE AD ROUTE (Secondary) ---
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              width: 1.5,
                            ),
                            backgroundColor: theme.colorScheme.primary
                                .withOpacity(0.05),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: isLoadingAd
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  setState(() => isLoadingAd = true);

                                  AdService.instance.showRewardedAd(
                                    onReward: () {
                                      _forceKillKeyboard();
                                      if (Navigator.of(ctx).canPop()) {
                                        Navigator.of(ctx).pop();
                                      }
                                      onReward();
                                    },
                                  );

                                  // ⏱ Safety reset in case ad fails silently
                                  Future.delayed(
                                    const Duration(seconds: 5),
                                    () {
                                      if (Navigator.of(ctx).mounted) {
                                        setState(() => isLoadingAd = false);
                                      }
                                    },
                                  );
                                },
                          child: isLoadingAd
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Loading Ad...',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Watch Ad (Unlocks for 1h)',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
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
            },
          );
        },
      );
    },
  );
}
