import 'package:flutter/material.dart';

/// A simple [ChangeNotifier] that holds the application's theme mode and
/// allows toggling between light and dark variants.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;

  bool get isDark => _mode == ThemeMode.dark;

  /// Switches between light and dark themes.
  void toggle() {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
