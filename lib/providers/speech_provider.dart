import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../ui/features/speaking/engine/speaking_engine.dart';

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

  // Language detection keywords
  static const Set<String> _germanKeywords = {
    'der',
    'die',
    'das',
    'und',
    'zu',
    'ein',
    'eine',
    'ich',
    'du',
    'er',
    'es',
    'wir',
    'ihr',
    'mein',
    'dein',
    'sein',
    'unser',
    'euer',
    'haben',
    'bin',
    'bist',
    'ist',
    'sind',
    'seid',
    'danke',
    'bitte',
    'guten',
    'tag',
    'abend',
    'morgen',
    'nacht',
    'hallo',
    'wie',
    'was',
    'wo',
    'wann',
    'warum',
    'wer',
    'welcher',
    'welche',
    'welches',
  };

  static const Set<String> _englishKeywords = {
    'the',
    'a',
    'an',
    'and',
    'or',
    'but',
    'in',
    'on',
    'at',
    'to',
    'for',
    'of',
    'with',
    'by',
    'from',
    'is',
    'are',
    'am',
    'be',
    'been',
    'being',
    'have',
    'has',
    'do',
    'does',
    'did',
    'will',
    'would',
    'could',
    'should',
    'may',
    'might',
    'must',
    'can',
    'hello',
    'hi',
    'thanks',
    'thank',
    'please',
    'sorry',
    'yes',
    'no',
    'okay',
    'ok',
    'what',
    'which',
    'who',
    'when',
    'where',
    'why',
    'how',
  };

  bool _initialized = false;
  bool _speechReady = false;
  bool _isListening = false;
  bool _showDebugPanel = false;
  String _lastStatus = 'idle';
  String? _lastError;
  int _sessionGen = 0;

  String _recognized = '';
  String _finalRecognized = '';
  List<String> _currentAlternates = [];
  double? _lastConfidence;
  final Map<String, double> _liveWordConfidence = {};
  final Map<String, double> _wordStability = {};
  final Map<String, int> _wordLastSeenTick = {};
  int _resultTick = 0;
  DateTime _lastResultAt = DateTime.fromMillisecondsSinceEpoch(0);

  double _voiceLevel = 0.0;
  double _minSoundLevel = 50000;
  double _maxSoundLevel = -50000;

  SpeechLanguage _language = SpeechLanguage.german;
  String _germanLocaleId = 'de_DE';
  String _englishLocaleId = 'en_US';
  final Map<String, String> _wordCorrections = Map<String, String>.from(
    _defaultWordCorrections,
  );

  // Mid-utterance language switching tracking
  SpeechLanguage? _lastDetectedLanguage;
  int _consecutiveWordsInDifferentLanguage = 0;
  static const int _minConsecutiveWordsToSwitch = 2;
  bool _isSwitchingLocale = false;
  String _sessionTranscriptPrefix = '';
  bool _allowAutoLanguageSwitch = true;

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
  List<String> get currentAlternates => List.unmodifiable(_currentAlternates);
  bool get hasConfirmedSentence => _finalRecognized.isNotEmpty;
  String get activeLocaleId => isGerman ? _germanLocaleId : _englishLocaleId;
  String get lastStatus => _lastStatus;
  String? get lastError => _lastError;
  bool get allowAutoLanguageSwitch => _allowAutoLanguageSwitch;
  Map<String, double> get liveWordConfidence =>
      Map.unmodifiable(_liveWordConfidence);

  set allowAutoLanguageSwitch(bool value) {
    if (_allowAutoLanguageSwitch == value) return;
    _allowAutoLanguageSwitch = value;
    notifyListeners();
  }

  double? confidenceForWord(String word) {
    final normalized = _normalizeConfidenceToken(word);
    if (normalized.isEmpty) return null;
    return _liveWordConfidence[normalized];
  }

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

  void setLanguage(SpeechLanguage language) {
    if (_language == language) return;
    _language = language;
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
    _currentAlternates.clear();
    _lastConfidence = null;
    _liveWordConfidence.clear();
    _wordStability.clear();
    _wordLastSeenTick.clear();
    _resultTick = 0;
    _isListening = true;
    _voiceLevel = 0.0;
    _minSoundLevel = 50000;
    _maxSoundLevel = -50000;
    _lastResultAt = DateTime.now();
    _lastDetectedLanguage = _language;
    _consecutiveWordsInDifferentLanguage = 0;
    _isSwitchingLocale = false;
    _sessionTranscriptPrefix = '';
    _sessionGen++;
    final gen = _sessionGen;
    notifyListeners();

    final started = await _speech.listen(
      localeId: isGerman ? _germanLocaleId : _englishLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        // Discard results from a previous session that arrived late.
        if (_sessionGen != gen) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          final transcript = _postProcessTranscript(words);
          final combinedTranscript = _mergeWithSessionPrefix(transcript);
          _recognized = combinedTranscript;
          
          final alternates = result.alternates
            .map((e) => _mergeWithSessionPrefix(_postProcessTranscript(e.recognizedWords.trim())))
            .where((t) => t.isNotEmpty && t != combinedTranscript)
            .toList();
          _currentAlternates = alternates;

          _resultTick += 1;
          _lastResultAt = DateTime.now();
          if (result.hasConfidenceRating) {
            final c = result.confidence;
            // Some engines emit 0.0 as a placeholder confidence.
            _lastConfidence = (c > 0.0 && c <= 1.0) ? c : null;
          }
          _updateRealtimeWordConfidence(combinedTranscript, _lastConfidence);

          // Auto-detect language from recognized text
          _autoDetectAndSwitchLanguage(combinedTranscript);

          if (result.finalResult) {
            _finalRecognized = combinedTranscript;
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
    _sessionGen++;
    _recognized = '';
    _finalRecognized = '';
    _currentAlternates.clear();
    _lastConfidence = null;
    _liveWordConfidence.clear();
    _wordStability.clear();
    _wordLastSeenTick.clear();
    _resultTick = 0;
    _lastDetectedLanguage = _language;
    _consecutiveWordsInDifferentLanguage = 0;
    _sessionTranscriptPrefix = '';
    _isSwitchingLocale = false;
    notifyListeners();
  }

  void _updateRealtimeWordConfidence(String transcript, double? confidence) {
    final tokens = transcript
        .split(RegExp(r'\s+'))
        .map(_normalizeConfidenceToken)
        .where((token) => token.isNotEmpty)
        .toSet();

    if (tokens.isEmpty) return;

    for (final token in tokens) {
      final previousStability = _wordStability[token] ?? 0.0;
      final seenBefore = _wordLastSeenTick.containsKey(token);
      // BOOST: Stability grows faster (0.22/0.14) so words quickly move out of "low" zone.
      final stabilityBoost = seenBefore ? 0.22 : 0.14;
      final stability = (previousStability + stabilityBoost).clamp(0.0, 1.0);
      _wordStability[token] = stability;
      _wordLastSeenTick[token] = _resultTick;

      // BOOST: Higher base floor (0.35) so even a first-seen word starts in a visible "low/medium" range.
      final inferredWordConfidence = (0.35 + (stability * 0.65)).clamp(
        0.0,
        1.0,
      );
      // BOOST: Weighted more towards real-time utterance confidence (60%) for dynamism.
      final nextConfidence = (confidence != null && confidence > 0.0)
          ? ((confidence * 0.6) + (inferredWordConfidence * 0.4)).clamp(
              0.0,
              1.0,
            )
          : inferredWordConfidence;

      final previous = _liveWordConfidence[token];
      // Responsive smoothing (favor current over history).
      _liveWordConfidence[token] = previous == null
          ? nextConfidence
          : ((previous * 0.4) + (nextConfidence * 0.6)).clamp(0.0, 1.0);
    }

    // FIX 4 + FIX 8: Time-based decay — decay faster for tokens absent longer.
    for (final token in _wordStability.keys.toList()) {
      if (!tokens.contains(token)) {
        final lastSeenTick = _wordLastSeenTick[token] ?? _resultTick;
        final ticksAbsent = _resultTick - lastSeenTick;
        // Base decay 0.08, accelerating for tokens absent many ticks.
        final decay = (0.08 + (ticksAbsent * 0.02)).clamp(0.0, 0.35);
        _wordStability[token] = (_wordStability[token]! - decay).clamp(0.0, 1.0);
      }
    }
  }

  // FIX 2: Unified normalization — delegates to SpeakingEngine._normalizeToken
  // so that the same canonical form is used everywhere.
  String _normalizeConfidenceToken(String token) {
    return SpeakingEngine.normalizeToken(token);
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

    final isBuddy =
        _buddyDirectVariants.contains(lowerCore) ||
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
        dist[i][j] = [
          deletion,
          insertion,
          substitution,
        ].reduce((minValue, next) => next < minValue ? next : minValue);
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

  String _mergeWithSessionPrefix(String currentTranscript) {
    if (_sessionTranscriptPrefix.isEmpty) return currentTranscript;
    if (currentTranscript.isEmpty) return _sessionTranscriptPrefix;
    return '${_sessionTranscriptPrefix.trim()} ${currentTranscript.trim()}'
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Detects language from recognized text and auto-switches if confidence exceeds threshold.
  /// Threshold: at least 50% of recognized words (minimum 2 words) must match one language.
  void _autoDetectAndSwitchLanguage(String text) {
    if (!_allowAutoLanguageSwitch) return;
    _checkMidUtteranceLanguageSwitch(text);
  }

  /// Detects language transitions within a single utterance (mid-utterance switching).
  /// Example: "guten morgen buddy" - switches from German to English mid-sentence.
  void _checkMidUtteranceLanguageSwitch(String text) {
    if (_isSwitchingLocale) return;

    final tokens = text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^a-z0-9äöüß]'), ''))
        .where((t) => t.isNotEmpty)
        .toList();

    if (tokens.isEmpty) return;

    // Check the last few tokens to detect if the user has switched languages
    final recentTokens = tokens.length > 3
        ? tokens.sublist(tokens.length - 3)
        : tokens;

    final suggestedLanguage = _detectLanguageFromTokenWindow(recentTokens);
    if (suggestedLanguage == null) return;

    // If current language is German but recent words are English (or vice versa),
    // and we have at least the minimum consecutive words, switch languages
    if (suggestedLanguage != _lastDetectedLanguage) {
      _consecutiveWordsInDifferentLanguage++;

      // Switch if we've detected enough consecutive words in a different language
      if (_consecutiveWordsInDifferentLanguage >=
          _minConsecutiveWordsToSwitch) {
        if (suggestedLanguage != _language) {
          if (_isListening) {
            unawaited(_switchLanguageDuringListening(suggestedLanguage));
          } else {
            setLanguage(suggestedLanguage);
          }
        }
        _lastDetectedLanguage = suggestedLanguage;
        _consecutiveWordsInDifferentLanguage = 0;
      }
    } else {
      // Reset counter if we're back to the detected language
      _consecutiveWordsInDifferentLanguage = 0;
      _lastDetectedLanguage = suggestedLanguage;
    }
  }

  SpeechLanguage? _detectLanguageFromTokenWindow(Iterable<String> tokens) {
    int germanScore = 0;
    int englishScore = 0;

    for (final token in tokens) {
      if (_germanKeywords.contains(token)) {
        germanScore++;
      }
      if (_englishKeywords.contains(token)) {
        englishScore++;
      }
    }

    if (germanScore >= 1 && germanScore > englishScore) {
      return SpeechLanguage.german;
    }
    if (englishScore >= 1 && englishScore > germanScore) {
      return SpeechLanguage.english;
    }
    return null;
  }

  Future<void> _switchLanguageDuringListening(
    SpeechLanguage nextLanguage,
  ) async {
    if (_isSwitchingLocale || !_isListening) return;
    if (nextLanguage == _language) return;

    _isSwitchingLocale = true;
    _lastStatus = 'switching_locale';

    // Preserve what has already been recognized before restarting the engine.
    final currentText = _finalRecognized.isNotEmpty
        ? _finalRecognized
        : _recognized;
    if (currentText.trim().isNotEmpty) {
      _sessionTranscriptPrefix = currentText.trim();
    }

    notifyListeners();

    await _speech.stop();
    _language = nextLanguage;

    _sessionGen++;
    final gen = _sessionGen;
    _lastResultAt = DateTime.now();

    final started = await _speech.listen(
      localeId: isGerman ? _germanLocaleId : _englishLocaleId,
      partialResults: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
      cancelOnError: false,
      listenMode: ListenMode.dictation,
      onResult: (result) {
        if (_sessionGen != gen) return;
        final words = result.recognizedWords.trim();
        if (words.isEmpty) return;

        final transcript = _postProcessTranscript(words);
        final combinedTranscript = _mergeWithSessionPrefix(transcript);
        _recognized = combinedTranscript;
        _resultTick += 1;
        _lastResultAt = DateTime.now();

        if (result.hasConfidenceRating) {
          final c = result.confidence;
          _lastConfidence = (c > 0.0 && c <= 1.0) ? c : null;
        }

        _updateRealtimeWordConfidence(combinedTranscript, _lastConfidence);
        _checkMidUtteranceLanguageSwitch(combinedTranscript);

        if (result.finalResult) {
          _finalRecognized = combinedTranscript;
        }
        notifyListeners();
      },
      onSoundLevelChange: (level) {
        _minSoundLevel = level < _minSoundLevel ? level : _minSoundLevel;
        _maxSoundLevel = level > _maxSoundLevel ? level : _maxSoundLevel;

        final range = (_maxSoundLevel - _minSoundLevel).abs();
        final normalized = range < 0.0001
            ? 0.0
            : ((level - _minSoundLevel) / range).clamp(0.0, 1.0);

        _voiceLevel = (_voiceLevel * 0.22) + (normalized * 0.78);
        notifyListeners();
      },
    );

    if (!started) {
      _lastStatus = 'failed_to_switch_locale';
      _lastError ??= 'Could not switch speech locale while listening.';
    } else {
      _lastStatus = 'listening';
    }

    _isSwitchingLocale = false;
    notifyListeners();
  }
}
