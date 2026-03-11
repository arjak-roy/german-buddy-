import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wunderbarai/providers/chat_provider.dart';

import '../widgets/chat_bubble.dart';
import '../widgets/buddy_app_bar.dart';
import '../widgets/bottom_mic.dart';
import 'package:provider/provider.dart';

/// Represents the interactive conversation screen with Buddy. A hero
/// animation is used on the mic button so pushing this route from the
/// home page appears seamless.
class BuddyScreen extends StatefulWidget {
  /// When used as a tab page inside the home scaffold we don't want to
  /// create another [Scaffold] (nested scaffolds cause layout issues). In
  /// that case set [embedded] to true and only the inner content is
  /// returned. When pushed via [Navigator] the default false value will
  /// provide the full dedicated page scaffold with its own app bar and mic
  /// button.
  final bool embedded;

  const BuddyScreen({super.key, this.embedded = false});

  @override
  State<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends State<BuddyScreen> {
  late final ScrollController _scrollController;
  late final FlutterTts _tts;
  int _lastCount = -1;
  bool _didInitialBottomJump = false;
  String? _lastSpokenAiText;

  void _scrollToBottom({required bool animate}) {
    if (!_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      return;
    }
    _scrollController.jumpTo(target);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE');
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speakLatestAiMessage(List entries) async {
    if (entries.isEmpty) return;
    final latest = entries.last;
    if (latest.isUser) return;

    final text = (latest.text).trim();
    if (text.isEmpty || text == _lastSpokenAiText) return;

    _lastSpokenAiText = text;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Ignore TTS runtime errors so chat flow remains uninterrupted.
    }
  }

  Widget _buildContent() {
    // obtain messages from provider
    return Consumer<ChatProvider>(builder: (context, chat, _) {
      final entries = chat.messages;

      // Establish baseline on first render so historical messages are not
      // spoken when opening/reopening the page.
      if (_lastCount == -1) {
        _lastCount = entries.length;
      }

      if (!_didInitialBottomJump && entries.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: false);
        });
        _didInitialBottomJump = true;
      }

      if (entries.isEmpty) {
        // show onboarding hint but keep mic accessible
        return Column(
          children: [
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Try saying "Hello buddy" in German',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            if (widget.embedded) const BottomMic(),
          ],
        );
      }

      // if new message added, scroll to bottom after frame
      if (entries.length > _lastCount) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animate: true);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _speakLatestAiMessage(entries);
        });

        _lastCount = entries.length;
      }

      if (widget.embedded) {
        // floating mic at bottom over the scrollable list
        return Stack(
          children: [
            SafeArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 118),
                itemCount: entries.length + (chat.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < entries.length) {
                    final e = entries[index];
                    return ChatMessage(
                      text: e.text,
                      translated: e.translated,
                      isUser: e.isUser,
                    );
                  }
                  // loading placeholder bubble
                  return const ChatMessage(
                    text: 'Buddy is thinking...',
                    isUser: false,
                  );
                },
              ),
            ),
                  Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(child: const BottomMic()),
            ),
          ],
        );
      }

      return Column(
        children: [
          Expanded(
            child: SafeArea(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final e = entries[index];
                  return ChatMessage(
                    text: e.text,
                    translated: e.translated,
                    isUser: e.isUser,
                  );
                },
              ),
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(
        color: Colors.grey.shade50,
        child: _buildContent(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: const BuddyAppBar(),
      body: _buildContent(),
      bottomNavigationBar: const BottomMic(),
    );
  }
}
