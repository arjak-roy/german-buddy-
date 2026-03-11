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
          _recognized = words;
          _lastResultAt = DateTime.now();
          if (result.hasConfidenceRating) {
            final c = result.confidence;
            // Some engines emit 0.0 as a placeholder confidence.
            _lastConfidence = (c > 0.0 && c <= 1.0) ? c : null;
          }
          if (result.finalResult) {
            _finalRecognized = words;
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
    if (!_isListening) return null;

    await _speech.stop();
    await _waitForTrailingResults();

    _isListening = false;
    _lastStatus = 'stopped';
    _voiceLevel = 0.0;
    notifyListeners();

    final text = (_finalRecognized.isNotEmpty ? _finalRecognized : _recognized)
        .trim();
    if (text.isEmpty) return null;

    return SpeechCaptureResult(text: text, confidence: _lastConfidence);
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
