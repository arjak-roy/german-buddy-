import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:wunderbarai/providers/chat_provider.dart';
import 'dart:typed_data';
import 'dart:async';

import '../widgets/chat_bubble.dart';
import '../widgets/buddy_app_bar.dart';
import '../widgets/bottom_mic.dart';
import '../../../../providers/app_providers.dart';

/// Represents the interactive conversation screen with Buddy. A hero
/// animation is used on the mic button so pushing this route from the
/// home page appears seamless.
class BuddyScreen extends ConsumerStatefulWidget {
  /// When used as a tab page inside the home scaffold we don't want to
  /// create another [Scaffold] (nested scaffolds cause layout issues). In
  /// that case set [embedded] to true and only the inner content is
  /// returned. When pushed via [Navigator] the default false value will
  /// provide the full dedicated page scaffold with its own app bar and mic
  /// button.
  final bool embedded;

  const BuddyScreen({super.key, this.embedded = false});

  @override
  ConsumerState<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends ConsumerState<BuddyScreen> {
  late final ScrollController _scrollController;
  late final FlutterTts _tts;
  late final AudioPlayer _nativeAudioPlayer;
  int _lastCount = -1;
  int _lastPlayedAudioToken = 0;
  bool _didInitialBottomJump = false;
  String? _lastSpokenAiText;
  int _lastInterruptToken = 0;

  void _scrollToBottom({required bool animate}) {
    if (!_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuad,
      );
      return;
    }
    _scrollController.jumpTo(target);
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _nativeAudioPlayer = AudioPlayer();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE'); // fallback; overridden by _applyVoiceSettings
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyVoiceSettings());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatProviderNotifier).prepareBuddyLiveSession();
    });
  }

  Future<void> _applyVoiceSettings() async {
    if (!mounted) return;
    final vp = ref.read(voiceProviderNotifier);
    await vp.loadVoices();
    if (!mounted) return;
    await vp.applyTo(_tts);
  }

  @override
  void dispose() {
    unawaited(ref.read(chatProviderNotifier).cancelBuddyVoiceTurn());
    _tts.stop();
    _nativeAudioPlayer.stop();
    _nativeAudioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playLatestAiMessage(List entries, ChatProvider chat) async {
    if (entries.isEmpty) return;
    final latest = entries.last;
    if (latest.isUser) return;

    final audioToken = chat.latestAiAudioToken;
    final audioBytes = chat.latestAiAudioBytes;
    final audioMime = chat.latestAiAudioMimeType ?? '';
    var playedNativeAudio = false;
    if (audioToken > _lastPlayedAudioToken &&
        audioBytes != null &&
        audioBytes.isNotEmpty) {
      _lastPlayedAudioToken = audioToken;
      try {
        await _tts.stop();
        await _nativeAudioPlayer.stop();
        final playable = audioMime.contains('audio/pcm')
            ? _wrapPcm16LeToWav(audioBytes)
            : audioBytes;
        await _nativeAudioPlayer.play(BytesSource(playable));
        playedNativeAudio = true;
      } catch (_) {
        // Fall back to TTS below when model audio playback fails.
      }
    }

    final text = (latest.text).trim();
    if (text.isEmpty || text == _lastSpokenAiText) return;

    _lastSpokenAiText = text;

    // Fallback speech path when no native model audio is available.
    if (!playedNativeAudio) {
      try {
        await _tts.stop();
        await _tts.speak(text);
      } catch (_) {
        // Ignore TTS runtime errors so chat flow remains uninterrupted.
      }
    }
  }

  Uint8List _wrapPcm16LeToWav(Uint8List pcmData, {int sampleRate = 24000}) {
    const channels = 1;
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataSize = pcmData.length;
    final totalSize = 44 + dataSize;

    final out = BytesBuilder(copy: false);
    void wAscii(String s) => out.add(Uint8List.fromList(s.codeUnits));
    void w16(int v) => out.add(Uint8List.fromList([v & 0xFF, (v >> 8) & 0xFF]));
    void w32(int v) => out.add(
      Uint8List.fromList([
        v & 0xFF,
        (v >> 8) & 0xFF,
        (v >> 16) & 0xFF,
        (v >> 24) & 0xFF,
      ]),
    );

    wAscii('RIFF');
    w32(totalSize - 8);
    wAscii('WAVE');
    wAscii('fmt ');
    w32(16);
    w16(1);
    w16(channels);
    w32(sampleRate);
    w32(byteRate);
    w16(blockAlign);
    w16(bitsPerSample);
    wAscii('data');
    w32(dataSize);
    out.add(pcmData);

    return out.takeBytes();
  }

  Widget _buildContent() {
    final chat = ref.watch(chatProviderNotifier);
    final entries = chat.messages;

    if (chat.buddyInterruptToken > _lastInterruptToken) {
      _lastInterruptToken = chat.buddyInterruptToken;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _nativeAudioPlayer.stop();
        await _tts.stop();
      });
    }

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
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
        _playLatestAiMessage(entries, chat);
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
          const Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(child: BottomMic()),
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
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Container(color: Colors.grey.shade50, child: _buildContent());
    }

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _tts.stop();
          _nativeAudioPlayer.stop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: const BuddyAppBar(),
        body: _buildContent(),
        bottomNavigationBar: const BottomMic(),
      ),
    );
  }
}
