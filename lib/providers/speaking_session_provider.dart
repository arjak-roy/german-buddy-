import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../ui/features/speaking/models/speaking_exercise_state.dart';
import '../core/constants/prompts.dart';
import '../data/services/gemini_service.dart';
import '../ui/features/speaking/engine/speaking_engine.dart';
import '../ui/features/speaking/engine/speaking_engine_models.dart';

part 'speaking_session_provider.g.dart';

class SpeakingSessionState {
  final List<String> script;
  final int currentSentenceIndex;
  final bool isCompleted;
  final double ttsSpeed;
  final bool isTtsSpeaking;
  final int ttsWordIndex;
  final Set<int> attemptedSentenceIndices;
  final Map<int, Map<String, dynamic>> sentenceWordConfidence;
  final String latestWordConfidenceJson;
  final SpeakingExerciseState uiState;

  // ── Sequence-aware matching state ──
  /// Index of the next expected word in the target token list.
  final int currentWordPointer;

  /// Indices (into the target token list) that have been matched *in order*.
  final Set<int> matchedWordIndices;

  /// Per-word confidence for the current sentence (token → confidence).
  final Map<String, double> wordConfidences;

  /// Live match-rate for the current sentence (0.0–1.0).
  final double matchRate;

  /// Live average word-confidence for matched words (0.0–1.0).
  final double averageWordConfidence;

  /// Per-word phonetic/articulation score (0.0–1.0).
  final Map<String, double> phoneticScores;

  SpeakingSessionState({
    required this.script,
    this.currentSentenceIndex = 0,
    this.isCompleted = false,
    this.ttsSpeed = 0.45,
    this.isTtsSpeaking = false,
    this.ttsWordIndex = -1,
    this.attemptedSentenceIndices = const <int>{},
    this.sentenceWordConfidence = const {},
    this.latestWordConfidenceJson = '{}',
    this.uiState = const SpeakingExerciseInitial(),
    this.currentWordPointer = 0,
    this.matchedWordIndices = const <int>{},
    this.wordConfidences = const <String, double>{},
    this.matchRate = 0.0,
    this.averageWordConfidence = 0.0,
    this.phoneticScores = const <String, double>{},
  });

  bool get hasAttemptedCurrentSentence => attemptedSentenceIndices.contains(currentSentenceIndex);
  bool get canOpenAnalysis => attemptedSentenceIndices.contains(script.length - 1);
  String get currentSentence => script[currentSentenceIndex];

  int get speakingSentenceCount => sentenceWordConfidence.length;

  Map<String, double> get speakingWordConfidence {
    final values = <String, List<double>>{};
    for (final sentence in sentenceWordConfidence.values) {
      final words = (sentence['words'] as List<dynamic>).cast<Map<String, dynamic>>();
      for (final entry in words) {
        final word = (entry['word'] as String).trim().toLowerCase();
        final confidence = (entry['confidence'] as num).toDouble();
        values.putIfAbsent(word, () => []).add(confidence);
      }
    }

    final avg = <String, double>{};
    for (final kv in values.entries) {
      final list = kv.value;
      final mean = list.isEmpty ? 0.0 : list.reduce((a, b) => a + b) / list.length;
      avg[kv.key] = mean;
    }
    return avg;
  }

  double get speakingAverageConfidence {
    final wordConfidence = speakingWordConfidence;
    if (wordConfidence.isEmpty) return 0.0;
    return wordConfidence.values.reduce((a, b) => a + b) / wordConfidence.length;
  }

  SpeakingSessionState copyWith({
    List<String>? script,
    int? currentSentenceIndex,
    bool? isCompleted,
    double? ttsSpeed,
    bool? isTtsSpeaking,
    int? ttsWordIndex,
    Set<int>? attemptedSentenceIndices,
    Map<int, Map<String, dynamic>>? sentenceWordConfidence,
    String? latestWordConfidenceJson,
    SpeakingExerciseState? uiState,
    int? currentWordPointer,
    Set<int>? matchedWordIndices,
    Map<String, double>? wordConfidences,
    double? matchRate,
    double? averageWordConfidence,
    Map<String, double>? phoneticScores,
  }) {
    return SpeakingSessionState(
      script: script ?? this.script,
      currentSentenceIndex: currentSentenceIndex ?? this.currentSentenceIndex,
      isCompleted: isCompleted ?? this.isCompleted,
      ttsSpeed: ttsSpeed ?? this.ttsSpeed,
      isTtsSpeaking: isTtsSpeaking ?? this.isTtsSpeaking,
      ttsWordIndex: ttsWordIndex ?? this.ttsWordIndex,
      attemptedSentenceIndices: attemptedSentenceIndices ?? this.attemptedSentenceIndices,
      sentenceWordConfidence: sentenceWordConfidence ?? this.sentenceWordConfidence,
      latestWordConfidenceJson: latestWordConfidenceJson ?? this.latestWordConfidenceJson,
      uiState: uiState ?? this.uiState,
      currentWordPointer: currentWordPointer ?? this.currentWordPointer,
      matchedWordIndices: matchedWordIndices ?? this.matchedWordIndices,
      wordConfidences: wordConfidences ?? this.wordConfidences,
      matchRate: matchRate ?? this.matchRate,
      averageWordConfidence: averageWordConfidence ?? this.averageWordConfidence,
      phoneticScores: phoneticScores ?? this.phoneticScores,
    );
  }
}

@riverpod
class SpeakingSessionNotifier extends _$SpeakingSessionNotifier {
  late final GeminiService _geminiService;

  @override
  SpeakingSessionState build(SpeakingExercise item) {
    _geminiService = GeminiService();
    return SpeakingSessionState(script: item.script);
  }

  void setTtsSpeed(double value) {
    state = state.copyWith(ttsSpeed: value);
  }

  void setTtsStarted() {
    state = state.copyWith(isTtsSpeaking: true, ttsWordIndex: -1);
  }

  void setTtsStopped() {
    state = state.copyWith(isTtsSpeaking: false, ttsWordIndex: -1);
  }

  void setTtsWordIndex(int index) {
    if (state.ttsWordIndex == index) return;
    state = state.copyWith(ttsWordIndex: index);
  }

  void goToPreviousSentence() {
    if (state.currentSentenceIndex == 0) return;
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex - 1,
      isCompleted: false,
      currentWordPointer: 0,
      matchedWordIndices: const <int>{},
      wordConfidences: const <String, double>{},
      matchRate: 0.0,
      averageWordConfidence: 0.0,
    );
  }

  bool goToNextSentence() {
    if (state.currentSentenceIndex >= state.script.length - 1) {
      if (!state.hasAttemptedCurrentSentence) {
        return false;
      }
      state = state.copyWith(isCompleted: true);
      return true;
    }
    state = state.copyWith(
      currentSentenceIndex: state.currentSentenceIndex + 1,
      isCompleted: false,
      currentWordPointer: 0,
      matchedWordIndices: const <int>{},
      wordConfidences: const <String, double>{},
      matchRate: 0.0,
      averageWordConfidence: 0.0,
    );
    return true;
  }

  void markCurrentSentenceAttempted() {
    final newSet = Set<int>.from(state.attemptedSentenceIndices);
    if (newSet.add(state.currentSentenceIndex)) {
      state = state.copyWith(attemptedSentenceIndices: newSet);
    }
  }

  // Cache key for diffing — skip update when nothing has changed.
  String _lastReportKey = '';

  /// Sequence-aware transcript processing.
  ///
  /// Instead of a bag-of-words `Set.contains`, this method walks a pointer
  /// through the target tokens.  A spoken word only "matches" if it appears
  /// at or near the current pointer position.  Once matched the pointer
  /// advances, enforcing correct word order.
  void processTranscript({
    required List<String> transcripts,
    required double confidence,
    required Map<String, double> liveWordConfidence,
  }) {
    final sentence = state.currentSentence;
    final targetTokens = _tokenizeNonIgnored(sentence);
    if (targetTokens.isEmpty || transcripts.isEmpty) return;

    // Filter to unique transcripts
    final uniqueTranscripts = transcripts.toSet().toList();

    // Build a cheap diff key — skip update when nothing changed.
    final reportKey = '${state.currentSentenceIndex}|'
        '${uniqueTranscripts.join('|')}|'
        '${confidence.toStringAsFixed(2)}|'
        '${liveWordConfidence.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(2)}').join(',')}';
    if (reportKey == _lastReportKey) return;
    _lastReportKey = reportKey;

    var bestPointer = state.currentWordPointer;
    var bestMatched = state.matchedWordIndices;
    var bestConfidences = state.wordConfidences;
    var bestPhoneticScores = state.phoneticScores;

    for (final transcript in uniqueTranscripts) {
      final spokenTokens = _tokenizeAll(transcript);
      final newMatched = Set<int>.from(state.matchedWordIndices);
      final newConfidences = Map<String, double>.from(state.wordConfidences);
      final newPhoneticScores = Map<String, double>.from(state.phoneticScores);
      var pointer = state.currentWordPointer;

      for (final spoken in spokenTokens) {
        if (pointer >= targetTokens.length) break;

        int? matchedIndex;
        // Lookahead max 2 words (i.e. tolerate if user skipped 1 or 2 words)
        for (int i = pointer; i < targetTokens.length && i <= pointer + 2; i++) {
          final expectedToken = targetTokens[i];
          final expected = expectedToken.normalized;
          final allowedDist = expected.length > 5 ? 2 : (expected.length > 3 ? 1 : 0);

          if (spoken == expected || _levenshtein(spoken, expected) <= allowedDist) {
            matchedIndex = i;
            break;
          }
        }

        if (matchedIndex != null) {
          final expectedToken = targetTokens[matchedIndex];
          final expected = expectedToken.normalized;
          newMatched.add(matchedIndex);
          
          final dist = _levenshtein(spoken, expected);
          
          // --- REAL-TIME ARTICULATION (PHONETIC) SCORE ---
          // Based on Option B: Live Letter-by-Letter Exactness.
          final double phoneticScore;
          if (expected.isEmpty || spoken == expected) {
            phoneticScore = 1.0;
          } else {
            // Normalized Levenshtein distance: 0.0 (perfect) to 1.0 (completely different)
            // Clarity is the inverse.
            final dNorm = dist / expected.length;
            phoneticScore = (1.0 - dNorm).clamp(0.0, 1.0);
          }
          newPhoneticScores[expected] = phoneticScore;
          
          // --- RECOGNITION CONFIDENCE ---
          final sttConf = liveWordConfidence[expected] ?? liveWordConfidence[spoken] ?? confidence;
          
          // Sequence bonus (if matched in order, it's very stable)
          final double sequenceBonus = (dist == 0) ? 0.15 : (dist == 1 ? 0.05 : 0.0);
          final double sanityFloor = (dist == 0) ? 0.70 : (dist == 1 ? 0.45 : 0.30);
          
          newConfidences[expected] = (sttConf + sequenceBonus).clamp(sanityFloor, 1.0);
          
          pointer = matchedIndex + 1;
        }
      }

      if (newMatched.length > bestMatched.length) {
        bestMatched = newMatched;
        bestPointer = pointer;
        bestConfidences = newConfidences;
        bestPhoneticScores = newPhoneticScores;
      }
    }

    // Compute live stats from the best matched sequence
    final matchRate = bestMatched.length / targetTokens.length;
    final matchedConfs = bestMatched
        .map((i) => bestConfidences[targetTokens[i].normalized] ?? confidence)
        .toList();
    final avgConf = matchedConfs.isEmpty
        ? 0.0
        : matchedConfs.reduce((a, b) => a + b) / matchedConfs.length;

    // Mark sentence as attempted if any words matched.
    final newAttempted = Set<int>.from(state.attemptedSentenceIndices);
    if (bestMatched.isNotEmpty) {
      newAttempted.add(state.currentSentenceIndex);
    }

    // Build the confidence report for Gemini analysis.
    final report = {
      'sentenceIndex': state.currentSentenceIndex,
      'sentenceText': sentence,
      'words': List.generate(targetTokens.length, (i) {
        final word = targetTokens[i].normalized;
        final matched = bestMatched.contains(i);
        final wc = matched ? (bestConfidences[word] ?? confidence) : 0.0;
        return {
          'word': word,
          'matched': matched,
          'confidence': wc,
          'band': _confidenceBand(wc),
        };
      }),
    };

    final newSentenceConfidence =
        Map<int, Map<String, dynamic>>.from(state.sentenceWordConfidence);
    newSentenceConfidence[state.currentSentenceIndex] = report;

    final orderedSentences = newSentenceConfidence.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final newJson = jsonEncode({
      'exercise': item.title,
      'sentences': orderedSentences.map((e) => e.value).toList(),
    });

    state = state.copyWith(
      currentWordPointer: bestPointer,
      matchedWordIndices: bestMatched,
      wordConfidences: bestConfidences,
      phoneticScores: bestPhoneticScores,
      matchRate: matchRate.clamp(0.0, 1.0),
      averageWordConfidence: avgConf.clamp(0.0, 1.0),
      attemptedSentenceIndices: newAttempted,
      sentenceWordConfidence: newSentenceConfidence,
      latestWordConfidenceJson: newJson,
    );
  }

  /// Backward-compatible wrapper — delegates to [processTranscript].
  void updateWordConfidenceReport({
    required String sentence,
    required List<String> targetTokens,
    required Set<String> spokenTokens,
    required double confidence,
    required Map<String, double> liveWordConfidence,
  }) {
    // Reconstruct a pseudo-transcript from the spoken tokens so the
    // pointer-based logic can consume them.
    processTranscript(
      transcripts: [spokenTokens.join(' ')],
      confidence: confidence,
      liveWordConfidence: liveWordConfidence,
    );
  }

  // ── Helpers ──

  List<SpeakingWordToken> _tokenizeNonIgnored(String input) {
    final phonetic = (item.phoneticScript != null &&
            state.currentSentenceIndex < item.phoneticScript!.length)
        ? item.phoneticScript![state.currentSentenceIndex]
        : null;
    return SpeakingEngine.tokenizeStatic(input, item.ignoreWords,
            phoneticInput: phonetic)
        .where((t) => !t.ignored && t.normalized.isNotEmpty)
        .toList();
  }

  List<String> _tokenizeAll(String input) {
    return SpeakingEngine.tokenizeStatic(input, item.ignoreWords)
        .where((t) => !t.ignored)
        .map((t) => t.normalized)
        .where((t) => t.isNotEmpty)
        .toList();
  }

  static int _levenshtein(String a, String b) {
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

  String _confidenceBand(double confidence) {
    if (confidence >= 0.75) return 'high';
    if (confidence >= 0.5) return 'medium';
    return 'low';
  }

  Future<void> runGeminiSessionAnalysis() async {
    final jsonPayload = state.latestWordConfidenceJson.trim();
    if (jsonPayload.isEmpty || jsonPayload == '{}') {
      state = state.copyWith(uiState: const SpeakingExerciseError('No session JSON data available yet.'));
      return;
    }

    state = state.copyWith(uiState: const SpeakingExerciseAnalyzing());

    try {
      final prompt = 'Exercise: ${item.title}\nScenario: ${item.scenario}\nPrompt: ${item.prompt}\nInput JSON:\n$jsonPayload\nAnalyze this session and return the required strict JSON schema.';
      final raw = await _geminiService.ask(prompt, CorePrompts.speakingExerciseAnalysisSystemPrompt(item.title), true);
      final parsed = _extractJsonObject(raw);

      if (parsed == null) {
        final payload = jsonDecode(jsonPayload) as Map<String, dynamic>;
        final fallback = _fallbackAnalysis(payload);
        final overall = fallback.isEmpty ? 0.0 : fallback.map((e) => e['score'] as double).reduce((a, b) => a + b) / fallback.length;
        
        state = state.copyWith(uiState: SpeakingExerciseSuccess(
          score: overall,
          summary: 'Fallback analysis used because Gemini did not return valid JSON.',
          suggestions: const [
            'Re-record difficult words slowly.',
            'Use pronunciation practice buttons for low-score words.',
            'Repeat each sentence at least twice for stability.',
          ],
          wordAnalysis: fallback,
        ));
        return;
      }

      final words = _parseWordAnalysis(parsed);
      final score = ((parsed['overallScore'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0);
      final summary = (parsed['summary'] ?? '').toString().trim();
      final suggestions = (parsed['suggestions'] is List)
          ? (parsed['suggestions'] as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList()
          : const <String>[];

      state = state.copyWith(uiState: SpeakingExerciseSuccess(
        score: score,
        summary: summary,
        suggestions: suggestions,
        wordAnalysis: words,
      ));
    } catch (e) {
      state = state.copyWith(uiState: SpeakingExerciseError('Analysis failed: $e'));
    }
  }

  Map<String, dynamic>? _extractJsonObject(String raw) {
    final codeBlock = RegExp(r'```json\s*([\s\S]*?)```', caseSensitive: false).firstMatch(raw)?.group(1);
    final candidate = (codeBlock ?? raw).trim();

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(candidate.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  List<Map<String, dynamic>> _fallbackAnalysis(Map<String, dynamic> payload) {
    final scores = _sessionWordScoresFromPayload(payload);
    return scores.entries.map((entry) {
      final score = entry.value;
      final status = score >= 75 ? 'high' : (score >= 50 ? 'medium' : 'low');
      final issue = status == 'high' ? 'Stable.' : (status == 'medium' ? 'Inconsistent.' : 'Unclear.');
      final suggestion = status == 'high' ? 'Keep it up.' : (status == 'medium' ? 'Slow down.' : 'Practice syllable by syllable.');
      return {
        'word': entry.key,
        'score': score,
        'status': status,
        'issue': issue,
        'suggestion': suggestion,
      };
    }).toList()..sort((a, b) => (a['score'] as double).compareTo(b['score'] as double));
  }

  Map<String, double> _sessionWordScoresFromPayload(Map<String, dynamic> payload) {
    final out = <String, List<double>>{};
    final sentences = payload['sentences'];
    if (sentences is! List) return const {};

    for (final sentence in sentences) {
      if (sentence is! Map<String, dynamic>) continue;
      final words = sentence['words'];
      if (words is! List) continue;
      for (final entry in words) {
        if (entry is! Map<String, dynamic>) continue;
        final word = (entry['word'] ?? '').toString().trim().toLowerCase();
        if (word.isEmpty) continue;
        final c = (entry['confidence'] as num?)?.toDouble() ?? 0.0;
        out.putIfAbsent(word, () => <double>[]).add(c);
      }
    }

    return out.map((word, values) {
      final avg = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
      return MapEntry(word, (avg * 100).clamp(0.0, 100.0));
    });
  }

  List<Map<String, dynamic>> _parseWordAnalysis(Map<String, dynamic> responseJson) {
    final items = responseJson['wordAnalysis'];
    if (items is! List) return const [];

    return items.whereType<Map>().map((item) {
      return {
        'word': (item['word'] ?? '').toString().trim().toLowerCase(),
        'score': ((item['score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0),
        'status': (item['status'] ?? '').toString().toLowerCase(),
        'issue': (item['issue'] ?? '').toString().trim(),
        'suggestion': (item['suggestion'] ?? '').toString().trim(),
      };
    }).toList();
  }
}
