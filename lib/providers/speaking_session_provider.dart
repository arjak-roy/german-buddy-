import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../ui/features/speaking/models/speaking_exercise_state.dart';
import '../core/constants/prompts.dart';
import '../data/services/gemini_service.dart';

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

  void updateWordConfidenceReport({
    required String sentence,
    required List<String> targetTokens,
    required Set<String> spokenTokens,
    required double confidence,
    required Map<String, double> liveWordConfidence,
  }) {
    // FIX 5: Build a cheap diff key from spoken tokens + truncated confidence.
    // Skip the update if nothing meaningful changed since the last invocation.
    final reportKey = '${state.currentSentenceIndex}|'
        '${spokenTokens.toList()..sort()}|'
        '${confidence.toStringAsFixed(2)}|'
        '${liveWordConfidence.entries.map((e) => '${e.key}:${e.value.toStringAsFixed(2)}').join(',')}';
    if (reportKey == _lastReportKey) return;
    _lastReportKey = reportKey;

    final newSet = Set<int>.from(state.attemptedSentenceIndices);
    if (spokenTokens.isNotEmpty) {
      newSet.add(state.currentSentenceIndex);
    }

    final report = {
      'sentenceIndex': state.currentSentenceIndex,
      'sentenceText': sentence,
      'words': targetTokens.map((word) {
        final matched = spokenTokens.contains(word);
        final wordConfidence = matched ? (liveWordConfidence[word] ?? confidence) : 0.0;
        return {
          'word': word,
          'matched': matched,
          'confidence': wordConfidence,
          'band': _confidenceBand(wordConfidence),
        };
      }).toList(),
    };

    final newConfidence = Map<int, Map<String, dynamic>>.from(state.sentenceWordConfidence);
    newConfidence[state.currentSentenceIndex] = report;

    final orderedSentences = newConfidence.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final newJson = jsonEncode({
      'exercise': item.title,
      'sentences': orderedSentences.map((entry) => entry.value).toList(),
    });

    state = state.copyWith(
      attemptedSentenceIndices: newSet,
      sentenceWordConfidence: newConfidence,
      latestWordConfidenceJson: newJson,
    );
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
