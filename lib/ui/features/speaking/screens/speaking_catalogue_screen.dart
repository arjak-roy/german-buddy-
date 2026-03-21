import 'package:flutter/material.dart';
import 'speaking_exercise_screen.dart';
import '../engine/speaking_exercises.dart';
import '../engine/speaking_engine_models.dart';

class SpeakingCatalogueScreen extends StatelessWidget {
  const SpeakingCatalogueScreen({super.key});

  void _openExercise(BuildContext context, SpeakingExercise item) {
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
        itemCount: defaultSpeakingExercises.length,
        itemBuilder: (context, index) {
          final item = defaultSpeakingExercises[index];
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
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openExercise(context, item),
            ),
          );
        },
      ),
    );
  }
}
