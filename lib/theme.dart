import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF1B263B);
  static const navyDeep = Color(0xFF1B2638);
  static const ink = Color(0xFF16213A);
  static const muted = Color(0xFF64748B);
  static const bg = Color(0xFFF3F5FA);
  static const blue = Color(0xFF2F80FF);
  static const blueSoft = Color(0xFFEAF2FF);
  static const border = Color(0xFFE2E8F0);
  static const cyan = Color(0xFFA5F3FC);
  static const mint = Color(0xFFC8F7D4);
  static const sand = Color(0xFFEDE4BE);
  static const rose = Color(0xFFF7B8B8);
  static const red = Color(0xFFFF3B3B);
  static const green = Color(0xFF22A559);
  static const greenDark = Color(0xFF15803D);
  static const yellow = Color(0xFFFFC400);
  static const grayChip = Color(0xFFE8ECF3);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  );
}

TextStyle t(double size,
    {FontWeight w = FontWeight.w500, Color c = AppColors.ink, double? h}) {
  return TextStyle(fontSize: size, fontWeight: w, color: c, height: h);
}
