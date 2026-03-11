import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/chat_provider.dart';
import '../../../shared/widgets/speech_action_bar.dart';

class BottomMic extends StatefulWidget {
  const BottomMic({super.key});

  @override
  State<BottomMic> createState() => _BottomMicState();
}

class _BottomMicState extends State<BottomMic> {
  @override
  Widget build(BuildContext context) {
    return SpeechActionBar(
      onSubmitted: (text) async {
        await context.read<ChatProvider>().sendMessage(text);
      },
    );
  }
}
