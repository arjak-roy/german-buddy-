import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'ui/features/auth/screens/login_screen.dart';
import 'ui/features/home/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.ensureInitialized();
  runApp(const ProviderScope(child: MainApp()));
}

/// Root of the application.
class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeProviderNotifier);

    return MaterialApp(
      title: 'Kumpel AI',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      home: const EntryPoint(),
    );
  }
}

/// Decides which screen to show based on authentication state.
class EntryPoint extends ConsumerWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authSession = ref.watch(authSessionProvider);

    return authSession.when(
      data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
