/// Models for the speaking engine module.
///
/// This module is designed to receive a script, translations, ignore words,
/// and produce analysis reports for user speech validation.
library speaking_engine_models;

class SpeakingExercise {
  final String id;
  final String title;
  final String description;
  final List<String> script;
  final Map<String, String> translations;
  final Set<String> ignoreWords;
  final String? scenario;
  final String? prompt;
  final List<String>? usefulPhrases;
  final String? spokenName;

  const SpeakingExercise({
    required this.id,
    required this.title,
    required this.description,
    required this.script,
    required this.translations,
    required this.ignoreWords,
    this.scenario,
    this.prompt,
    this.usefulPhrases,
    this.spokenName,
  });
}

class SpeakingWordToken {
  final String raw;
  final String normalized;
  final bool ignored;

  const SpeakingWordToken({
    required this.raw,
    required this.normalized,
    required this.ignored,
  });
}

class SpeakingWordAnalysis {
  final String target;
  final bool matched;
  final double confidence;
  final String translation;

  const SpeakingWordAnalysis({
    required this.target,
    required this.matched,
    required this.confidence,
    required this.translation,
  });

  double get score => matched ? confidence : 0.0;
}

class SpeakingSentenceAnalysis {
  final int sentenceIndex;
  final String sentence;
  final List<SpeakingWordAnalysis> wordAnalyses;
  final double matchRate;

  const SpeakingSentenceAnalysis({
    required this.sentenceIndex,
    required this.sentence,
    required this.wordAnalyses,
    required this.matchRate,
  });
}

class SpeakingSessionAnalysis {
  final List<SpeakingSentenceAnalysis> sentenceAnalyses;
  final double averageMatchRate;

  const SpeakingSessionAnalysis({
    required this.sentenceAnalyses,
    required this.averageMatchRate,
  });
}
