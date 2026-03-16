import 'package:flutter/material.dart';

/// Central place for the application's Material3 theme definitions.
class AppTheme {
  static const _seed = Color(0xFF2563EB);
  static const _lightBackground = Color(0xFFF7F9FC);
  static const _darkBackground = Color(0xFF0B1220);
  static const _darkSurface = Color(0xFF121A2B);

  static TextTheme _textTheme(ColorScheme scheme) {
    return TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(color: scheme.onSurface),
      bodyMedium: TextStyle(height: 1.25, color: scheme.onSurface),
      bodySmall: TextStyle(color: scheme.onSurfaceVariant),
      labelLarge: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      labelMedium: TextStyle(color: scheme.onSurfaceVariant),
    );
  }

  static final light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _seed),
    useMaterial3: true,
    scaffoldBackgroundColor: _lightBackground,
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
    textTheme: _textTheme(ColorScheme.fromSeed(seedColor: _seed)),
    dividerColor: const Color(0xFFE5E7EB),
    iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
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
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: _darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF22304A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF60A5FA), width: 1.4),
      ),
    ),
    textTheme: _textTheme(
      ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
    ),
    dividerColor: const Color(0xFF22304A),
    iconTheme: const IconThemeData(color: Color(0xFFE5EEF9)),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF101827),
      indicatorColor: Colors.white.withOpacity(0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: Colors.white);
        }
        return const IconThemeData(color: Color(0xFF94A3B8));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF94A3B8),
        );
      }),
    ),
  );
}
