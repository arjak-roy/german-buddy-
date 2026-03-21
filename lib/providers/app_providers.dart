import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_provider.dart';
import 'chat_provider.dart';
import 'introduce_yourself_practice_provider.dart';
import 'pronunciation_analysis_provider.dart';
import 'pronunciation_recording_provider.dart';
import 'speech_provider.dart';
import 'theme_provider.dart';
import 'user_provider.dart';
import 'voice_provider.dart';

export 'auth_provider.dart';
export 'profile_provider.dart';

final themeProviderNotifier = ChangeNotifierProvider<ThemeProvider>(
  (ref) => ThemeProvider(),
);

final userProviderNotifier = ChangeNotifierProvider<UserProvider>(
  (ref) => UserProvider(),
);

final chatProviderNotifier = ChangeNotifierProvider<ChatProvider>(
  (ref) => ChatProvider(),
);

final aiProviderNotifier = ChangeNotifierProvider<AiProvider>(
  (ref) => AiProvider(),
);

final pronunciationAnalysisProviderNotifier =
    ChangeNotifierProvider<PronunciationAnalysisProvider>(
      (ref) => PronunciationAnalysisProvider(),
    );

final pronunciationRecordingProviderNotifier =
    ChangeNotifierProvider<PronunciationRecordingProvider>(
      (ref) => PronunciationRecordingProvider(),
    );

final speechProviderNotifier = ChangeNotifierProvider<SpeechProvider>(
  (ref) => SpeechProvider(),
);

final voiceProviderNotifier = ChangeNotifierProvider<VoiceProvider>(
  (ref) => VoiceProvider(),
);

final introduceYourselfPracticeProviderNotifier =
    ChangeNotifierProvider<IntroduceYourselfPracticeProvider>(
      (ref) => IntroduceYourselfPracticeProvider(script: []),
    );
