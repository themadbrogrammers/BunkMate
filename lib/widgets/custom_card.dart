import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bunkmate/providers/theme_provider.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final VoidCallback? onTap; // Added for tap support

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

    // Determine the background color only if no gradient is provided
    final Color? backgroundColor = gradient == null
        ? (isDarkMode ? Colors.white.withOpacity(0.04) : Colors.white)
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24.0), // Premium rounded corners
          // ✨ PREMIUM TOUCH: Inner rim lighting (Glassmorphism)
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.04),
            width: 1.5,
          ),

          // ✨ PREMIUM TOUCH: Deep, ambient drop shadow
          boxShadow: [
            if (gradient == null && !isDarkMode) ...[
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 24,
                spreadRadius: -4,
                offset: const Offset(0, 10),
              ),
            ] else if (isDarkMode && gradient == null) ...[
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 30,
                spreadRadius: -6,
                offset: const Offset(0, 12),
              ),
            ],
          ],
        ),
        clipBehavior:
            Clip.antiAlias, // Ensures internal elements respect the 24px curve
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: child,
        ),
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:bunkmate/providers/theme_provider.dart';

// class CustomCard extends StatelessWidget {
//   final Widget child;
//   final EdgeInsetsGeometry? padding;
//   final Gradient? gradient; // Added gradient parameter

//   const CustomCard({
//     super.key,
//     required this.child,
//     this.padding,
//     this.gradient, // Initialize gradient
//   });

//   @override
//   Widget build(BuildContext context) {
//     final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;

//     // Determine the background color only if no gradient is provided
//     final Color? backgroundColor = gradient == null
//         ? (isDarkMode ? Colors.white.withOpacity(0.05) : Colors.white)
//         : null; // Set color to null if gradient is used

//     return Container(
//       padding:
//           padding ??
//           const EdgeInsets.symmetric(
//             horizontal: 16.0,
//             vertical: 24.0,
//           ), // Keep default padding logic
//       decoration: BoxDecoration(
//         // Use gradient if provided, otherwise use calculated backgroundColor
//         gradient: gradient,
//         color: backgroundColor, // Will be null if gradient is not null
//         borderRadius: BorderRadius.circular(12.0),
//         border: Border.all(
//           color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
//         ),
//         boxShadow:
//             !isDarkMode &&
//                 gradient ==
//                     null // Apply shadow only in light mode AND if no gradient (gradients might look odd with shadows)
//             ? [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   blurRadius: 10,
//                   offset: const Offset(0, 5),
//                 ),
//               ]
//             : null,
//       ),
//       // Use ClipRRect to ensure the child respects the border radius, especially if the gradient has sharp edges
//       clipBehavior: Clip.antiAlias, // Ensures gradient respects border radius
//       child: child,
//     );
//   }
// }
