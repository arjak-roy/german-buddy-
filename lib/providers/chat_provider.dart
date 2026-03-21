import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/models/chat_entry.dart';
import '../data/services/gemini_service.dart';

part 'chat_provider.g.dart';

class ChatState {
  final List<ChatEntry> messages;
  final Uint8List? latestAiAudioBytes;
  final String? latestAiAudioMimeType;
  final int latestAiAudioToken;

  const ChatState({
    required this.messages,
    this.latestAiAudioBytes,
    this.latestAiAudioMimeType,
    this.latestAiAudioToken = 0,
  });

  ChatState copyWith({
    List<ChatEntry>? messages,
    Uint8List? latestAiAudioBytes,
    String? latestAiAudioMimeType,
    int? latestAiAudioToken,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      latestAiAudioBytes: latestAiAudioBytes ?? this.latestAiAudioBytes,
      latestAiAudioMimeType: latestAiAudioMimeType ?? this.latestAiAudioMimeType,
      latestAiAudioToken: latestAiAudioToken ?? this.latestAiAudioToken,
    );
  }
}

@riverpod
class ChatNotifier extends _$ChatNotifier {
  late final GeminiService _service;

  @override
  AsyncValue<ChatState> build() {
    _service = GeminiService();
    return const AsyncData(ChatState(messages: []));
  }

  void addMessage(ChatEntry entry) {
    if (state is AsyncData) {
      final current = state.value!;
      state = AsyncData(current.copyWith(messages: [...current.messages, entry]));
    }
  }

  void clear() {
    state = const AsyncData(ChatState(messages: []));
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final currentState = state.value ?? const ChatState(messages: []);
    final updatedMessages = [...currentState.messages, ChatEntry(text: text, isUser: true)];
    
    state = const AsyncLoading();
    
    // We update to loading but maintain data, Riverpod 2 approach: AsyncLoading().copyWithPrevious(...)
    state = AsyncValue.data(currentState.copyWith(messages: updatedMessages)).copyWithPrevious(const AsyncLoading());

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

      final parsed = _parseReply(reply.text);

      Uint8List? newAudioBytes = currentState.latestAiAudioBytes;
      String? newMimeType = currentState.latestAiAudioMimeType;
      int newToken = currentState.latestAiAudioToken;

      if (reply.audioBytes != null && reply.audioBytes!.isNotEmpty) {
        newAudioBytes = reply.audioBytes;
        newMimeType = reply.audioMimeType;
        newToken += 1;
      }
      
      final finalMessages = [...updatedMessages, parsed];

      state = AsyncData(ChatState(
        messages: finalMessages,
        latestAiAudioBytes: newAudioBytes,
        latestAiAudioMimeType: newMimeType,
        latestAiAudioToken: newToken,
      ));
    } catch (e) {
      state = AsyncData(currentState.copyWith(
        messages: [...updatedMessages, ChatEntry(text: 'Fehler: $e', isUser: false)]
      ));
    }
  }

  ChatEntry _parseReply(String raw) {
    final trimmed = raw.trim();

    final jsonReply = _parseReplyFromJson(trimmed);
    if (jsonReply != null) {
      return jsonReply;
    }

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

    if (_looksStructured(trimmed)) {
      return ChatEntry(text: trimmed, translated: null, isUser: false);
    }

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
      'table', 'tables', 'list', 'lists', 'comparison', 'compare',
      'steps', 'vocabulary', 'chart', 'tabelle', 'tabellen',
      'liste', 'listen', 'vergleich', 'schritte', 'wortschatz',
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

    final hasUnorderedList = RegExp(r'^\s*[-*+]\s+.+$', multiLine: true).hasMatch(text);
    final hasOrderedList = RegExp(r'^\s*\d+[.)]\s+.+$', multiLine: true).hasMatch(text);

    return hasUnorderedList || hasOrderedList;
  }
}
