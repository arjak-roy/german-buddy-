import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/chat_provider.dart';
import '../../../shared/widgets/speech_action_bar.dart';

class BottomMic extends StatelessWidget {
  const BottomMic({super.key});

  @override
  Widget build(BuildContext context) {
    return SpeechActionBar(
      onSubmitted: (text) async {
        await context.read<ChatProvider>().sendMessage(text);
      },
    );
  }
}
