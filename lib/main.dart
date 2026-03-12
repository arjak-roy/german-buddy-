import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/ai_provider.dart';
import 'providers/pronunciation_analysis_provider.dart';
import 'providers/pronunciation_recording_provider.dart';
import 'providers/speech_provider.dart';
import 'ui/features/auth/screens/login_screen.dart';
import 'ui/features/home/screens/home_screen.dart';

void main() {
  runApp(const MainApp());
}

/// Root of the application. Uses [MultiProvider] to register global
/// state objects. The theme provider is loaded first so that other
/// widgets (including those built during navigation) can read the
/// correct theme mode.
class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<ChatProvider>(create: (_) => ChatProvider()),
        ChangeNotifierProvider<AiProvider>(create: (_) => AiProvider()),
        ChangeNotifierProvider<PronunciationAnalysisProvider>(
          create: (_) => PronunciationAnalysisProvider(),
        ),
        ChangeNotifierProvider<PronunciationRecordingProvider>(
          create: (_) => PronunciationRecordingProvider(),
        ),
        ChangeNotifierProvider<SpeechProvider>(create: (_) => SpeechProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, __) {
          return MaterialApp(
            title: 'WunderbarAI',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.mode,
            home: const EntryPoint(),
          );
        },
      ),
    );
  }
}

/// Decides which screen to show based on authentication state.
class EntryPoint extends StatelessWidget {
  const EntryPoint({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.loggedIn) {
      return const HomeScreen();
    }
    return const LoginScreen();
  }
}
