import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:record/record.dart';

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

  bool _isBuddyPreparing = false;
  bool _isBuddyLiveReady = false;
  bool _isBuddyVoiceActive = false;
  bool _isBuddyVoiceStopping = false;
  String _buddyVoiceTranscript = '';
  int _buddyInterruptToken = 0;
  String? _buddyLiveError;
  bool _didStartLiveConversation = false;

  bool get isBuddyPreparing => _isBuddyPreparing;
  bool get isBuddyLiveReady => _isBuddyLiveReady;
  bool get isBuddyVoiceActive => _isBuddyVoiceActive;
  bool get isBuddyVoiceStopping => _isBuddyVoiceStopping;
  String get buddyVoiceTranscript => _buddyVoiceTranscript;
  int get buddyInterruptToken => _buddyInterruptToken;
  String? get buddyLiveError => _buddyLiveError;

  bool get didStartLiveConversation => _didStartLiveConversation;

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
  final AudioRecorder _buddyAudioRecorder = AudioRecorder();
  StreamSubscription<void>? _buddyInterruptSub;

  ChatProvider() {
    _buddyInterruptSub = _service.buddyLiveInterruptedStream.listen((_) {
      _buddyInterruptToken += 1;
      notifyListeners();
    });
  }

  /// Split the raw model output into German text + English translation.
  ChatEntry _parseReply(String raw) {
    final trimmed = raw.trim();

    final jsonReply = _parseReplyFromJson(trimmed);
    if (jsonReply != null) {
      return jsonReply;
    }

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

    // Keep markdown-rich replies intact (lists/tables/steps) instead of
    // forcing a line-based German/English split.
    if (_looksStructured(trimmed)) {
      return ChatEntry(text: trimmed, translated: null, isUser: false);
    }

    // The expected format is:
    // German sentence on first line
    // English translation on second line, optionally in parentheses.
    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
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

  ChatEntry? _parseReplyFromJson(String raw) {
    if (raw.isEmpty) return null;

    Map<String, dynamic>? asMap;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        asMap = decoded;
      }
    } catch (_) {
      // Try extracting a JSON object from markdown-wrapped/mixed responses.
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(raw);
      if (match == null) return null;
      final candidate = match.group(0);
      if (candidate == null) return null;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) {
          asMap = decoded;
        }
      } catch (_) {
        return null;
      }
    }

    if (asMap == null) return null;

    String pickFirstNonEmpty(List<String> keys) {
      for (final key in keys) {
        final value = asMap![key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return '';
    }

    final german = pickFirstNonEmpty([
      'german',
      'germanText',
      'response',
      'reply',
      'text',
      'message',
      'shopkeeperResponse',
      'spokenResponse',
    ]);

    final english = pickFirstNonEmpty([
      'english',
      'englishText',
      'translation',
      'translated',
      'englishTranslation',
    ]);

    if (german.isEmpty && english.isEmpty) return null;

    return ChatEntry(
      text: german.isEmpty ? english : german,
      translated: english,
      isUser: false,
    );
  }

  bool _wantsStructuredOutput(String userText) {
    final lower = userText.toLowerCase();
    const triggers = [
      'table',
      'tables',
      'list',
      'lists',
      'comparison',
      'compare',
      'steps',
      'vocabulary',
      'chart',
      'tabelle',
      'tabellen',
      'liste',
      'listen',
      'vergleich',
      'schritte',
      'wortschatz',
    ];
    return triggers.any(lower.contains);
  }

  bool _looksStructured(String aiText) {
    final text = aiText.trim();
    if (text.isEmpty) return false;

    if (RegExp(r'^\s*\[German\]', caseSensitive: false).hasMatch(text)) {
      return true;
    }

    final tableSeparator = RegExp(
      r'^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$',
      multiLine: false,
    );
    final lines = text.split('\n');
    for (var i = 0; i < lines.length - 1; i++) {
      final header = lines[i].trim();
      final separator = lines[i + 1].trim();
      if (header.contains('|') && tableSeparator.hasMatch(separator)) {
        return true;
      }
    }

    final hasUnorderedList = RegExp(
      r'^\s*[-*+]\s+.+$',
      multiLine: true,
    ).hasMatch(text);
    final hasOrderedList = RegExp(
      r'^\s*\d+[.)]\s+.+$',
      multiLine: true,
    ).hasMatch(text);

    return hasUnorderedList || hasOrderedList;
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
      final wantsStructured = _wantsStructuredOutput(text);
      var reply = await _service.askBuddy(text);

      if (wantsStructured && !_looksStructured(reply.text)) {
        final fallbackText = await _service.ask(text);
        if (fallbackText.trim().isNotEmpty) {
          reply = BuddyDialogResponse(
            text: fallbackText,
            audioBytes: reply.audioBytes,
            audioMimeType: reply.audioMimeType,
          );
        }
      }

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

  Future<void> prepareBuddyLiveSession({bool startConversation = false}) async {
    _isBuddyPreparing = false;
    _isBuddyLiveReady = false;
    _buddyLiveError = null;
    notifyListeners();
  }

  Future<void> startBuddyVoiceTurn() async {
    addMessage(
      ChatEntry(
        text: 'Live voice mode is disabled for now. Please type your message.',
        isUser: false,
      ),
    );
  }

  Future<void> stopBuddyVoiceTurn() async {
    _isBuddyVoiceActive = false;
    _isBuddyVoiceStopping = false;
    notifyListeners();
  }

  Future<void> cancelBuddyVoiceTurn() async {
    _isBuddyVoiceActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _buddyInterruptSub?.cancel();
    _buddyAudioRecorder.dispose();
    super.dispose();
  }
}
