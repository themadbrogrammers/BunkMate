import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TargetStepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool increment;

  const TargetStepperButton({
    super.key,
    required this.icon,
    required this.increment,
    required this.onTap,
  });

  @override
  State<TargetStepperButton> createState() => _TargetStepperButtonState();
}

class _TargetStepperButtonState extends State<TargetStepperButton> {
  Timer? _timer;
  int _elapsed = 0;
  bool _isPressed = false; // ✨ Tracks the physical "squish" state

  void _startHold() {
    widget.onTap?.call();
    _elapsed = 0;
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      _elapsed += 40;
      int speed;
      if (_elapsed < 300) {
        speed = 220; // slow
      } else if (_elapsed < 800) {
        speed = 120; // fast
      } else {
        speed = 40; // TURBO
      }

      if (_elapsed % speed == 0) {
        widget.onTap?.call();
        HapticFeedback.selectionClick();
      }
    });
  }

  void _stopHold() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDisabled = widget.onTap == null;

    // ✨ Color psychology: Red for decrease, Green for increase
    final Color baseColor = widget.increment
        ? (isDark ? Colors.green.withOpacity(0.15) : Colors.green.withOpacity(0.1))
        : (isDark ? Colors.red.withOpacity(0.15) : Colors.red.withOpacity(0.1));

    final Color iconColor = widget.increment
        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
        : (isDark ? Colors.red.shade300 : Colors.red.shade700);

    return GestureDetector(
      // Map all gestures to handle both single taps and holds cleanly
      onTap: widget.onTap,
      onTapDown: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = true);
          HapticFeedback.lightImpact(); // Instant tactile response
        }
      },
      onTapUp: (_) {
        if (!isDisabled) setState(() => _isPressed = false);
      },
      onTapCancel: () {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _stopHold();
        }
      },
      onLongPressStart: (_) {
        if (!isDisabled) _startHold();
      },
      onLongPressEnd: (_) {
        if (!isDisabled) {
          setState(() => _isPressed = false);
          _stopHold();
        }
      },
      // ✨ Physical Squish Animation
      child: AnimatedScale(
        scale: _isPressed ? 0.85 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuart,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 44, // Slightly larger hit area for better UX
          height: 44,
          decoration: BoxDecoration(
            color: isDisabled
                ? theme.disabledColor.withOpacity(0.1)
                : (_isPressed ? baseColor.withOpacity(0.3) : baseColor),
            shape: BoxShape.circle, // Perfectly round looks best for +/-
            border: Border.all(
              color: isDisabled
                  ? Colors.transparent
                  : (_isPressed ? iconColor.withOpacity(0.5) : iconColor.withOpacity(0.15)),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 22,
            color: isDisabled ? theme.disabledColor : iconColor,
          ),
        ),
      ),
    );
  }
}

class SecondaryMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const SecondaryMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = valueColor ?? theme.textTheme.bodyLarge?.color;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color?.withOpacity(0.7) ?? theme.hintColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            height: 1.1,
            // ✨ PREMIUM TOUCH: Tiny text shadow to lift the number 
            shadows: [
              Shadow(
                color: (color ?? Colors.black).withOpacity(0.2),
                offset: const Offset(0, 1),
                blurRadius: 2,
              )
            ]
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.hintColor,
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';

// class TargetStepperButton extends StatefulWidget {
//   final IconData icon;
//   final VoidCallback? onTap;
//   final bool increment;

//   const TargetStepperButton({
//     super.key,
//     required this.icon,
//     required this.increment,
//     required this.onTap,
//   });

//   @override
//   State<TargetStepperButton> createState() => _TargetStepperButtonState();
// }

// class _TargetStepperButtonState extends State<TargetStepperButton> {
//   Timer? _timer;
//   int _elapsed = 0;

//   void _startHold() {
//     widget.onTap?.call();
//     _elapsed = 0;
//     _timer?.cancel();

//     _timer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
//       _elapsed += 40;
//       int speed;
//       if (_elapsed < 300) {
//         speed = 220; // slow
//       } else if (_elapsed < 800) {
//         speed = 120; // fast
//       } else {
//         speed = 40; // TURBO
//       }

//       if (_elapsed % speed == 0) {
//         widget.onTap?.call();
//         HapticFeedback.selectionClick();
//       }
//     });
//   }

//   void _stopHold() {
//     _timer?.cancel();
//   }

//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     return GestureDetector(
//       onTap: widget.onTap,
//       onLongPressStart: (_) => _startHold(),
//       onLongPressEnd: (_) => _stopHold(),
//       child: Material(
//         color: widget.onTap == null
//             ? theme.disabledColor.withOpacity(0.1)
//             : theme.colorScheme.primary.withOpacity(0.15),
//         shape: const CircleBorder(),
//         child: SizedBox(
//           width: 37,
//           height: 37,
//           child: Icon(widget.icon, size: 22),
//         ),
//       ),
//     );
//   }
// }

// class SecondaryMetricTile extends StatelessWidget {
//   final String label;
//   final String value;
//   final IconData icon;
//   final Color? valueColor;

//   const SecondaryMetricTile({
//     super.key,
//     required this.label,
//     required this.value,
//     required this.icon,
//     this.valueColor,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final color = valueColor ?? theme.textTheme.bodyLarge?.color;
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, size: 18, color: color?.withOpacity(0.7) ?? theme.hintColor),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: theme.textTheme.titleMedium?.copyWith(
//             fontWeight: FontWeight.bold,
//             color: color,
//             height: 1.1,
//           ),
//         ),
//         Text(
//           label,
//           style: theme.textTheme.bodySmall?.copyWith(
//             color: theme.hintColor,
//             height: 1.2,
//           ),
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//         ),
//       ],
//     );
//   }
// }