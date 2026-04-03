// lib/mixins/scroll_to_top_mixin.dart
import 'package:flutter/material.dart';

mixin ScrollToTopMixin<T extends StatefulWidget> on State<T> {
  // The mixin provides the ScrollController
  final ScrollController scrollController = ScrollController();

  // The mixin provides the scrollToTop method
  void scrollToTop() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // The mixin handles disposing the controller
  @override
  void dispose() {
    scrollController.dispose();
    super.dispose(); // Don't forget to call super.dispose()!
  }
}