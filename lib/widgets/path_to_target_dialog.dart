import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/services.dart';
import 'package:bunkmate/helpers/toast_helper.dart';

class PathToTargetDialog extends StatefulWidget {
  final int requiredClasses;
  final double currentAttended;
  final double currentConducted;
  final double targetPercentage;
  final int classesPerWeek;

  const PathToTargetDialog({
    super.key,
    required this.requiredClasses,
    required this.currentAttended,
    required this.currentConducted,
    required this.targetPercentage,
    required this.classesPerWeek,
  });

  @override
  State<PathToTargetDialog> createState() => _PathToTargetDialogState();
}

class _PathToTargetDialogState extends State<PathToTargetDialog>
    with SingleTickerProviderStateMixin {
  // Design System Constants
  static const double _radius = 28.0;
  static const double _perspective = 0.0012;

  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _tiltAngleX = 0.0;
  double _tiltAngleY = 0.0;
  bool _motionEnabled = false;
  Timer? _motionTimeout;

  @override
  void dispose() {
    _stopListening();
    _motionTimeout?.cancel();
    super.dispose();
  }

  void _enableMotion() {
    if (_motionEnabled || MediaQuery.of(context).disableAnimations) return;

    HapticFeedback.lightImpact();
    setState(() => _motionEnabled = true);
    _startListening();

    _motionTimeout?.cancel();
    _motionTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      _stopListening();
      setState(() {
        _motionEnabled = false;
        _tiltAngleX = 0;
        _tiltAngleY = 0;
      });
    });
  }

  void _startListening() {
    _accelerometerSubscription =
        accelerometerEventStream(
          samplingPeriod: SensorInterval.uiInterval,
        ).listen((event) {
          if (!mounted) return;
          // Normalizing sensor data for a subtle, premium tilt effect
          final targetX = (-(event.y / 9.8) * 7.0 * 0.9) * (pi / 180);
          final targetY = ((event.x / 9.8) * 7.0 * 0.9) * (pi / 180);

          setState(() {
            _tiltAngleX = lerpDouble(_tiltAngleX, targetX, 0.15)!;
            _tiltAngleY = lerpDouble(_tiltAngleY, targetY, 0.15)!;
          });
        });
  }

  void _stopListening() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // --- Logic Calculations ---
    final int balancedBuffer = 10;
    final int balancedAttend = widget.requiredClasses + balancedBuffer;

    int allowedSkips = 0;
    if (widget.targetPercentage > 0 && widget.targetPercentage < 1) {
      final double newAttended = widget.currentAttended + balancedAttend;
      final double newConducted = widget.currentConducted + balancedAttend;
      allowedSkips =
          ((newAttended - (widget.targetPercentage * newConducted)) /
                  widget.targetPercentage)
              .floor();
      if (allowedSkips < 0) allowedSkips = 0;
    }

    final double weeksNeeded = widget.classesPerWeek > 0
        ? widget.requiredClasses / widget.classesPerWeek
        : 0;

    return Center(
      child: MetaCard(
        tiltX: _tiltAngleX,
        tiltY: _tiltAngleY,
        onTap: _enableMotion,
        child: Container(
          width: min(MediaQuery.of(context).size.width * 0.9, 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(isDark ? 0.9 : 1.0),
            borderRadius: BorderRadius.circular(_radius),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- Header Section ---
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.route_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Path to Recovery',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Strategy to hit your ${(widget.targetPercentage * 100).toInt()}% target',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 28),

                // --- Option 1: Express ---
                _PathOptionTile(
                  title: 'Express Lane',
                  tag: 'FASTEST',
                  icon: Icons.rocket_launch_rounded,
                  color: Colors.red,
                  description: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      children: [
                        const TextSpan(text: 'Attend the next '),
                        TextSpan(
                          text: '${widget.requiredClasses} classes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const TextSpan(text: ' consecutively.'),
                        if (weeksNeeded > 0)
                          TextSpan(
                            text:
                                '\n≈ ${weeksNeeded.toStringAsFixed(1)} weeks of perfect attendance.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  action: _CopyButton(
                    onTap: () => _copyToClipboard(widget.requiredClasses),
                  ),
                ),

                const SizedBox(height: 16),

                // --- Option 2: Balanced ---
                _PathOptionTile(
                  title: 'Safe Buffer',
                  tag: 'RECOMMENDED',
                  icon: Icons.shield_outlined,
                  color: Colors.green,
                  description: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                      children: [
                        const TextSpan(text: 'Attend '),
                        TextSpan(
                          text: '$balancedAttend classes',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(text: ' to unlock a safety net of '),
                        TextSpan(
                          text: '$allowedSkips skips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                        const TextSpan(text: ' for later.'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // --- Footer Action ---
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Got it, Chief!',
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  void _copyToClipboard(int count) async {
    final String text =
        "Attendance Recovery Plan: I need to attend the next $count classes perfectly to hit my target. Let's go!";
    await Clipboard.setData(ClipboardData(text: text));
    showTopToast('📋 Recovery plan copied to clipboard!');
    HapticFeedback.mediumImpact();
  }
}

/// A wrapper that provides the 3D tilt effect and haptics
class MetaCard extends StatelessWidget {
  final double tiltX;
  final double tiltY;
  final Widget child;
  final VoidCallback onTap;

  const MetaCard({
    super.key,
    required this.tiltX,
    required this.tiltY,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutBack,
        builder: (context, value, _) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateX(tiltX)
              ..rotateY(tiltY)
              ..scale(value),
            child: child,
          );
        },
      ),
    );
  }
}

class _PathOptionTile extends StatelessWidget {
  final String title;
  final String tag;
  final IconData icon;
  final Color color;
  final Widget description;
  final Widget? action;

  const _PathOptionTile({
    required this.title,
    required this.tag,
    required this.icon,
    required this.color,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(16), child: description),
          if (action != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: action!,
            ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CopyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.copy_all_rounded,
              size: 14,
              color: Theme.of(context).hintColor,
            ),
            const SizedBox(width: 6),
            Text(
              'Copy Reminder',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
