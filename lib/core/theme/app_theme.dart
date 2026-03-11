import 'package:flutter/material.dart';

/// Central place for the application's Material3 theme definitions.
class AppTheme {
  static const _seed = Color(0xFF2563EB);

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF7F9FC),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _seed, width: 1.4),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.w700),
      titleMedium: TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(height: 1.25),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: _seed.withOpacity(0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: _seed);
        }
        return const IconThemeData(color: Color(0xFF6B7280));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? const Color(0xFF1F2937)
              : const Color(0xFF6B7280),
        );
      }),
    ),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
