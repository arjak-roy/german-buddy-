import '../models/speaking_exercise_item.dart';
import 'speaking_engine_models.dart';

/// Adapter utilities to convert engine `SpeakingExercise` to app `SpeakingExerciseItem`.

SpeakingExerciseItem speakingExerciseToItem(SpeakingExercise ex) {
  return SpeakingExerciseItem(
    title: ex.title,
    description: ex.description,
    scenario: ex.scenario ?? ex.description,
    prompt:
        ex.prompt ?? (ex.script.isNotEmpty ? ex.script.first : ex.description),
    usefulPhrases: ex.script,
  );
}
