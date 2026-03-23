import 'speaking_engine_models.dart';

/// A reusable and testable speaking engine.
///
/// Usage:
///
/// final engine = SpeakingEngine(
///   script: ["Hallo, ich heiße ..."],
///   translations: {'hallo': 'hello', 'ich': 'I'},
///   ignoreWords: {'your name', '...'},
/// );
///
/// final analysis = engine.analyzeSentence(0, "Hallo ich heiße Maria");
///
class SpeakingEngine {
  final List<String> script;
  final Map<String, String> translations;
  final Set<String> ignoreWords;

  int _currentSentenceIndex = 0;

  SpeakingEngine({
    required List<String> script,
    Map<String, String>? translations,
    Set<String>? ignoreWords,
  }) : script = List.unmodifiable(script),
       translations = Map.unmodifiable(translations ?? {}),
       ignoreWords = Set.unmodifiable(ignoreWords ?? {}) {
    if (script.isEmpty) {
      throw ArgumentError('script must contain at least one sentence');
    }
  }

  int get currentSentenceIndex => _currentSentenceIndex;

  String get currentSentence => script[_currentSentenceIndex];

  bool get hasNextSentence => _currentSentenceIndex < script.length - 1;

  bool get hasPreviousSentence => _currentSentenceIndex > 0;

  void nextSentence() {
    if (hasNextSentence) {
      _currentSentenceIndex += 1;
    }
  }

  void previousSentence() {
    if (hasPreviousSentence) {
      _currentSentenceIndex -= 1;
    }
  }

  /// Public normalization — SpeechProvider delegates here for parity.
  static String normalizeToken(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return '';

    final placeholder = RegExp(r'^\[(.+)\]\$').firstMatch(trimmed);
    // Support bracketed placeholders like [Your Name] (match without trailing $)
    // fallback to a correct bracket-only match if previous fails.
    final bracketOnly = RegExp(r'^\[(.+)\]$').firstMatch(trimmed);
    final placeholderMatch = placeholder ?? bracketOnly;
    if (placeholderMatch != null) {
      return placeholderMatch.group(1)!.trim().toLowerCase();
    }

    final normalized = trimmed
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9äöüßÄÖÜ'\s]"), ' ')
        .trim();

    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    return tokens.join(' ');
  }

  List<SpeakingWordToken> tokenize(String input, {String? phoneticInput}) {
    final rawTokens = RegExp(
      r'\[[^\]]+\]|[^\s]+',
    ).allMatches(input).map((m) => m.group(0)!).toList();

    final rawPhoneticTokens = phoneticInput != null
        ? phoneticInput.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList()
        : <String>[];

    final normalizedIgnore = ignoreWords
        .map(normalizeToken)
        .where((t) => t.isNotEmpty)
        .toSet();
    final ignoredPhraseParts = ignoreWords
        .map(normalizeToken)
        .where((e) => e.contains(' '))
        .toList();

    final tokens = <SpeakingWordToken>[];

    for (var i = 0; i < rawTokens.length; i++) {
      final raw = rawTokens[i];
      final normalized = normalizeToken(raw);
      if (normalized.isEmpty) continue;

      // Try to associate a phonetic string if available.
      // Note: This simple zip assumes 1-to-1 word alignment.
      final phonetic = (i < rawPhoneticTokens.length) ? rawPhoneticTokens[i] : null;

      tokens.add(
        SpeakingWordToken(
          raw: raw,
          normalized: normalized,
          ignored: normalizedIgnore.contains(normalized),
          phonetic: phonetic,
        ),
      );
    }

    if (ignoredPhraseParts.isNotEmpty) {
      for (final phrase in ignoredPhraseParts) {
        final phraseWords = phrase.split(' ');
        for (var i = 0; i + phraseWords.length <= tokens.length; i++) {
          var matchesPhrase = true;
          for (var k = 0; k < phraseWords.length; k++) {
            if (tokens[i + k].normalized != phraseWords[k]) {
              matchesPhrase = false;
              break;
            }
          }
          if (matchesPhrase) {
            for (var j = 0; j < phraseWords.length; j++) {
              tokens[i + j] = SpeakingWordToken(
                raw: tokens[i + j].raw,
                normalized: tokens[i + j].normalized,
                ignored: true,
                phonetic: tokens[i + j].phonetic,
              );
            }
          }
        }
      }
    }

    return List.unmodifiable(tokens);
  }

  List<SpeakingWordToken> get sentenceTokens => tokenize(currentSentence);

  /// Static tokenizer for use outside an engine instance (e.g. from providers).
  static List<SpeakingWordToken> tokenizeStatic(
    String input,
    Set<String> ignoreWords, {
    String? phoneticInput,
  }) {
    final rawTokens = RegExp(
      r'\[[^\]]+\]|[^\s]+',
    ).allMatches(input).map((m) => m.group(0)!).toList();

    final rawPhoneticTokens = phoneticInput != null
        ? phoneticInput.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList()
        : <String>[];

    final normalizedIgnore = ignoreWords
        .map(normalizeToken)
        .where((t) => t.isNotEmpty)
        .toSet();
    final ignoredPhraseParts = ignoreWords
        .map(normalizeToken)
        .where((e) => e.contains(' '))
        .toList();

    final tokens = <SpeakingWordToken>[];

    for (var i = 0; i < rawTokens.length; i++) {
      final raw = rawTokens[i];
      final normalized = normalizeToken(raw);
      if (normalized.isEmpty) continue;

      final phonetic = (i < rawPhoneticTokens.length) ? rawPhoneticTokens[i] : null;

      tokens.add(
        SpeakingWordToken(
          raw: raw,
          normalized: normalized,
          ignored: normalizedIgnore.contains(normalized),
          phonetic: phonetic,
        ),
      );
    }

    if (ignoredPhraseParts.isNotEmpty) {
      for (final phrase in ignoredPhraseParts) {
        final phraseWords = phrase.split(' ');
        for (var i = 0; i + phraseWords.length <= tokens.length; i++) {
          var matchesPhrase = true;
          for (var k = 0; k < phraseWords.length; k++) {
            if (tokens[i + k].normalized != phraseWords[k]) {
              matchesPhrase = false;
              break;
            }
          }
          if (matchesPhrase) {
            for (var j = 0; j < phraseWords.length; j++) {
              tokens[i + j] = SpeakingWordToken(
                raw: tokens[i + j].raw,
                normalized: tokens[i + j].normalized,
                ignored: true,
                phonetic: tokens[i + j].phonetic,
              );
            }
          }
        }
      }
    }

    return List.unmodifiable(tokens);
  }

  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final rows = a.length + 1;
    final cols = b.length + 1;
    final d = List<List<int>>.generate(rows, (_) => List<int>.filled(cols, 0));
    for (var i = 0; i < rows; i++) { d[i][0] = i; }
    for (var j = 0; j < cols; j++) { d[0][j] = j; }
    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost]
            .reduce((min, v) => v < min ? v : min);
      }
    }
    return d[a.length][b.length];
  }

  SpeakingSentenceAnalysis analyzeSentence(
    int sentenceIndex,
    String spokenSentence, {
    Map<String, double>? spokenWordConfidences,
  }) {
    if (sentenceIndex < 0 || sentenceIndex >= script.length) {
      throw RangeError.index(sentenceIndex, script, 'sentenceIndex');
    }

    final targetTokens = tokenize(
      script[sentenceIndex],
    ).where((t) => !t.ignored).toList();
    final spokenTokens = tokenize(
      spokenSentence,
    ).where((t) => !t.ignored).toList();

    final spokenNormalizedSet = spokenTokens.map((e) => e.normalized).toSet();

    final wordAnalyses = <SpeakingWordAnalysis>[];

    for (final token in targetTokens) {
      final matched = spokenNormalizedSet.contains(token.normalized);
      final rawConfidence = spokenWordConfidences?[token.normalized];
      final confidence = matched ? (rawConfidence ?? 1.0) : 0.0;
      wordAnalyses.add(
        SpeakingWordAnalysis(
          target: token.normalized,
          matched: matched,
          confidence: confidence.clamp(0.0, 1.0),
          translation: translations[token.normalized] ?? '',
        ),
      );
    }

    final matchRate = targetTokens.isEmpty
        ? 1.0
        : wordAnalyses.map((w) => w.score).fold(0.0, (a, b) => a + b) /
              targetTokens.length;

    return SpeakingSentenceAnalysis(
      sentenceIndex: sentenceIndex,
      sentence: script[sentenceIndex],
      wordAnalyses: List.unmodifiable(wordAnalyses),
      matchRate: matchRate.clamp(0.0, 1.0),
    );
  }

  SpeakingSessionAnalysis analyzeFullSession(
    Map<int, String> spokenSentences, {
    Map<int, Map<String, double>>? sentenceWordConfidences,
  }) {
    final sentenceAnalyses = <SpeakingSentenceAnalysis>[];

    for (var i = 0; i < script.length; i++) {
      final spoken = spokenSentences[i] ?? '';
      final confidences = sentenceWordConfidences?[i];
      sentenceAnalyses.add(
        analyzeSentence(i, spoken, spokenWordConfidences: confidences),
      );
    }

    final averageMatchRate = sentenceAnalyses.isEmpty
        ? 1.0
        : sentenceAnalyses.map((a) => a.matchRate).fold(0.0, (a, b) => a + b) /
              sentenceAnalyses.length;

    return SpeakingSessionAnalysis(
      sentenceAnalyses: List.unmodifiable(sentenceAnalyses),
      averageMatchRate: averageMatchRate.clamp(0.0, 1.0),
    );
  }

  List<SpeakingExercise> createExercisesFromScript({
    required String idPrefix,
    String Function(int index)? titleBuilder,
    String Function(int index)? descriptionBuilder,
  }) {
    final builder = titleBuilder ?? (i) => 'Sentence ${i + 1} Practice';
    final description =
        descriptionBuilder ?? (i) => 'Practice sentence number ${i + 1}.';

    return List.unmodifiable(
      script.asMap().entries.map((entry) {
        final idx = entry.key;
        final sentence = entry.value;

        return SpeakingExercise(
          id: '$idPrefix-$idx',
          title: builder(idx),
          description: description(idx),
          script: [sentence],
          translations: translations,
          ignoreWords: ignoreWords,
        );
      }).toList(),
    );
  }
}
