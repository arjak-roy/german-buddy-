import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/theme_provider.dart';

class ThemeModeButton extends StatelessWidget {
  const ThemeModeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return IconButton(
      tooltip: themeProvider.isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => context.read<ThemeProvider>().toggle(),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => RotationTransition(
          turns: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          themeProvider.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey<bool>(themeProvider.isDark),
          size: 22,
        ),
      ),
    );
  }
}