import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/speech_provider.dart';

class BuddyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BuddyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    final showDebug = context.watch<SpeechProvider>().showDebugPanel;

    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Buddy'),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                color: Colors.greenAccent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(showDebug ? Icons.bug_report : Icons.info_outline),
          tooltip: showDebug ? 'Hide STT debug panel' : 'Show STT debug panel',
          onPressed: () => context.read<SpeechProvider>().toggleDebugPanel(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
