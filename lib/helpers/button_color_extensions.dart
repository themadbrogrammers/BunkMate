import 'package:flutter/material.dart';

extension ColorBrightness on Color {
  Color lighten([double amount = 0.19]) {
    final hsl = HSLColor.fromColor(this);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}