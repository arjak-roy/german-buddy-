import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum SpeechLanguage { german, english }

class SpeechCaptureResult {
  final String text;
  final double? confidence;

  const SpeechCaptureResult({required this.text, this.confidence});
}

class SpeechProvider extends ChangeNotifier {
  final SpeechToText _speech = SpeechToText();
  static const String _wakeWord = 'buddy';
  static const Set<String> _buddyDirectVariants = {
    'buddy',
    'budi',
    'budy',
    'buddi',
    'baddi',
    'bady',
    'body',
    'bodi',
    'buddyy',
    'budde',
  };
  static const Map<String, String> _defaultWordCorrections = {
    'gutun': 'guten',
    'guuten': 'guten',
    'gutan': 'guten',
    'tage': 'tag',
    'tak': 'tag',
    'dankee': 'danke',
    'bitteh': 'bitte',
  };

  bool _initialized = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _showDebugPanel = false;
  String _lastStatus = 'idle';
  String? _lastError;

  String _recognized = '';
  String _finalRecognized = '';
  double? _lastConfidence;
  DateTime _lastResultAt = DateTime.fromMillisecondsSinceEpoch(0);

  double _voiceLevel = 0.0;
  double _minSoundLevel = 50000;
  double _maxSoundLevel = -50000;

  SpeechLanguage _language = SpeechLanguage.german;
  String _germanLocaleId = 'de_DE';
  String _englishLocaleId = 'en_US';
  final Map<String, String> _wordCorrections =
      Map<String, String>.from(_defaultWordCorrections);

  bool get speechReady => _speechReady;
  bool get isListening => _isListening;
  bool get showDebugPanel => _showDebugPanel;
  double get voiceLevel => _voiceLevel;
  SpeechLanguage get language => _language;
  bool get isGerman => _language == SpeechLanguage.german;
  double? get lastConfidence => _lastConfidence;
  String get lastRecognizedText => _recognized;
  String get confirmedText => _finalRecognized;
  String get currentTranscript =>
      _finalRecognized.isNotEmpty ? _finalRecognized : _recognized;
  bool get hasConfirmedSentence => _finalRecognized.isNotEmpty;
  String get activeLocaleId => isGerman ? _germanLocaleId : _englishLocaleId;
  String get lastStatus => _lastStatus;
  String? get lastError => _lastError;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    final available = await _speech.initialize(
      onStatus: (status) {
        _lastStatus = status;

        // Plugin status can transition to done/notListening automatically.
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          _voiceLevel = 0.0;
        }
        notifyListeners();
      },
      onError: (error) {
        _lastError =
            '${error.errorMsg} (${error.permanent ? 'permanent' : 'temporary'})';
        _lastStatus = 'error';
        _isListening = false;
        _voiceLevel = 0.0;
        notifyListeners();
      },
      debugLogging: kDebugMode,
    );

    if (available) {
      final locales = await _speech.locales();
      _germanLocaleId = _resolvePreferredLocale(
        locales,
        preferred: const ['de-DE'],
        languagePrefix: 'de',
        fallback: _germanLocaleId,
      );
      _englishLocaleId = _resolvePreferredLocale(
        locales,
        preferred: const ['en-GB', 'en_GB', 'en-US', 'en_US'],
        languagePrefix: 'en',
        fallback: _englishLocaleId,
      );
    }

    _speechReady = available;
    _lastStatus = available ? 'ready' : 'unavailable';
    if (!available && _lastError == null) {
      _lastError = 'Speech recognition unavailable on this device.';
    }
    notifyListeners();
  }

  void toggleLanguage() {
    _language = isGerman ? SpeechLanguage.english : SpeechLanguage.german;
    notifyListeners();
  }

  void toggleDebugPanel() {
    _showDebugPanel = !_showDebugPanel;
    notifyListeners();
  }

  void setWordCorrections(Map<String, String> corrections) {
    _wordCorrections
      ..clear()
      ..addEntries(
        corrections.entries.map(
          (entry) => MapEntry(
            entry.key.trim().toLowerCase(),
            entry.value.trim().toLowerCase(),
          ),
        ),
      );
    notifyListeners();
  }

  void addWordCorrections(Map<String, String> corrections) {
    for (final entry in corrections.entries) {
      final key = entry.key.trim().toLowerCase();
      final value = entry.value.trim().toLowerCase();
      if (key.isEmpty || value.isEmpty) continue;
      _wordCorrections[key] = value;
    }
    notifyListeners();
  }

  void resetWordCorrections() {
    _wordCorrections
      ..clear()
      ..addAll(_defaultWordCorrections);
    notifyListeners();
  }

  Future<bool> startListening() async {
    if (!_speechReady || _isListening) return false;

    _lastError = null;
    _lastStatus = 'starting';
    _recognized = '';
    _finalRecognized = '';
    _lastConfidence = null;
    _isListening = true;
    _voiceLevel = 0.0;
    _minSoundLevel = 50000;
    _maxSoundLevel = -50000;
    _lastResultAt = DateTime.now();
    notifyListeners();

    final started = await _speech.listen(
      localeId: isGerman ? _germanLocaleId : _englishLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          _recognized = _postProcessTranscript(words);
          _lastResultAt = DateTime.now();
          if (result.hasConfidenceRating) {
            final c = result.confidence;
            // Some engines emit 0.0 as a placeholder confidence.
            _lastConfidence = (c > 0.0 && c <= 1.0) ? c : null;
          }
          if (result.finalResult) {
            _finalRecognized = _postProcessTranscript(words);
          }
          notifyListeners();
        }
      },
      onSoundLevelChange: (level) {
        _minSoundLevel = level < _minSoundLevel ? level : _minSoundLevel;
        _maxSoundLevel = level > _maxSoundLevel ? level : _maxSoundLevel;

        final range = (_maxSoundLevel - _minSoundLevel).abs();
        final normalized = range < 0.0001
            ? 0.0
            : ((level - _minSoundLevel) / range).clamp(0.0, 1.0);

        // Keep less inertia so visual feedback follows sound changes faster.
        _voiceLevel = (_voiceLevel * 0.22) + (normalized * 0.78);
        notifyListeners();
      },
    );

    if (!started) {
      _isListening = false;
      _voiceLevel = 0.0;
      _lastStatus = 'failed_to_start';
      _lastError ??= 'Could not start speech listening.';
      notifyListeners();
      return false;
    }

    _lastStatus = 'listening';
    notifyListeners();

    return true;
  }

  Future<SpeechCaptureResult?> stopListeningAndCollect() async {
    final wasListening = _isListening;
    if (wasListening) {
      await _speech.stop();
    }
    await _waitForTrailingResults();

    _isListening = false;
    if (wasListening) {
      _lastStatus = 'stopped';
    }
    _voiceLevel = 0.0;
    notifyListeners();

    final text = (_finalRecognized.isNotEmpty ? _finalRecognized : _recognized)
        .trim();
    if (text.isEmpty) return null;

    return SpeechCaptureResult(text: text, confidence: _lastConfidence);
  }

  void clearTranscript() {
    _recognized = '';
    _finalRecognized = '';
    _lastConfidence = null;
    notifyListeners();
  }

  String _postProcessTranscript(String text) {
    if (text.trim().isEmpty) return text;

    final tokens = text.split(RegExp(r'\s+'));
    final normalized = <String>[];

    for (final token in tokens) {
      final mapped = _normalizeToken(token);
      normalized.add(mapped);
    }

    return normalized.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _normalizeToken(String token) {
    final core = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (core.isEmpty) return token;

    final lowerCore = core.toLowerCase();
    final correctedWord = _wordCorrections[lowerCore];
    if (correctedWord != null) {
      final replacement = _applyOriginalCasePattern(
        source: core,
        replacement: correctedWord,
      );
      return token.replaceFirst(core, replacement);
    }

    final isBuddy = _buddyDirectVariants.contains(lowerCore) ||
        _levenshtein(lowerCore, _wakeWord) <= 1;
    if (!isBuddy) return token;

    final replacement = _applyOriginalCasePattern(
      source: core,
      replacement: _wakeWord,
    );

    return token.replaceFirst(core, replacement);
  }

  String _applyOriginalCasePattern({
    required String source,
    required String replacement,
  }) {
    final isAllUpper = source == source.toUpperCase();
    if (isAllUpper) return replacement.toUpperCase();

    final isCapitalized = RegExp(r'^[A-Z]').hasMatch(source);
    if (!isCapitalized) return replacement;

    return replacement[0].toUpperCase() + replacement.substring(1);
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final rows = a.length + 1;
    final cols = b.length + 1;
    final dist = List<List<int>>.generate(
      rows,
      (_) => List<int>.filled(cols, 0),
    );

    for (var i = 0; i < rows; i++) {
      dist[i][0] = i;
    }
    for (var j = 0; j < cols; j++) {
      dist[0][j] = j;
    }

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        final deletion = dist[i - 1][j] + 1;
        final insertion = dist[i][j - 1] + 1;
        final substitution = dist[i - 1][j - 1] + cost;
        dist[i][j] = [deletion, insertion, substitution].reduce(
          (minValue, next) => next < minValue ? next : minValue,
        );
      }
    }

    return dist[a.length][b.length];
  }

  Future<void> cancelListening() async {
    await _speech.cancel();
    _isListening = false;
    _voiceLevel = 0.0;
    _lastStatus = 'cancelled';
    notifyListeners();
  }

  String _resolvePreferredLocale(
    List<LocaleName> locales, {
    required List<String> preferred,
    required String languagePrefix,
    required String fallback,
  }) {
    final byNormalized = <String, String>{
      for (final l in locales) _normalizeLocale(l.localeId): l.localeId,
    };

    for (final candidate in preferred) {
      final found = byNormalized[_normalizeLocale(candidate)];
      if (found != null) return found;
    }

    for (final locale in locales) {
      if (locale.localeId.toLowerCase().startsWith(languagePrefix)) {
        return locale.localeId;
      }
    }

    return fallback;
  }

  String _normalizeLocale(String localeId) {
    return localeId.trim().toLowerCase().replaceAll('_', '-');
  }

  Future<void> _waitForTrailingResults() async {
    const maxWait = Duration(milliseconds: 1200);
    const stableWindow = Duration(milliseconds: 420);
    final started = DateTime.now();

    while (DateTime.now().difference(started) < maxWait) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final quietFor = DateTime.now().difference(_lastResultAt);
      if (quietFor >= stableWindow) {
        break;
      }
    }
  }
}
