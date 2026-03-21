sealed class SpeakingExerciseState {
  const SpeakingExerciseState();
}

class SpeakingExerciseInitial extends SpeakingExerciseState {
  const SpeakingExerciseInitial();
}

class SpeakingExerciseRecording extends SpeakingExerciseState {
  const SpeakingExerciseRecording();
}

class SpeakingExerciseAnalyzing extends SpeakingExerciseState {
  const SpeakingExerciseAnalyzing();
}

class SpeakingExerciseSuccess extends SpeakingExerciseState {
  final double score;
  final String summary;
  final List<String> suggestions;
  final List<dynamic> wordAnalysis;

  const SpeakingExerciseSuccess({
    required this.score,
    required this.summary,
    required this.suggestions,
    required this.wordAnalysis,
  });
}

class SpeakingExerciseError extends SpeakingExerciseState {
  final String error;
  const SpeakingExerciseError(this.error);
}
