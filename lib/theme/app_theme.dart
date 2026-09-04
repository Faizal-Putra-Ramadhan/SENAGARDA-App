import 'package:flutter/material.dart';

/// Palet warna disamakan dengan portal web NAWASENA supaya identitas
/// visual konsisten antara website dan aplikasi kontrol rover.
class AppTheme {
  static const Color primaryGreen = Color(0xFF1F4A34);
  static const Color accentGold = Color(0xFFD9A441);
  static const Color darkBg = Color(0xFF101410);
  static const Color dangerRed = Color(0xFFC1502E);
  static const Color successGreen = Color(0xFF4C8C5B);
  static const Color panelBg = Color(0xFF161A16);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        brightness: Brightness.dark,
      ),
    );
  }
}
