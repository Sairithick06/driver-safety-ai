import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors
  static const Color primary = Color(0xFF00C2FF);
  static const Color secondary = Color(0xFF4F8CFF);
  static const Color accent = Color(0xFF00E5FF);

  // Background Colors
  static const Color background = Color(0xFF08111F);
  static const Color background2 = Color(0xFF10233D);
  static const Color surface = Color(0xFF1B2A41);
  static const Color card = Color(0xFF223047);

  // Text Colors
  static const Color white = Colors.white;
  static const Color grey = Color(0xFFB7BDC7);
  static const Color lightGrey = Color(0xFF8D97A5);

  // Status Colors
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFFFA726);
  static const Color danger = Color(0xFFFF5252);

  // AI Glow
  static const Color glow = Color(0x3300C2FF);

  // Gradient
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      background,
      background2,
      Color(0xFF1C355E),
    ],
  );

  // Button Gradient
  static const LinearGradient buttonGradient = LinearGradient(
    colors: [
      primary,
      secondary,
    ],
  );
}