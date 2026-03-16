import 'package:flutter/foundation.dart';

import '../data/models/chat_entry.dart';
import '../data/services/gemini_service.dart';

/// Holds the list of messages in the Buddy chat, with some initial mock
/// data. In a real app this could be backed by an API or websocket.
class ChatProvider extends ChangeNotifier {
  final List<ChatEntry> _messages = []; // start empty for real interaction

  List<ChatEntry> get messages => List.unmodifiable(_messages);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Uint8List? _latestAiAudioBytes;
  String? _latestAiAudioMimeType;
  int _latestAiAudioToken = 0;
  Uint8List? get latestAiAudioBytes => _latestAiAudioBytes;
  String? get latestAiAudioMimeType => _latestAiAudioMimeType;
  int get latestAiAudioToken => _latestAiAudioToken;

  /// Add a raw entry and notify listeners.
  void addMessage(ChatEntry entry) {
    _messages.add(entry);
    notifyListeners();
  }

  /// Clear all chat history.
  void clear() {
    _messages.clear();
    notifyListeners();
  }

  // service used to query the language model
  final GeminiService _service = GeminiService();

  /// Split the raw model output into German text + English translation.
  ChatEntry _parseReply(String raw) {
    final trimmed = raw.trim();

    // Structured markdown format for list/table responses:
    // [German]\n...markdown...\n[English]\n...markdown...
    final structured = RegExp(
      r'^\s*\[German\]\s*\n([\s\S]*?)\n\s*\[English\]\s*\n([\s\S]*?)\s*$',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(trimmed);

    if (structured != null) {
      final german = (structured.group(1) ?? '').trim();
      final english = (structured.group(2) ?? '').trim();
      return ChatEntry(text: german, translated: english, isUser: false);
    }

    // The expected format is:
    // German sentence on first line
    // English translation on second line, optionally in parentheses.
    final lines =
        trimmed.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    String german = '';
    String english = '';
    if (lines.isNotEmpty) {
      german = lines[0];
      if (lines.length > 1) {
        english = lines.sublist(1).join(' ');
      } else {
        // try extract parentheses
        final match = RegExp(r'\((.*)\)').firstMatch(german);
        if (match != null) {
          english = match.group(1)!;
          german = german.replaceAll(RegExp(r'\(.*\)'), '').trim();
        }
      }
    }
    return ChatEntry(text: german, translated: english, isUser: false);
  }

  /// Sends [text] as a user message, then awaits a reply from Gemini and
  /// appends it. Any errors are also added as bot messages.
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // add user message immediately
    addMessage(ChatEntry(text: text, isUser: true));

    _isLoading = true;
    notifyListeners();

    try {
      final reply = await _service.askBuddy(text);
      addMessage(_parseReply(reply.text));
      if (reply.audioBytes != null && reply.audioBytes!.isNotEmpty) {
        _latestAiAudioBytes = reply.audioBytes;
        _latestAiAudioMimeType = reply.audioMimeType;
        _latestAiAudioToken += 1;
      }
    } catch (e) {
      addMessage(ChatEntry(text: 'Fehler: $e', isUser: false));
    }

    _isLoading = false;
    notifyListeners();
  }
}
