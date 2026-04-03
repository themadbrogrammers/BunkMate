import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void showTopToast(String message, {Color? backgroundColor, Color? textColor}) {
  Fluttertoast.cancel();
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_SHORT,
    gravity: ToastGravity.TOP, // Position at the top
    timeInSecForIosWeb: 2, // Duration for iOS/Web
    backgroundColor:
        backgroundColor ?? Colors.black.withOpacity(0.7), // Default background
    textColor: textColor ?? Colors.white, // Default text color
    fontSize: 14.0,
  );
}

void showErrorToast(String message) {
  showTopToast('❌ $message', backgroundColor: Colors.red.shade700);
}

// import 'dart:async'; // Import Timer
// import 'package:flutter/material.dart';
// import 'package:fluttertoast/fluttertoast.dart';

// Timer? _debounceTimer;
// const _debounceDuration = Duration(milliseconds: 200);

// void showTopToast(String message, {Color? backgroundColor, Color? textColor}) {
//   _debounceTimer?.cancel();

//   _debounceTimer = Timer(_debounceDuration, () {
//     Fluttertoast.cancel();
//     try {
//       Fluttertoast.showToast(
//         msg: message,
//         toastLength: Toast.LENGTH_SHORT,
//         gravity: ToastGravity.TOP,
//         timeInSecForIosWeb: 2,
//         backgroundColor: backgroundColor ?? Colors.black.withOpacity(0.7),
//         textColor: textColor ?? Colors.white,
//         fontSize: 14.0,
//       );
//     } catch (e) {
//       print("Error showing toast: $e");
//     }
//   });
// }

// // showErrorToast remains the same, it just calls the debounced showTopToast
// void showErrorToast(String message) {
//   showTopToast('❌ $message', backgroundColor: Colors.red.shade700);
// }

// // Optional: Add a cancel function if needed elsewhere
// void cancelDebouncedToast() {
//   _debounceTimer?.cancel();
//   Fluttertoast.cancel(); // Also cancel any visible native toast
// }
