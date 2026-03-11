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
    // The expected format is:
    // German sentence on first line
    // English translation on second line, optionally in parentheses.
    final lines = raw.trim().split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
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
      final reply = await _service.ask(text);
      addMessage(_parseReply(reply));
    } catch (e) {
      addMessage(ChatEntry(text: 'Fehler: $e', isUser: false));
    }

    _isLoading = false;
    notifyListeners();
  }
}
