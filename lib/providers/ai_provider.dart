import 'package:flutter/foundation.dart';
import '../data/services/gemini_service.dart';

/// Holds AI conversation state and exposes a method to send messages to
/// the Gemini model. Responses are appended to [chatLogs].
class AiProvider extends ChangeNotifier {
  final GeminiService _client = GeminiService();
  final List<String> _chatLogs = [];

  List<String> get chatLogs => List.unmodifiable(_chatLogs);

  Future<void> sendMessage(String message) async {
    _chatLogs.add('You: $message');
    notifyListeners();

    final reply = await _client.ask(message);
    _chatLogs.add('Buddy AI: $reply');
    notifyListeners();
  }

  void clear() {
    _chatLogs.clear();
    notifyListeners();
  }
}
