import 'package:flutter/foundation.dart';

import '../data/models/pronunciation_analysis_report.dart';
import '../data/services/gemini_service.dart';
import '../ui/features/pronunciation/models/pronunciation_item.dart';

class PronunciationAnalysisProvider extends ChangeNotifier {
  final GeminiService _geminiService = GeminiService();

  final Map<String, PronunciationAnalysisReport> _reportsByWord = {};
  final Map<String, String> _analyzedFilePathsByWord = {};
  String? _currentWordKey;
  bool _isLoading = false;
  String? _error;

  String _wordKey(PronunciationItem item) =>
      '${item.german.trim().toLowerCase()}|${item.english.trim().toLowerCase()}';

  PronunciationAnalysisReport? get report =>
      _currentWordKey == null ? null : _reportsByWord[_currentWordKey];
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReport => report != null;
  Map<String, PronunciationAnalysisReport> get allReports =>
      Map.unmodifiable(_reportsByWord);

  double get averageScore {
    if (_reportsByWord.isEmpty) return 0.0;
    final total = _reportsByWord.values.fold<int>(
      0,
      (previousValue, report) => previousValue + report.overallScore,
    );
    return total / _reportsByWord.length;
  }

  String? get topPerformer {
    if (_reportsByWord.isEmpty) return null;
    final bestEntry = _reportsByWord.entries.reduce(
      (a, b) => a.value.overallScore >= b.value.overallScore ? a : b,
    );
    return '${bestEntry.key.split('|').first} (${bestEntry.value.overallScore}/100)';
  }

  String? get improvementTarget {
    if (_reportsByWord.isEmpty) return null;
    final worstEntry = _reportsByWord.entries.reduce(
      (a, b) => a.value.overallScore <= b.value.overallScore ? a : b,
    );
    return '${worstEntry.key.split('|').first} (${worstEntry.value.overallScore}/100)';
  }

  String? get analyzedFilePath => _currentWordKey == null
      ? null
      : _analyzedFilePathsByWord[_currentWordKey];

  void selectWord(PronunciationItem item) {
    _currentWordKey = _wordKey(item);
    _error = null;
    notifyListeners();
  }

  Future<bool> analyzeRecording({
    required PronunciationItem item,
    required String filePath,
  }) async {
    if (_isLoading) return false;

    _currentWordKey = _wordKey(item);

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final analyzedReport = await _geminiService.analyzePronunciationAudio(
        targetWord: item.german,
        targetEnglish: item.english,
        targetPhonetic: item.phonetic,
        audioFilePath: filePath,
      );
      _reportsByWord[_currentWordKey!] = analyzedReport;
      _analyzedFilePathsByWord[_currentWordKey!] = filePath;
      return true;
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearTransientState() {
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
