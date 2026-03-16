import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Holds the user's selected German TTS voice and provides helpers for
/// applying it to any [FlutterTts] instance.
class VoiceProvider extends ChangeNotifier {
  String? _selectedName;
  String? _selectedLocale;
  List<Map<String, String>> _germanVoices = const [];
  bool _loaded = false;

  String? get selectedName => _selectedName;
  String? get selectedLocale => _selectedLocale;
  List<Map<String, String>> get germanVoices => _germanVoices;
  bool get loaded => _loaded;

  /// Queries the device for available German voices. No-op if already loaded.
  Future<void> loadVoices() async {
    if (_loaded) return;
    final tts = FlutterTts();
    try {
      final raw = await tts.getVoices;
      if (raw is List) {
        final found = <Map<String, String>>[];
        for (final v in raw) {
          if (v is! Map) continue;
          final name = v['name']?.toString() ?? '';
          final locale = v['locale']?.toString() ?? '';
          if (name.isEmpty || locale.isEmpty) continue;
          if (!locale.toLowerCase().startsWith('de')) continue;
          found.add({'name': name, 'locale': locale});
        }
        _germanVoices = found;
        // Auto-select the first available voice if none has been chosen yet.
        if (_selectedName == null && found.isNotEmpty) {
          _selectedName = found.first['name'];
          _selectedLocale = found.first['locale'];
        }
      }
    } catch (e) {
      debugPrint('VoiceProvider: failed to load voices: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Updates the selected voice and notifies listeners.
  void setVoice(String name, String locale) {
    _selectedName = name;
    _selectedLocale = locale;
    notifyListeners();
  }

  /// Applies German language and the currently selected voice (if any) to [tts].
  Future<void> applyTo(FlutterTts tts) async {
    await tts.setLanguage('de-DE');
    final name = _selectedName;
    final locale = _selectedLocale;
    if (name != null && locale != null) {
      try {
        await tts.setVoice({'name': name, 'locale': locale});
      } catch (e) {
        debugPrint('VoiceProvider.applyTo: could not set voice "$name": $e');
      }
    }
  }
}
