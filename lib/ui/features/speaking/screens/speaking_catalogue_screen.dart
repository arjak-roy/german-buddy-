import 'package:flutter/material.dart';
import 'package:wunderbarai/ui/features/speaking/screens/speaking_engine_example_screen.dart';
import '../models/speaking_exercise_item.dart';
import 'speaking_exercise_screen.dart';
import '../engine/speaking_exercises.dart';
import '../engine/speaking_engine_adapter.dart';

class SpeakingCatalogueScreen extends StatelessWidget {
  const SpeakingCatalogueScreen({super.key});

  void _openExercise(BuildContext context, SpeakingExerciseItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpeakingExerciseScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Speaking Exercises')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        // Use engine-provided canonical exercises when available.
        itemCount: defaultSpeakingExercises.length,
        itemBuilder: (context, index) {
          final engineEx = defaultSpeakingExercises[index];
          final item = speakingExerciseToItem(engineEx);
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.mic_none_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(item.description),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_circle_fill_rounded),
                    tooltip: 'Open engine example',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              // Lazy import to avoid breaking current flow
                              SpeakingEngineExampleScreen(item: item),
                        ),
                      );
                    },
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () => _openExercise(context, item),
            ),
          );
        },
      ),
    );
  }
}
