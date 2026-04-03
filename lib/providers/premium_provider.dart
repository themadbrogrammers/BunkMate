import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✨ NEW: For the security check
import 'package:workmanager/workmanager.dart'; // ✨ NEW: To kill the background task

class PremiumProvider with ChangeNotifier {
  bool _isPremiumFlag = false;
  bool _isLoadingPricing = true;
  List<StoreProduct> _storeProducts = [];

  // ✨ NEW: Tracks exactly when their stacked semesters expire
  DateTime? _semesterExpiryDate;

  // --- Getters ---
  bool get isPremium => _isPremiumFlag;
  bool get isLoadingPricing => _isLoadingPricing;
  int get maxSaves => _isPremiumFlag ? 5 : 1;
  List<StoreProduct> get storeProducts => _storeProducts;
  DateTime? get semesterExpiryDate =>
      _semesterExpiryDate; // ✨ Exposed for the UI

  // ✨ FIX 1: The Live Listener
  // Watches RevenueCat in the background. If a subscription expires
  // or renews while the app is open, this triggers automatically!
  PremiumProvider() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      _processCustomerInfo(customerInfo);
    });
  }

  // --- Core Methods ---

  /// Called when the app starts. RevenueCat caches this locally.
  /// Called when the app starts. Fetches dynamic Offerings from RevenueCat.
  Future<void> load() async {
    _isLoadingPricing = true;
    notifyListeners();

    try {
      // 1. Get current user status
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      await _processCustomerInfo(customerInfo);

      // print("RC: Fetching dynamic Offerings...");

      // 2. ✨ THE UPGRADE: Fetch Offerings instead of hardcoded strings
      Offerings offerings = await Purchases.getOfferings();

      if (offerings.current != null &&
          offerings.current!.availablePackages.isNotEmpty) {
        // Extract the StoreProducts from the available packages
        // This keeps your existing UI logic perfectly intact!
        _storeProducts = offerings.current!.availablePackages
            .map((package) => package.storeProduct)
            .toList();

        // print(
        //   "RC: Successfully loaded ${_storeProducts.length} products from Offerings!",
        // );
      } else {
        // print(
        //   "RC WARNING: No current offering found. Check RevenueCat Dashboard.",
        // );
      }
    } catch (e) {
      debugPrint("RevenueCat Load Error: $e");
    } finally {
      _isLoadingPricing = false;
      notifyListeners();
    }
  }

  /// ✨ Extracts the math and security checks so the Live Listener can use it too
  Future<void> _processCustomerInfo(CustomerInfo customerInfo) async {
    // 1. Check Standard Entitlements (Monthly Sub & Lifetime)
    bool hasEntitlement =
        customerInfo.entitlements.all["pro"]?.isActive == true;

    // 2. ✨ THE MAGIC STACKING ENGINE
    bool hasActiveSemester = false;
    DateTime? calculatedExpiry;

    // Get all consumable transactions and sort them chronologically (oldest to newest)
    List<StoreTransaction> semTransactions = customerInfo
        .nonSubscriptionTransactions
        .where((t) => t.productIdentifier.startsWith('bunker_pro_sem_'))
        .toList();

    semTransactions.sort(
      (a, b) => DateTime.parse(
        a.purchaseDate,
      ).compareTo(DateTime.parse(b.purchaseDate)),
    );

    // Stack them up!
    for (var transaction in semTransactions) {
      try {
        int sems = int.parse(transaction.productIdentifier.split('_').last);
        int daysAllowed = sems * 180;
        DateTime pDate = DateTime.parse(transaction.purchaseDate);

        // If this is the first purchase, OR their previous pass expired before they bought this one:
        if (calculatedExpiry == null || calculatedExpiry!.isBefore(pDate)) {
          calculatedExpiry = pDate.add(Duration(days: daysAllowed));
        } else {
          // They bought this WHILE they still had an active pass! Stack the days on top!
          calculatedExpiry = calculatedExpiry!.add(Duration(days: daysAllowed));
        }
      } catch (e) {
        debugPrint("Error parsing semester transaction: $e");
      }
    }

    // Check if the final stacked date is still in the future
    if (calculatedExpiry != null && calculatedExpiry!.isAfter(DateTime.now())) {
      hasActiveSemester = true;
      _semesterExpiryDate = calculatedExpiry;
    } else {
      _semesterExpiryDate = null;
    }

    // Combine both checks to see if they are currently Pro
    bool newPremiumStatus = hasEntitlement || hasActiveSemester;

    // ✨ FIX 2: THE SECURITY CHECK (Strips features if subscription expires)
    if (!newPremiumStatus) {
      final prefs = await SharedPreferences.getInstance();

      // If the switch is still stuck on, forcefully turn it off!
      if (prefs.getBool('proactive_alerts') == true) {
        await prefs.setBool('proactive_alerts', false);

        // Safely kill the background robot immediately
        try {
          Workmanager().cancelAll();
        } catch (_) {}
      }
    }

    // Apply the final status to the app's state
    if (_isPremiumFlag != newPremiumStatus ||
        _semesterExpiryDate != calculatedExpiry) {
      _isPremiumFlag = newPremiumStatus;
      notifyListeners();
    }
  }

  StoreProduct? getProductById(String id) {
    try {
      return _storeProducts.firstWhere((product) {
        // 1. Exact match (perfect for lifetime and semesters)
        if (product.identifier == id) return true;

        // 2. Base plan match (perfect for subscriptions).
        // Adding the ':' prevents "sem_1" from accidentally matching "sem_10"!
        if (product.identifier.startsWith('$id:')) return true;

        return false;
      });
    } catch (e) {
      return null; // Return null safely if it hasn't loaded yet
    }
  }

  Future<void> refreshPremiumStatus() async {
    await load();
  }
}
