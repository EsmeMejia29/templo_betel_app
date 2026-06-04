import 'package:flutter/material.dart';

class BetelTheme {
  // Paleta de colores oficial (Verdes, oro/oliva y blanco)
  static const Color greenPrimary = Color(0xFF4A6B32);    // Verde institucional AD
  static const Color goldSecondary = Color(0xFF9E8E43);   // Dorado/Oliva del texto del calendario
  static const Color accentPurple = Color(0xFF8A3B7B);    // Morado de destaques del mes
  static const Color backgroundLight = Color(0xFFF9FBF7); // Fondo crema claro / hueso
  static const Color textDark = Color(0xFF2C3E24);        // Texto legible oscuro

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: greenPrimary,
      colorScheme: ColorScheme.light(
        primary: greenPrimary,
        secondary: goldSecondary,
        tertiary: accentPurple,
        surface: backgroundLight,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: greenPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      fontFamily: 'Serif', // O la fuente predeterminada del sistema
    );
  }
}