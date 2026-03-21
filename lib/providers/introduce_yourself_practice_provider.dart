import 'dart:convert';

import 'package:flutter/foundation.dart';

class IntroduceYourselfPracticeProvider extends ChangeNotifier {
  final List<String> script;

  IntroduceYourselfPracticeProvider({required this.script});

  int _currentSentenceIndex = 0;
  int? _queuedAdvanceFor;
  bool _isCompleted = false;
  double _ttsSpeed = 0.45;
  bool _isTtsSpeaking = false;
  int _ttsWordIndex = -1;
  final Set<int> _attemptedSentenceIndices = <int>{};

  final Map<int, Map<String, dynamic>> _sentenceWordConfidence = {};
  String _latestWordConfidenceJson = '{}';

  int get currentSentenceIndex => _currentSentenceIndex;
  int? get queuedAdvanceFor => _queuedAdvanceFor;
  bool get isCompleted => _isCompleted;
  double get ttsSpeed => _ttsSpeed;
  bool get isTtsSpeaking => _isTtsSpeaking;
  int get ttsWordIndex => _ttsWordIndex;
  bool get hasAttemptedCurrentSentence =>
      _attemptedSentenceIndices.contains(_currentSentenceIndex);
  bool get canOpenAnalysis =>
      _attemptedSentenceIndices.contains(script.length - 1);
  String get latestWordConfidenceJson => _latestWordConfidenceJson;

  int get speakingSentenceCount => _sentenceWordConfidence.length;

  Map<String, double> get speakingWordConfidence {
    final values = <String, List<double>>{};
    for (final sentence in _sentenceWordConfidence.values) {
      final words = (sentence['words'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final entry in words) {
        final word = (entry['word'] as String).trim().toLowerCase();
        final confidence = (entry['confidence'] as num).toDouble();
        values.putIfAbsent(word, () => []).add(confidence);
      }
    }

    final avg = <String, double>{};
    for (final kv in values.entries) {
      final list = kv.value;
      final mean = list.isEmpty
          ? 0.0
          : list.reduce((a, b) => a + b) / list.length;
      avg[kv.key] = mean;
    }
    return avg;
  }

  double get speakingAverageConfidence {
    final wordConfidence = speakingWordConfidence;
    if (wordConfidence.isEmpty) return 0.0;
    return wordConfidence.values.reduce((a, b) => a + b) /
        wordConfidence.length;
  }

  String get currentSentence => script[_currentSentenceIndex];

  void setTtsSpeed(double value) {
    _ttsSpeed = value;
    notifyListeners();
  }

  void setTtsStarted() {
    _isTtsSpeaking = true;
    _ttsWordIndex = -1;
    notifyListeners();
  }

  void setTtsStopped() {
    _isTtsSpeaking = false;
    _ttsWordIndex = -1;
    notifyListeners();
  }

  void setTtsWordIndex(int index) {
    if (_ttsWordIndex == index) return;
    _ttsWordIndex = index;
    notifyListeners();
  }

  void goToPreviousSentence() {
    if (_currentSentenceIndex == 0) return;
    _currentSentenceIndex -= 1;
    _isCompleted = false;
    _queuedAdvanceFor = null;
    notifyListeners();
  }

  bool goToNextSentence() {
    if (_currentSentenceIndex >= script.length - 1) {
      if (!hasAttemptedCurrentSentence) {
        return false;
      }
      _isCompleted = true;
      notifyListeners();
      return true;
    }

    _currentSentenceIndex += 1;
    _isCompleted = false;
    _queuedAdvanceFor = null;
    notifyListeners();
    return true;
  }

  void markCurrentSentenceAttempted() {
    final inserted = _attemptedSentenceIndices.add(_currentSentenceIndex);
    if (inserted) {
      notifyListeners();
    }
  }

  void markCompletionIfLast() {
    if (_currentSentenceIndex >= script.length - 1) {
      _isCompleted = true;
      notifyListeners();
    }
  }

  void queueAdvanceForCurrent() {
    _queuedAdvanceFor = _currentSentenceIndex;
    notifyListeners();
  }

  void clearQueuedAdvance() {
    _queuedAdvanceFor = null;
    notifyListeners();
  }

  void advanceAfterSuccess() {
    if (_currentSentenceIndex >= script.length - 1) {
      _isCompleted = true;
    } else {
      _currentSentenceIndex += 1;
    }
    _queuedAdvanceFor = null;
    notifyListeners();
  }

  String confidenceBand(double confidence) {
    if (confidence >= 0.75) return 'high';
    if (confidence >= 0.5) return 'medium';
    return 'low';
  }

  void updateWordConfidenceReport({
    required String sentence,
    required List<String> targetTokens,
    required Set<String> spokenTokens,
    required double confidence,
    required Map<String, double> liveWordConfidence,
    bool notify = true,
  }) {
    if (spokenTokens.isNotEmpty) {
      _attemptedSentenceIndices.add(_currentSentenceIndex);
    }

    final report = {
      'sentenceIndex': _currentSentenceIndex,
      'sentenceText': sentence,
      'words': targetTokens.map((word) {
        final matched = spokenTokens.contains(word);
        final wordConfidence = matched
            ? (liveWordConfidence[word] ?? confidence)
            : 0.0;
        return {
          'word': word,
          'matched': matched,
          'confidence': wordConfidence,
          'band': confidenceBand(wordConfidence),
        };
      }).toList(),
    };

    // Keep a cumulative session payload: one entry per sentence index.
    _sentenceWordConfidence[_currentSentenceIndex] = report;

    final orderedSentences = _sentenceWordConfidence.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final newJson = jsonEncode({
      'exercise': 'Introduce Yourself',
      'sentences': orderedSentences.map((entry) => entry.value).toList(),
    });
    final changed = newJson != _latestWordConfidenceJson;
    _latestWordConfidenceJson = newJson;

    if (notify && changed) {
      notifyListeners();
    }
  }
}
