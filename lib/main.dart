import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/firebase_bootstrap.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'ui/features/auth/screens/login_screen.dart';
import 'ui/features/auth/screens/welcome_splash_screen.dart';
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
      title: 'Language Buddy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: theme.mode,
      home: const EntryPoint(),
    );
  }
}

/// Decides which screen to show based on authentication state.
class EntryPoint extends ConsumerStatefulWidget {
  const EntryPoint({super.key});

  @override
  ConsumerState<EntryPoint> createState() => _EntryPointState();
}

class _EntryPointState extends ConsumerState<EntryPoint> {
  bool _hasSeenInitialAuthSnapshot = false;
  bool _showPostLoginSplash = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<dynamic>>(authSessionProvider, (previous, next) {
      final previousUser = previous?.valueOrNull;
      final nextUser = next.valueOrNull;

      if (!_hasSeenInitialAuthSnapshot) {
        _hasSeenInitialAuthSnapshot = true;
        // Do not show splash on app start for already signed-in users.
        return;
      }

      final signedInNow = previousUser == null && nextUser != null;
      if (signedInNow && !_showPostLoginSplash) {
        setState(() {
          _showPostLoginSplash = true;
        });
      }
    });

    final authSession = ref.watch(authSessionProvider);

    if (_showPostLoginSplash) {
      return WelcomeSplashScreen(
        onFinished: () {
          if (!mounted) return;
          setState(() {
            _showPostLoginSplash = false;
          });
        },
      );
    }

    return authSession.when(
      data: (user) => user != null ? const HomeScreen() : const LoginScreen(),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => const LoginScreen(),
    );
  }
}
