import 'package:flutter/material.dart';
import 'package:bunkmate/services/ad_service.dart';
import 'package:flutter/services.dart';

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

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isLoading = false;

      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          Colors.blue.shade900.withOpacity(0.35),
                          Colors.blue.shade800.withOpacity(0.15),
                        ]
                      : [
                          Colors.blue.shade100.withOpacity(0.6),
                          Colors.blue.shade50.withOpacity(0.3),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- Icon ---
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary.withOpacity(0.15),
                    ),
                    child: Icon(
                      Icons.lock_open_rounded,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Title ---
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // --- Content ---
                  Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.lock_open_rounded, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unlocks instantly • Enjoy the whole day!',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Actions ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  _forceKillKeyboard();
                                  Navigator.of(ctx).pop();
                                },
                          child: const Text('Not Now'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  // 🔒 Lock button immediately
                                  setState(() => isLoading = true);

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
                                        setState(() => isLoading = false);
                                      }
                                    },
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text('Preparing…'),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.movie_filter_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text('Unlock'),
                                  ],
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
    },
  );
}
