import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../shared/widgets/speech_action_bar.dart';

class BottomMic extends ConsumerWidget {
  const BottomMic({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(chatProviderNotifier);

    return SpeechActionBar(
      onSubmitted: (text) async {
        await ref.read(chatProviderNotifier).sendMessage(text);
      },
      onCustomVoiceStart: () =>
          ref.read(chatProviderNotifier).startBuddyVoiceTurn(),
      onCustomVoiceStop: () =>
          ref.read(chatProviderNotifier).stopBuddyVoiceTurn(),
      isCustomVoiceActive: chat.isBuddyVoiceActive,
      customVoiceLevel: chat.isBuddyVoiceActive ? 1.0 : 0.0,
      customTranscript: chat.buddyVoiceTranscript,
    );
  }
}
