import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/speech_provider.dart';
import '../../features/buddy/widgets/buddy_mic_button.dart';

class SpeechActionBar extends StatefulWidget {
  final Future<void> Function(String text) onSubmitted;
  final String keyboardLabel;
  final Future<void> Function()? onCustomVoiceStart;
  final Future<void> Function()? onCustomVoiceStop;
  final bool? isCustomVoiceActive;
  final double? customVoiceLevel;
  final String? customTranscript;

  const SpeechActionBar({
    required this.onSubmitted,
    this.keyboardLabel = 'Type your message',
    this.onCustomVoiceStart,
    this.onCustomVoiceStop,
    this.isCustomVoiceActive,
    this.customVoiceLevel,
    this.customTranscript,
    super.key,
  });

  @override
  State<SpeechActionBar> createState() => _SpeechActionBarState();
}

class _SpeechActionBarState extends State<SpeechActionBar> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SpeechProvider>().ensureInitialized();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SpeechProvider>(
      builder: (context, speech, _) {
        final usesCustomVoice =
            widget.onCustomVoiceStart != null && widget.onCustomVoiceStop != null;
        final isVoiceActive =
            widget.isCustomVoiceActive ?? (usesCustomVoice ? false : speech.isListening);
        final voiceLevel = widget.customVoiceLevel ?? speech.voiceLevel;
        final transcript = (widget.customTranscript ?? speech.currentTranscript).trim();

        final isGerman = speech.isGerman;
        final shadowA = isGerman
            ? const Color(0xFF000000)
            : const Color(0xFF012169);
        final shadowB = isGerman
            ? const Color(0xFFDD0000)
            : const Color(0xFFC8102E);
        final borderColor = isGerman
            ? const Color(0xFFFFCE00)
            : const Color(0xFFEEEEEE);

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kDebugMode && speech.showDebugPanel) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.72),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.25,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STT | ready: ${speech.speechReady} | listening: ${speech.isListening} | lang: ${isGerman ? 'DE' : 'EN'}',
                        ),
                        Text('status: ${speech.lastStatus}'),
                        Text('locale: ${speech.activeLocaleId}'),
                        Text(
                          'confidence: ${speech.lastConfidence != null ? (speech.lastConfidence! * 100).toStringAsFixed(0) + '%' : 'n/a'} | voice: ${(speech.voiceLevel * 100).toStringAsFixed(0)}%',
                        ),
                        Text(
                          'heard: ${speech.lastRecognizedText.isEmpty ? '-' : speech.lastRecognizedText}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (speech.lastError != null)
                          Text(
                            'error: ${speech.lastError}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 44),
                  BuddyMicButton(
                    isRecording: isVoiceActive,
                    voiceLevel: voiceLevel,
                    onTap: () =>
                      usesCustomVoice ? _toggleCustomVoice() : _toggleListening(context),
                    onLongPressStart: () =>
                      usesCustomVoice ? _startCustomVoice() : _startListening(context),
                    onLongPressEnd: () => usesCustomVoice
                      ? _stopCustomVoice()
                      : _stopListeningAndSubmit(context),
                    onLongPressCancel: () => usesCustomVoice
                      ? _stopCustomVoice()
                      : _stopListeningAndSubmit(context),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: speech.toggleLanguage,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutQuad,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context).colorScheme.surface,
                            border: Border.all(color: borderColor, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: shadowA.withOpacity(0.35),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                              BoxShadow(
                                color: shadowB.withOpacity(0.35),
                                blurRadius: 12,
                                spreadRadius: 0.5,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.language,
                                size: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isGerman ? 'DE' : 'EN',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      IconButton.filledTonal(
                        onPressed: () => _showInputSheet(context),
                        icon: const Icon(Icons.keyboard_alt_outlined, size: 20),
                        tooltip: 'Keyboard',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(10),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isVoiceActive && transcript.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.66),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: speech.hasConfirmedSentence
                          ? Colors.greenAccent.withOpacity(0.7)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        speech.hasConfirmedSentence
                            ? Icons.verified_outlined
                            : Icons.hearing_outlined,
                        color: speech.hasConfirmedSentence
                            ? Colors.greenAccent
                            : Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          transcript,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _startCustomVoice() async {
    final start = widget.onCustomVoiceStart;
    if (start == null) return;
    await start();
  }

  Future<void> _stopCustomVoice() async {
    final stop = widget.onCustomVoiceStop;
    if (stop == null) return;
    await stop();
  }

  Future<void> _toggleCustomVoice() async {
    final active = widget.isCustomVoiceActive ?? false;
    if (active) {
      await _stopCustomVoice();
      return;
    }
    await _startCustomVoice();
  }

  Future<void> _startListening(BuildContext context) async {
    final speech = context.read<SpeechProvider>();
    await speech.ensureInitialized();

    if (!speech.speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition is not available.')),
      );
      return;
    }
    final started = await speech.startListening();
    if (!context.mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            speech.lastError ??
                'Could not start speech recognition. Check microphone permission.',
          ),
        ),
      );
    }
  }

  Future<void> _toggleListening(BuildContext context) async {
    final speech = context.read<SpeechProvider>();
    if (speech.isListening) {
      await _stopListeningAndSubmit(context);
      return;
    }

    // If recognition auto-stopped and words are still present, submit them
    // before starting a new session so valid transcripts are not lost.
    final pending = speech.currentTranscript.trim();
    if (pending.isNotEmpty) {
      await widget.onSubmitted(pending);
      if (!mounted) return;
      speech.clearTranscript();
      return;
    }

    await _startListening(context);
  }

  Future<void> _stopListeningAndSubmit(BuildContext context) async {
    final speech = context.read<SpeechProvider>();
    final preStopText = speech.currentTranscript.trim();
    final preStopHeardText = speech.lastRecognizedText.trim();

    final captured = await speech.stopListeningAndCollect();
    if (!mounted) return;

    final postStopText = captured?.text.trim() ?? '';
    final fallbackText = speech.currentTranscript.trim();
    final heardFallbackText = speech.lastRecognizedText.trim();
    final text = postStopText.isNotEmpty
        ? postStopText
        : (preStopText.isNotEmpty
              ? preStopText
              : (fallbackText.isNotEmpty
                    ? fallbackText
                    : (preStopHeardText.isNotEmpty
                          ? preStopHeardText
                          : heardFallbackText)));

    if (text.isEmpty) return;
    await widget.onSubmitted(text);
    if (!mounted) return;
    speech.clearTranscript();
  }

  void _showInputSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: widget.keyboardLabel,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _submit(context, controller),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _submit(context, controller),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    await widget.onSubmitted(text);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }
}
