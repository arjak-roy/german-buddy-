import 'package:flutter/material.dart';

import '../models/speaking_exercise_item.dart';
import 'speaking_exercise_screen.dart';

class SpeakingEngineExampleScreen extends StatelessWidget {
  final SpeakingExerciseItem item;

  const SpeakingEngineExampleScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Engine Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(item.description),
            const SizedBox(height: 16),
            Text('Prompt', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(item.prompt),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SpeakingExerciseScreen(item: item),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Open Practice'),
            ),
          ],
        ),
      ),
    );
  }
}
