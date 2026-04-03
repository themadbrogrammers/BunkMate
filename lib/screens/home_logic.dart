import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'package:bunkmate/providers/attendance_provider.dart';
import 'package:bunkmate/providers/ad_provider.dart';
import 'package:bunkmate/providers/premium_provider.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:bunkmate/navigation/app_visibility_service.dart';
import 'package:bunkmate/helpers/toast_helper.dart';
import 'package:bunkmate/widgets/max_drop_overlay.dart';

import 'home_page.dart';

class HomeLogic {
  /// Syncs controllers if they aren't currently being edited by the user
  static void syncControllersWithProvider(HomePageState state, AttendanceProvider provider) {
    if (!state.targetFocusNode.hasFocus &&
        state.targetPercentController.text != provider.targetPercentage.toString()) {
      state.targetPercentController.text = provider.targetPercentage.toString();
    }

    final bool rawDataHasFocus = FocusScope.of(state.context).focusedChild?.toString().contains('EditableText') ?? false;
    if (!rawDataHasFocus && state.rawDataController.text != provider.rawData) {
      state.rawDataController.value = TextEditingValue(
        text: provider.rawData,
        selection: TextSelection.collapsed(offset: provider.rawData.length),
      );
    }
  }

  static void initializeControllers(HomePageState state) {
    if (!state.mounted) return;
    final provider = Provider.of<AttendanceProvider>(state.context, listen: false);
    state.targetPercentController.text = provider.targetPercentage.toString();
    if (state.rawDataController.text.isEmpty && provider.rawData.isNotEmpty) {
      state.rawDataController.text = provider.rawData;
    }
  }

  static void handleCalculate(HomePageState state) {
    // state.calcTriggered = true;
    state.celebrationPlayed = false;
    // state.scrolledAfterCalc = false;

    FocusScope.of(state.context).unfocus();
    commitTargetPercentage(state);

    final provider = state.context.read<AttendanceProvider>();
    provider.updateRawDataWithoutCalc(state.rawDataController.text);
    provider.calculateHours();
  }

  static void commitTargetPercentage(HomePageState state) {
    final provider = state.context.read<AttendanceProvider>();
    final value = int.tryParse(state.targetPercentController.text);

    if (value == null || value < 0 || value > 100) {
      state.targetPercentController.text = provider.targetPercentage.toString();
      return;
    }
    if (value != provider.targetPercentage) {
      provider.setTargetPercentage(value);
    }
  }

  static Future<void> handlePaste(HomePageState state) async {
    final provider = Provider.of<AttendanceProvider>(state.context, listen: false);
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pastedText = clipboardData?.text;
      if (pastedText != null && pastedText.isNotEmpty) {
        // state.scrollAfterPaste = true;
        // state.scrolledAfterCalc = false;
        // state.calcTriggered = false;
        state.rawDataController.text = pastedText;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!state.mounted) return;
          provider.setRawData(pastedText, newFileName: 'Pasted from clipboard');
          showTopToast('📋 Pasted from clipboard!');
        });

        FocusScope.of(state.context).unfocus();
        if (!state.showRawDataInput) state.setState(() => state.showRawDataInput = true);
      } else {
        showTopToast('Clipboard is empty.');
      }
    } catch (e) {
      showTopToast('❌ Error pasting: ${e.toString()}', backgroundColor: Colors.red.shade700);
    }
  }

  // static void orchestrateScroll(HomePageState state) {
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (!state.mounted) return;
      
  //     // Use a small delay to ensure the UI has finished expanding
  //     Future.delayed(const Duration(milliseconds: 100), () {
  //       final ctx = state.resultsKey.currentContext;
  //       if (ctx == null || state.scrolledAfterCalc) return;

  //       state.scrolledAfterCalc = true;
  //       state.calcTriggered = false;
  //       state.scrollAfterPaste = false;

  //       Scrollable.ensureVisible(
  //         ctx,
  //         duration: const Duration(milliseconds: 600),
  //         curve: Curves.easeOutCubic, // Smoother than easeInOut for results
  //         alignment: 0.15,
  //       );
  //     });
  //   });
  // }

  static void handleSuccessState(HomePageState state, AttendanceProvider provider, VoidCallback onUpdate,) {
    final bool isGoodState = provider.result.requiredToAttend <= 0;

    if (isGoodState && !state.celebrationPlayed) {
      state.celebrationPlayed = true;
      HapticFeedback.lightImpact();
      if (provider.result.maxDroppableHours >= 5) {
        HapticFeedback.selectionClick();
      }
    }

    onUpdate();
    Future.delayed(const Duration(milliseconds: 450), () {
      if (state.mounted) onUpdate();
    });

    _tryShowMaxDropOverlay(state, provider);
    _handleInterstitialAds(state, provider);

    if (state.showRawDataInput) {
      state.setState(() => state.showRawDataInput = false);
    }
  }

  static void _tryShowMaxDropOverlay(HomePageState state, AttendanceProvider provider) {
    final showOverlayPref = state.prefs?.getBool('showOverlay') ?? true;
    
    if (!provider.result.dataParsedSuccessfully || provider.errorMessage != null) return;
    if (!state.mounted || !state.isActive || !AppVisibilityService.instance.isRouteVisible) return;
    if (!showOverlayPref || !provider.isOverlayEligible) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.mounted || !state.isActive) return;
      showDialog(
        context: state.context,
        barrierDismissible: true,
        builder: (_) => MaxDropOverlay(result: provider.result),
      );
      provider.markOverlayAsShown();
    });
  }

  static void _handleInterstitialAds(HomePageState state, AttendanceProvider provider) {
    final premium = state.context.read<PremiumProvider>();
    final adProvider = state.context.read<AdProvider>();

    if (!premium.isPremium) {
      adProvider.incrementCalculationCounter();
      final result = provider.result;
      final bool isGoodMoment = result.requiredToAttend <= 0 && result.totalConducted > 0;

      if (adProvider.shouldShowInterstitial && isGoodMoment) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!state.mounted || !AppVisibilityService.instance.isRouteVisible) return;
          if (AdService.instance.isFullscreenShowing) return;
          AdService.instance.showInterstitialAd();
        });
      }
    }
  }

  static Color getResultStatusColor(AttendanceProvider provider) {
    return provider.result.currentPercentage >= provider.targetPercentage ? Colors.green : Colors.red;
  }
}