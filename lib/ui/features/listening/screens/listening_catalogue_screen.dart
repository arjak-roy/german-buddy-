import 'package:flutter/material.dart';
import '../models/listening_exercise_item.dart';
import 'listening_exercise_screen.dart';

class ListeningCatalogueScreen extends StatelessWidget {
  const ListeningCatalogueScreen({super.key});

  void _openExercise(BuildContext context, ListeningExerciseItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ListeningExerciseScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listening Exercises')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: listeningExercises.length,
        itemBuilder: (context, index) {
          final item = listeningExercises[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(20),
              title: Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(item.description),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openExercise(context, item),
            ),
          );
        },
      ),
    );
  }
}
