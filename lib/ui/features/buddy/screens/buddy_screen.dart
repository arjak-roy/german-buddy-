import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

import '../../../../providers/chat_provider.dart';
import '../../../../data/repositories/live_session_repository.dart';
import '../../../../core/utils/audio_converter.dart';

import '../widgets/chat_bubble.dart';
import '../widgets/buddy_app_bar.dart';
import '../widgets/bottom_mic.dart';
import '../../../../providers/app_providers.dart';

class BuddyScreen extends ConsumerStatefulWidget {
  static FlutterTts? _staticTts;
  static Future<void> stopTtsIfActive() async {
    if (_staticTts != null) {
      try {
        await _staticTts!.stop();
      } catch (_) {}
    }
  }

  final bool embedded;

  const BuddyScreen({super.key, this.embedded = false});

  @override
  ConsumerState<BuddyScreen> createState() => _BuddyScreenState();
}

class _BuddyScreenState extends ConsumerState<BuddyScreen>
    with WidgetsBindingObserver {
  late final ScrollController _scrollController;
  late final FlutterTts _tts;
  late final AudioPlayer _nativeAudioPlayer;
  late final ValueNotifier<Brightness> _brightnessNotifier;
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
    WidgetsBinding.instance.addObserver(this);
    _brightnessNotifier = ValueNotifier(
      WidgetsBinding.instance.window.platformBrightness,
    );
    _scrollController = ScrollController();
    _nativeAudioPlayer = AudioPlayer();
    _tts = FlutterTts();
    BuddyScreen._staticTts = _tts;
    _tts.setLanguage('de-DE'); 
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyVoiceSettings());
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
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ref.read(liveSessionRepositoryProvider.notifier).cancelBuddyVoiceTurn());
    _tts.stop();
    _nativeAudioPlayer.stop();
    _nativeAudioPlayer.dispose();
    _scrollController.dispose();
    if (BuddyScreen._staticTts == _tts) {
      BuddyScreen._staticTts = null;
    }
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    _brightnessNotifier.value =
        WidgetsBinding.instance.window.platformBrightness;
  }

  Future<void> _playLatestAiMessage(List entries, ChatState chatState) async {
    if (entries.isEmpty) return;
    final latest = entries.last;
    if (latest.isUser) return;

    final audioToken = chatState.latestAiAudioToken;
    final audioBytes = chatState.latestAiAudioBytes;
    final audioMime = chatState.latestAiAudioMimeType ?? '';
    var playedNativeAudio = false;
    
    if (audioToken > _lastPlayedAudioToken &&
        audioBytes != null &&
        audioBytes.isNotEmpty) {
      _lastPlayedAudioToken = audioToken;
      try {
        await _tts.stop();
        await _nativeAudioPlayer.stop();
        final playable = audioMime.contains('audio/pcm')
            ? AudioConverter.wrapPcm16LeToWav(audioBytes)
            : audioBytes;
        await _nativeAudioPlayer.play(BytesSource(playable));
        playedNativeAudio = true;
      } catch (_) {
      }
    }

    final text = (latest.text).trim();
    if (text.isEmpty || text == _lastSpokenAiText) return;

    _lastSpokenAiText = text;

    if (!playedNativeAudio) {
      try {
        await _tts.stop();
        await _tts.speak(text);
      } catch (_) {
      }
    }
  }

  Widget _buildContent(bool isDark) {
    final chatAsync = ref.watch(chatNotifierProvider);
    final chatState = chatAsync.valueOrNull;
    final entries = chatState?.messages ?? [];
    final isLoading = chatAsync.isLoading;
    
    final liveSession = ref.watch(liveSessionRepositoryProvider);

    if (liveSession.isBuddyPreparing && !liveSession.isBuddyLiveReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
            const SizedBox(height: 12),
            Text(
              'Connecting Buddy Live...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (liveSession.buddyInterruptToken > _lastInterruptToken) {
      _lastInterruptToken = liveSession.buddyInterruptToken;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _nativeAudioPlayer.stop();
        await _tts.stop();
      });
    }

    if (_lastCount == -1) {
      _lastCount = entries.length;
    }

    if (!_didInitialBottomJump && entries.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: false);
      });
      _didInitialBottomJump = true;
    }

    if (entries.isEmpty && !isLoading) {
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

    if (entries.length > _lastCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animate: true);
      });

      if (chatState != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _playLatestAiMessage(entries, chatState);
        });
      }

      _lastCount = entries.length;
    }

    if (widget.embedded) {
      return Stack(
        children: [
          SafeArea(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 118),
              itemCount: entries.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < entries.length) {
                  final e = entries[index];
                  return ChatMessage(
                    text: e.text,
                    translated: e.translated,
                    isUser: e.isUser,
                    isDark: isDark,
                  );
                }
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
              itemCount: entries.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < entries.length) {
                  final e = entries[index];
                  return ChatMessage(
                    text: e.text,
                    translated: e.translated,
                    isUser: e.isUser,
                    isDark: isDark,
                  );
                }
                return const ChatMessage(
                  text: 'Buddy is thinking...',
                  isUser: false,
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
    final colorScheme = Theme.of(context).colorScheme;
    if (widget.embedded) {
      final isDark = _brightnessNotifier.value == Brightness.dark;
      return Container(
        color: colorScheme.background,
        child: _buildContent(isDark),
      );
    }

    return ValueListenableBuilder<Brightness>(
      valueListenable: _brightnessNotifier,
      builder: (context, brightness, _) {
        final isDark = brightness == Brightness.dark;
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) {
              _tts.stop();
              _nativeAudioPlayer.stop();
            }
          },
          child: Scaffold(
            backgroundColor: colorScheme.background,
            appBar: const BuddyAppBar(),
            body: _buildContent(isDark),
            bottomNavigationBar: const BottomMic(),
          ),
        );
      },
    );
  }
}
