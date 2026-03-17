import 'dart:ui' as dart_ui;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

void showPremiumPaywall(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const PremiumSheet(),
  );
}

class PremiumSheet extends StatefulWidget {
  const PremiumSheet({super.key});

  @override
  State<PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<PremiumSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  int _selectedPlanIndex = 1; // 0 = Month, 1 = Semesters, 2 = Lifetime
  double _semesterCount = 1;

  final int _fallbackPriceMonth = 29;
  final int _fallbackPriceSem = 59;
  final int _fallbackPriceLifetime = 399;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  // --- DYNAMIC REVENUECAT LOGIC ---
  String get _selectedProductId {
    if (_selectedPlanIndex == 0) {
      // ✨ FIX: Use the exact combined string that RevenueCat expects for modern Google Subscriptions
      return 'bunker_pro_monthly:monthly-base';
    }
    if (_selectedPlanIndex == 2) return 'bunker_pro_lifetime';
    return 'bunker_pro_sem_${_semesterCount.toInt()}';
  }

  StoreProduct? get _targetProduct {
    return context.read<PremiumProvider>().getProductById(_selectedProductId);
  }

  // int get _calculatedDiscountPercent {
  //   if (_selectedPlanIndex != 1 || _semesterCount == 1) return 0;

  //   final provider = context.read<PremiumProvider>();
  //   final baseSemProduct = provider.getProductById('bunker_pro_sem_1');
  //   final targetSemProduct = _targetProduct;

  //   if (baseSemProduct != null && targetSemProduct != null) {
  //     double rawOriginalPrice = baseSemProduct.price * _semesterCount;
  //     double actualBulkPrice = targetSemProduct.price;
  //     if (rawOriginalPrice <= 0) return 0;
  //     return (((rawOriginalPrice - actualBulkPrice) / rawOriginalPrice) * 100)
  //         .round();
  //   }

  //   int sems = _semesterCount.toInt();
  //   return min((sems - 1) * 10, 50);
  // }

  int get _calculatedDiscountPercent {
    final provider = context.read<PremiumProvider>();

    // 1. MONTHLY ANCHOR (Create a 50% "Launch Sale" craving)
    if (_selectedPlanIndex == 0) return 50;

    // 2. LIFETIME ANCHOR (Compare vs 4 years of Monthly)
    if (_selectedPlanIndex == 2) {
      final monthProduct = provider.getProductById(
        'bunker_pro_monthly:monthly-base',
      );
      final lifetimeProduct = _targetProduct;

      if (monthProduct != null && lifetimeProduct != null) {
        double rawMonthly4Years = monthProduct.price * 48; // Cost of 4 years
        double lifePrice = lifetimeProduct.price;
        if (rawMonthly4Years > lifePrice) {
          return (((rawMonthly4Years - lifePrice) / rawMonthly4Years) * 100)
              .round();
        }
      }
      return 75; // Fallback massive discount if network hasn't loaded
    }

    // 3. SEMESTERS ANCHOR (Your original flawless math)
    if (_semesterCount == 1) return 0;

    final baseSemProduct = provider.getProductById('bunker_pro_sem_1');
    final targetSemProduct = _targetProduct;

    if (baseSemProduct != null && targetSemProduct != null) {
      double rawOriginalPrice = baseSemProduct.price * _semesterCount;
      double actualBulkPrice = targetSemProduct.price;
      if (rawOriginalPrice <= 0) return 0;
      return (((rawOriginalPrice - actualBulkPrice) / rawOriginalPrice) * 100)
          .round();
    }

    int sems = _semesterCount.toInt();
    return min((sems - 1) * 10, 50);
  }

  String get _displayPrice {
    if (_targetProduct != null) {
      return _targetProduct!.priceString;
    }
    if (_selectedPlanIndex == 0) return '₹$_fallbackPriceMonth';
    if (_selectedPlanIndex == 2) return '₹$_fallbackPriceLifetime';
    int rawPrice = _semesterCount.toInt() * _fallbackPriceSem;
    return '₹${(rawPrice * (1 - (_calculatedDiscountPercent / 100))).round()}';
  }

  String get _originalPriceStrikethrough {
    final provider = context.read<PremiumProvider>();

    // 1. MONTHLY STRIKETHROUGH (Double the current price)
    if (_selectedPlanIndex == 0) {
      final target = _targetProduct;
      if (target != null) {
        // Extract the symbol (e.g. ₹ or $) by removing the numbers from the priceString
        String symbol = target.priceString
            .replaceAll(RegExp(r'[0-9.,]'), '')
            .trim();
        return '$symbol${(target.price * 2).toStringAsFixed(0)}';
      }
      return '₹${_fallbackPriceMonth * 2}';
    }

    // 2. LIFETIME STRIKETHROUGH (Cost of 48 months)
    if (_selectedPlanIndex == 2) {
      final monthProduct = provider.getProductById(
        'bunker_pro_monthly:monthly-base',
      );
      if (monthProduct != null) {
        String symbol = monthProduct.priceString
            .replaceAll(RegExp(r'[0-9.,]'), '')
            .trim();
        return '$symbol${(monthProduct.price * 48).toStringAsFixed(0)}';
      }
      return '₹${_fallbackPriceMonth * 48}';
    }

    // 3. SEMESTERS STRIKETHROUGH
    final baseSemProduct = provider.getProductById('bunker_pro_sem_1');
    if (baseSemProduct != null) {
      String symbol = baseSemProduct.priceString
          .replaceAll(RegExp(r'[0-9.,]'), '')
          .trim();
      double rawOriginalPrice = baseSemProduct.price * _semesterCount;
      return '$symbol${rawOriginalPrice.toStringAsFixed(0)}';
    }
    return '₹${_semesterCount.toInt() * _fallbackPriceSem}';
  }

  // Helper to format dates nicely
  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }

  // --- ACTUAL SECURE PURCHASE WITH STACKING INTERCEPTOR ---
  // --- ACTUAL SECURE PURCHASE WITH STACKING INTERCEPTOR ---
  Future<void> _handlePurchase() async {
    final provider = context.read<PremiumProvider>();

    // ✨ THE EXTENSION INTERCEPTOR: Warn them if they are stacking!
    if (_selectedPlanIndex == 1 && provider.semesterExpiryDate != null) {
      int addedDays = _semesterCount.toInt() * 180;
      DateTime newExpiry = provider.semesterExpiryDate!.add(
        Duration(days: addedDays),
      );

      bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final theme = Theme.of(ctx);
          final isDark = theme.brightness == Brightness.dark;
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            backgroundColor: theme.scaffoldBackgroundColor,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(24),
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
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      size: 36,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Extend Pro Access?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.5,
                        color: theme.hintColor,
                      ),
                      children: [
                        const TextSpan(
                          text: 'You already have BunkER Pro until ',
                        ),
                        TextSpan(
                          text: _formatDate(provider.semesterExpiryDate!),
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(text: '.\n\nAdding '),
                        TextSpan(
                          text: '${_semesterCount.toInt()} more semester(s)',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' will stack on top of your current plan, extending your Pro access by ',
                        ),
                        TextSpan(
                          text: '$addedDays days',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const TextSpan(
                          text: '.\n\nYour new expiration date will be: ',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(newExpiry),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.purpleAccent,
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
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurpleAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Extend Now',
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

      if (proceed != true) return; // User hit cancel
    }

    // --- Process the actual purchase ---
    try {
      showTopToast('⏳ Securely connecting to Play Store...');
      // print("RC: attempting purchase for $_selectedProductId");

      StoreProduct? productToBuy = _targetProduct;

      // We just await the purchase, we don't need to save the result
      // because we fetch the fresh CustomerInfo right after!
      if (productToBuy != null) {
        await Purchases.purchaseStoreProduct(productToBuy);
      } else {
        await Purchases.purchaseProduct(_selectedProductId);
      }

      // Grab the fresh data from RevenueCat
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();

      if (customerInfo.entitlements.all["pro"]?.isActive == true ||
          customerInfo.nonSubscriptionTransactions.isNotEmpty) {
        if (!mounted) return;
        await context.read<PremiumProvider>().refreshPremiumStatus();

        HapticFeedback.heavyImpact();
        Navigator.pop(context);
        showTopToast('✨ Purchase Successful! Welcome to BunkER Pro.');
      }
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        // print("RC PURCHASE ERROR: $e");
        showErrorToast('Purchase failed or unavailable right now.');
      }
    }
  }

  // --- RESTORE PURCHASES ---
  Future<void> _handleRestore() async {
    try {
      showTopToast('🔍 Checking for previous purchases...');
      CustomerInfo customerInfo = await Purchases.restorePurchases();

      // Ensure we check for nonSubscriptionTransactions here too, so consumable stacking restores properly!
      if (customerInfo.entitlements.all["pro"]?.isActive == true ||
          customerInfo.nonSubscriptionTransactions.isNotEmpty) {
        if (!mounted) return;
        await context.read<PremiumProvider>().refreshPremiumStatus();

        // Final sanity check to make sure the math actually proved they are still Premium today
        if (context.read<PremiumProvider>().isPremium) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context);
          showTopToast('✨ Purchases Restored! Welcome back.');
        } else {
          showErrorToast('Your previous semester passes have expired.');
        }
      } else {
        showErrorToast('No active Pro subscription found on this account.');
      }
    } catch (e) {
      showErrorToast('Failed to restore purchases.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<PremiumProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
          child: BackdropFilter(
            filter: dart_ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor.withOpacity(
                  isDark ? 0.85 : 0.95,
                ),
                border: Border(
                  top: BorderSide(
                    color: Colors.purpleAccent.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Ambient Neon Purple Glow
                  Positioned(
                    top: -50,
                    child: AnimatedBuilder(
                      animation: _glowAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 300,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurpleAccent.withOpacity(
                                  _glowAnimation.value * 0.4,
                                ),
                                blurRadius: 100,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Column(
                    children: [
                      // Drag Handle
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      Expanded(
                        child: ListView(
                          controller: controller,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          children: [
                            // Header Icon
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.deepPurpleAccent.withOpacity(
                                    0.15,
                                  ),
                                  border: Border.all(
                                    color: Colors.purpleAccent.withOpacity(0.5),
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.diamond_rounded,
                                  size: 48,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              'BunkER Pro',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Unlock the ultimate attendance arsenal.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.hintColor,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Features List
                            _buildFeatureRow(
                              theme,
                              Icons.notifications_active_rounded,
                              'Proactive Morning Alerts',
                              'Get a push notification at 8 AM if you are in the danger zone.',
                            ),
                            _buildFeatureRow(
                              theme,
                              Icons.save_rounded,
                              '5 Dedicated Save Slots',
                              'Track multiple semesters or different subjects at once.',
                            ),
                            _buildFeatureRow(
                              theme,
                              Icons.block_flipped,
                              'Zero Ads. Zero Interruptions',
                              'Pure speed. Never see another ad again.',
                            ),
                            _buildFeatureRow(
                              theme,
                              Icons.flight_takeoff_rounded,
                              'Unlimited Holiday Planning',
                              'Plan your vacations with zero cooldowns.',
                            ),
                            _buildFeatureRow(
                              theme,
                              Icons.auto_graph,
                              'Unlimited Absence Analysis',
                              'Analyze your time limitlessly.',
                            ),

                            const SizedBox(height: 32),
                            const Divider(height: 1),
                            const SizedBox(height: 24),

                            // --- GAMIFIED PRICING ENGINE ---
                            Text(
                              'Choose Your Arsenal',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 1. Plan Selector Tabs
                            Container(
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: theme.dividerColor.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  _buildTab(0, '1 Month', Icons.calendar_today),
                                  _buildTab(
                                    1,
                                    'Semesters',
                                    Icons.school_rounded,
                                  ),
                                  _buildTab(
                                    2,
                                    'Lifetime',
                                    Icons.all_inclusive_rounded,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // 2. Dynamic Slider
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              child: _selectedPlanIndex == 1
                                  ? _buildSemesterSlider(theme)
                                  : const SizedBox.shrink(),
                            ),

                            // 3. Price Display
                            _buildPriceDisplay(
                              theme,
                              provider.isLoadingPricing,
                            ),
                            const SizedBox(height: 32),

                            // 4. Action Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: provider.isLoadingPricing
                                    ? null
                                    : _handlePurchase,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.deepPurpleAccent
                                      .withOpacity(0.5),
                                ),
                                child: provider.isLoadingPricing
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Unlock Pro • $_displayPrice',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 5. Restore Purchases & Tip
                            Column(
                              children: [
                                TextButton(
                                  onPressed: _handleRestore,
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    'Already bought Pro? Restore Purchases',
                                    style: TextStyle(
                                      color: theme.hintColor,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                      decorationColor: theme.hintColor
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 12,
                                      color: theme.hintColor.withOpacity(0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Must use the same App Store/Play Store account',
                                      style: TextStyle(
                                        color: theme.hintColor.withOpacity(0.6),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],
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

  // --- UI Components ---

  Widget _buildTab(int index, String title, IconData icon) {
    final isSelected = _selectedPlanIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedPlanIndex = index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.deepPurpleAccent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? Colors.deepPurpleAccent.withOpacity(0.5)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.purpleAccent : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: isSelected ? Colors.purpleAccent : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSemesterSlider(ThemeData theme) {
    final sems = _semesterCount.toInt();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Duration',
              style: TextStyle(
                color: theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            RichText(
              text: TextSpan(
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                children: [
                  TextSpan(
                    text: '$sems',
                    style: const TextStyle(
                      color: Colors.purpleAccent,
                      fontSize: 20,
                    ),
                  ),
                  TextSpan(text: sems == 1 ? ' Semester' : ' Semesters'),
                  if (sems == 8)
                    const TextSpan(text: ' 🎓', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Colors.deepPurpleAccent,
            inactiveTrackColor: theme.dividerColor.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: Colors.purpleAccent.withOpacity(0.2),
            trackHeight: 8,
          ),
          child: Slider(
            value: _semesterCount,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (val) {
              if (val != _semesterCount) HapticFeedback.selectionClick();
              setState(() => _semesterCount = val);
            },
          ),
        ),
        if (_calculatedDiscountPercent > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Text(
              'Sem pricing active! You are getting $_calculatedDiscountPercent% off.',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPriceDisplay(ThemeData theme, bool isLoading) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.deepPurpleAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.purpleAccent),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.deepPurpleAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.deepPurpleAccent.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Price',
                style: TextStyle(
                  color: theme.hintColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _displayPrice,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  // ✨ FIX: Removed the _selectedPlanIndex == 1 check so it shows everywhere!
                  if (_calculatedDiscountPercent > 0) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _originalPriceStrikethrough,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: Colors.redAccent,
                          decorationThickness: 2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // ✨ FIX: Show the Green SAVE pill on all tabs if there is a discount
          if (_calculatedDiscountPercent > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.greenAccent.shade400.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.greenAccent),
              ),
              child: Column(
                children: [
                  Text(
                    // Bonus: Show 'BEST VALUE' on Lifetime to make it pop even more
                    _selectedPlanIndex == 2 ? 'BEST VALUE' : 'SAVE',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '$_calculatedDiscountPercent%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(
    ThemeData theme,
    IconData icon,
    String title,
    String desc,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.deepPurpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.purpleAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
