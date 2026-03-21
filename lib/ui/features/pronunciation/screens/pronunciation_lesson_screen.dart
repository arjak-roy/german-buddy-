import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../data/models/pronunciation_analysis_report.dart';
import '../../../../providers/app_providers.dart';
import '../../buddy/widgets/buddy_mic_button.dart';
import '../models/pronunciation_item.dart';

class _SegmentTiming {
  final String label;
  final int startMs;
  final int endMs;

  _SegmentTiming({
    required this.label,
    required this.startMs,
    required this.endMs,
  });
}

class PronunciationLessonScreen extends ConsumerStatefulWidget {
  final PronunciationItem item;

  const PronunciationLessonScreen({required this.item, super.key});

  @override
  ConsumerState<PronunciationLessonScreen> createState() =>
      _PronunciationLessonScreenState();
}

class _PronunciationLessonScreenState
    extends ConsumerState<PronunciationLessonScreen> {
  static const _panelTitle = Color(0xFF0F172A);
  static const _panelBody = Color(0xFF334155);
  static const _panelMuted = Color(0xFF64748B);

  late final FlutterTts _tts;
  Timer? _segmentTimer;
  int _currentStep = 0;
  int _activeSegmentIndex = -1;
  double _speechRate = 0.45;
  bool _isPlaying = false;

  List<String> get _segments => widget.item.segments;
  List<_Viseme> get _visemes =>
      _segments.map((segment) => _visemeForSegment(segment)).toList();

  List<PronunciationPhonemeFeedback> _reportPhonemes() {
    final analysis = ref.read(pronunciationAnalysisProviderNotifier);
    return analysis.report?.phonemeBreakdown ?? [];
  }

  List<_SegmentTiming> _segmentTimings() {
    final phonemes = _reportPhonemes();

    // Heuristic baseline (segment-level) if server timing is not available.
    final segments = _segments;
    final fallbackTiming = <_SegmentTiming>[];
    if (segments.isNotEmpty) {
      final totalDuration = (500 + segments.length * 180).clamp(700, 2000);
      final perSegment = (totalDuration / segments.length).round();
      var current = 0;
      for (final segment in segments) {
        final start = current;
        final end = current + perSegment;
        current = end;
        fallbackTiming.add(
          _SegmentTiming(label: segment, startMs: start, endMs: end),
        );
      }
    }

    // 1) If server provides full phoneme timing, use hybrid best-effort integration
    final serverTiming = phonemes.where((p) => p.endMs > p.startMs).toList();

    if (serverTiming.isNotEmpty) {
      final sorted = List<PronunciationPhonemeFeedback>.from(serverTiming)
        ..sort((a, b) => a.startMs.compareTo(b.startMs));

      // If we can map to segments exactly, we trust server heavily but blend with heuristic.
      if (sorted.length == segments.length) {
        const serverWeight = 0.75;
        const heuristicWeight = 0.25;

        // Convert segment-based fallback for translation
        final fallbackByIndex = fallbackTiming;
        final List<_SegmentTiming> hybrid = [];

        for (var i = 0; i < sorted.length; i++) {
          final server = sorted[i];
          final heur = fallbackByIndex[i];

          final blendedStart =
              (server.startMs * serverWeight + heur.startMs * heuristicWeight)
                  .round();
          final blendedEnd =
              (server.endMs * serverWeight + heur.endMs * heuristicWeight)
                  .round();

          hybrid.add(
            _SegmentTiming(
              label: segments[i],
              startMs: blendedStart,
              endMs: blendedEnd > blendedStart
                  ? blendedEnd
                  : blendedStart + 100,
            ),
          );
        }

        return hybrid;
      }

      // If server count doesn't match segments, but timing exists, prefer server at phoneme level.
      return sorted
          .map(
            (p) => _SegmentTiming(
              label: p.phoneme,
              startMs: p.startMs,
              endMs: p.endMs,
            ),
          )
          .toList();
    }

    // 2) fallback
    return fallbackTiming;
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE'); // fallback; overridden by _applyVoiceSettings
    _tts.setPitch(1.0);
    _tts.setSpeechRate(_speechRate);
    _tts.awaitSpeakCompletion(false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyVoiceSettings());

    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
    });
    _tts.setCompletionHandler(_stopPlaybackUi);
    _tts.setCancelHandler(_stopPlaybackUi);
    _tts.setErrorHandler((_) => _stopPlaybackUi());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recorder = ref.read(pronunciationRecordingProviderNotifier);
      final analysis = ref.read(pronunciationAnalysisProviderNotifier);
      analysis.selectWord(widget.item);
      recorder.initializePlayback();
      recorder.prepareForWord(widget.item.german);
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
    _segmentTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _playGermanWord() async {
    setState(() {
      _currentStep = 0;
    });
    await _playWithSegments();
  }

  Future<void> _playPhoneticGuide() async {
    setState(() {
      _currentStep = 1;
    });
    await _playWithSegments();
  }

  Future<void> _playWithSegments() async {
    _segmentTimer?.cancel();

    final timings = _segmentTimings();
    if (timings.isNotEmpty) {
      setState(() => _activeSegmentIndex = 0);

      _segmentTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        final elapsed = timer.tick * 50;
        final newActive = timings.indexWhere(
          (s) => elapsed >= s.startMs && elapsed <= s.endMs,
        );

        if (newActive == -1 && elapsed > timings.last.endMs) {
          timer.cancel();
          return;
        }

        if (newActive != -1) {
          setState(() {
            _activeSegmentIndex = newActive;
          });
        }
      });

      await _tts.setSpeechRate(_speechRate);
      await _tts.stop();
      await _tts.speak(widget.item.german);
      return;
    }

    // very fallback: show segments without timing
    setState(() {
      _activeSegmentIndex = 0;
    });
    final segmentCount = _segments.length;
    final perSegmentMs = (950 - (_speechRate * 700)).clamp(250, 900).toInt();
    var tick = 0;

    _segmentTimer = Timer.periodic(Duration(milliseconds: perSegmentMs), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      tick += 1;
      if (tick >= segmentCount) {
        timer.cancel();
        return;
      }
      setState(() {
        _activeSegmentIndex = tick;
      });
    });

    await _tts.setSpeechRate(_speechRate);
    await _tts.stop();
    await _tts.speak(widget.item.german);
  }

  void _stopPlaybackUi() {
    _segmentTimer?.cancel();
    _segmentTimer = null;
    if (!mounted) return;
    setState(() {
      _isPlaying = false;
      _activeSegmentIndex = -1;
    });
  }

  Future<void> _startRecording(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    final started = await recorder.startRecording();
    if (!mounted) return;
    if (!started && recorder.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(recorder.error!)));
      return;
    }

    if (started) {
      setState(() {
        _currentStep = 2;
      });
    }
  }

  Future<void> _stopRecording(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    final stopped = await recorder.stopRecording();
    if (!mounted) return;
    if (!stopped && recorder.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(recorder.error!)));
      return;
    }

    if (stopped) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recording captured. Confirm to continue to analysis.'),
        ),
      );
    }
  }

  Future<void> _toggleRecordedAudioPlayback(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    final played = await recorder.togglePlayback();
    if (!mounted) return;
    if (!played && recorder.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(recorder.error!)));
    }
  }

  Future<void> _confirmAndAnalyze(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    final analysis = ref.read(pronunciationAnalysisProviderNotifier);
    final path = recorder.recordedFilePath;
    if (path == null) return;

    setState(() {
      _currentStep = 3;
    });

    final success = await analysis.analyzeRecording(
      item: widget.item,
      filePath: path,
    );
    if (!mounted) return;

    if (!success && analysis.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(analysis.error!)));
    }
  }

  Future<void> _recordAgain(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    await recorder.clearRecording();
    if (!mounted) return;
    setState(() {
      _currentStep = 2;
    });
  }

  Future<void> _retryWord(BuildContext context) async {
    final recorder = ref.read(pronunciationRecordingProviderNotifier);
    final analysis = ref.read(pronunciationAnalysisProviderNotifier);
    await recorder.clearRecording();
    analysis.clearTransientState();
    if (!mounted) return;
    setState(() {
      _activeSegmentIndex = -1;
      _currentStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recorder = ref.watch(pronunciationRecordingProviderNotifier);
    final analysis = ref.watch(pronunciationAnalysisProviderNotifier);

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.german)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: _AnimatedLips(
                        isPlaying: _isPlaying,
                        activeIndex: _activeSegmentIndex,
                        visemes: _visemes,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.item.german,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.english,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF0369A1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TagChip(label: widget.item.phonetic),
                        _TagChip(label: widget.item.stars),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Stepper(
                currentStep: _currentStep,
                onStepTapped: (step) {
                  setState(() {
                    _currentStep = step;
                  });
                },
                physics: const ClampingScrollPhysics(),
                controlsBuilder: (context, details) => const SizedBox.shrink(),
                steps: [
                  Step(
                    title: const Text('Play German Word'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FilledButton.icon(
                          onPressed: _playGermanWord,
                          icon: Icon(
                            _isPlaying ? Icons.equalizer : Icons.play_arrow,
                          ),
                          label: Text(
                            _isPlaying ? 'Playing...' : 'Play Native Audio',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Speed: ${_speechRate.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _panelTitle,
                          ),
                        ),
                        Slider(
                          value: _speechRate,
                          min: 0.25,
                          max: 0.7,
                          divisions: 9,
                          label: _speechRate.toStringAsFixed(2),
                          onChanged: (value) {
                            setState(() {
                              _speechRate = value;
                            });
                          },
                        ),
                        if (analysis.report != null) ...[
                          const SizedBox(height: 14),
                          _RetryHintCard(report: analysis.report!),
                        ],
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('German Phonetics'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _playPhoneticGuide,
                          icon: const Icon(Icons.graphic_eq_rounded),
                          label: const Text('Play Phonetic Guide'),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'The highlighted segment shows what is playing now.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final timings = _segmentTimings();
                            final chunks = timings.isNotEmpty
                                ? timings.map((t) => t.label).toList()
                                : _segments;

                            return Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: List<Widget>.generate(chunks.length, (
                                index,
                              ) {
                                final active =
                                    _isPlaying && index == _activeSegmentIndex;
                                final passed =
                                    _isPlaying && index < _activeSegmentIndex;
                                final background = active
                                    ? const Color(0xFF16A34A)
                                    : (passed
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFFE2E8F0));
                                final foreground = active || passed
                                    ? Colors.white
                                    : const Color(0xFF334155);

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: background,
                                    borderRadius: BorderRadius.circular(999),
                                    boxShadow: active
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x3316A34A),
                                              blurRadius: 14,
                                              offset: Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    chunks[index],
                                    style: TextStyle(
                                      color: foreground,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      fontFeatures: const [],
                                    ),
                                  ),
                                );
                              }),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Audio Record'),
                    isActive: _currentStep >= 2,
                    state: recorder.hasRecording
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Press and hold to record your pronunciation. Recording stops automatically after 5 seconds.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _panelBody,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            children: [
                              _RecordingWaveform(
                                samples: recorder.waveformSamples,
                                progress: recorder.progress,
                                isRecording: recorder.isRecording,
                                isPlayable: recorder.hasRecording,
                                isPlayingBack: recorder.isPlayingBack,
                                onTap: recorder.hasRecording
                                    ? () =>
                                          _toggleRecordedAudioPlayback(context)
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _RecorderBadge(
                                    icon: recorder.isRecording
                                        ? Icons.fiber_manual_record_rounded
                                        : Icons.timer_outlined,
                                    label:
                                        '${recorder.recordingDuration.inMilliseconds / 1000}'
                                            .split('.')
                                            .first
                                            .padLeft(2, '0') +
                                        ':${((recorder.recordingDuration.inMilliseconds % 1000) / 10).floor().toString().padLeft(2, '0')}',
                                    color: recorder.isRecording
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF0F172A),
                                  ),
                                  _RecorderBadge(
                                    icon: Icons.hourglass_bottom_rounded,
                                    label: '5s max',
                                    color: const Color(0xFF0369A1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: BuddyMicButton(
                                  isRecording: recorder.isRecording,
                                  voiceLevel: recorder.waveformSamples.isEmpty
                                      ? 0.0
                                      : recorder.waveformSamples.last,
                                  onLongPressStart: () =>
                                      _startRecording(context),
                                  onLongPressEnd: () => _stopRecording(context),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                recorder.isRecording
                                    ? 'Recording... keep holding or wait for auto-stop.'
                                    : (recorder.isPlayingBack
                                          ? 'Playing your recorded pronunciation.'
                                          : (recorder.hasRecording
                                                ? 'Recording saved and ready for analysis.'
                                                : 'Hold the mic and pronounce ${widget.item.german}.')),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _panelMuted,
                                ),
                              ),
                              if (recorder.hasRecording &&
                                  !recorder.isRecording) ...[
                                const SizedBox(height: 14),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: analysis.isLoading
                                          ? null
                                          : () => _confirmAndAnalyze(context),
                                      icon: const Icon(
                                        Icons.check_circle_outline,
                                      ),
                                      label: Text(
                                        analysis.isLoading
                                            ? 'Analyzing...'
                                            : 'Confirm & Analyze',
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: analysis.isLoading
                                          ? null
                                          : () => _recordAgain(context),
                                      icon: const Icon(
                                        Icons.restart_alt_rounded,
                                      ),
                                      label: const Text('Record Again'),
                                    ),
                                  ],
                                ),
                              ],
                              if (recorder.hasRecording) ...[
                                const SizedBox(height: 8),
                                Text(
                                  recorder.isPlayingBack
                                      ? 'Tap the waveform to stop playback.'
                                      : 'Tap the waveform to play your recording once.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF0369A1),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              if (recorder.recordedFilePath != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  recorder.recordedFilePath!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: _panelMuted,
                                  ),
                                ),
                              ],
                              if (recorder.error != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  recorder.error!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Analysis'),
                    isActive: _currentStep >= 3,
                    state: analysis.hasReport
                        ? StepState.complete
                        : (recorder.hasRecording
                              ? StepState.indexed
                              : StepState.disabled),
                    content: _AnalysisStepContent(
                      isLoading: analysis.isLoading,
                      error: analysis.error,
                      hasRecording: recorder.hasRecording,
                      report: analysis.report,
                      onRetryWord: () => _retryWord(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Viseme { neutral, openA, rounded, spread, consonant, tight }

_Viseme _visemeForSegment(String segment) {
  final normalized = segment.toLowerCase().replaceAll(
    RegExp(r'[^a-zA-Zäöüß]'),
    '',
  );
  if (normalized.isEmpty) return _Viseme.neutral;

  if (normalized.contains('sch') ||
      normalized.contains('ch') ||
      normalized.contains('ts') ||
      normalized.contains('tz')) {
    return _Viseme.consonant;
  }

  if (normalized.contains('oo') ||
      normalized.contains('oh') ||
      normalized.contains('ou') ||
      normalized.contains('u') ||
      normalized.contains('o') ||
      normalized.contains('ö') ||
      normalized.contains('ü')) {
    return _Viseme.rounded;
  }

  if (normalized.contains('ee') ||
      normalized.contains('eh') ||
      normalized.contains('ie') ||
      normalized.contains('i') ||
      normalized.contains('e') ||
      normalized.contains('ä')) {
    return _Viseme.spread;
  }

  if (normalized.contains('a')) {
    return _Viseme.openA;
  }

  if (normalized.startsWith('f') ||
      normalized.startsWith('v') ||
      normalized.startsWith('w') ||
      normalized.startsWith('m') ||
      normalized.startsWith('b') ||
      normalized.startsWith('p')) {
    return _Viseme.tight;
  }

  return _Viseme.consonant;
}

class _AnimatedLips extends StatelessWidget {
  final bool isPlaying;
  final int activeIndex;
  final List<_Viseme> visemes;

  const _AnimatedLips({
    required this.isPlaying,
    required this.activeIndex,
    required this.visemes,
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = activeIndex.clamp(
      0,
      visemes.isEmpty ? 0 : visemes.length - 1,
    );
    final viseme = (!isPlaying || visemes.isEmpty || activeIndex < 0)
        ? _Viseme.neutral
        : visemes[safeIndex];

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutQuad,
      tween: Tween<double>(begin: 1.0, end: isPlaying ? 1.04 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutQuad,
        width: 176,
        height: 120,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF1F2), Color(0xFFFFE4E6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFFDA4AF)),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFFFB7185,
              ).withOpacity(isPlaying ? 0.22 : 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(left: 24, top: 44, child: _CheekGlow(active: isPlaying)),
            Positioned(
              right: 24,
              top: 44,
              child: _CheekGlow(active: isPlaying),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _LipsPainter(viseme: viseme, isPlaying: isPlaying),
              ),
            ),
            const Positioned(
              right: 10,
              top: 8,
              child: Icon(
                Icons.record_voice_over_rounded,
                size: 14,
                color: Color(0xFFE11D48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheekGlow extends StatelessWidget {
  final bool active;

  const _CheekGlow({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: active ? 22 : 18,
      height: active ? 14 : 12,
      decoration: BoxDecoration(
        color: const Color(0xFFFB7185).withOpacity(active ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LipsPainter extends CustomPainter {
  final _Viseme viseme;
  final bool isPlaying;

  const _LipsPainter({required this.viseme, required this.isPlaying});

  @override
  void paint(Canvas canvas, Size size) {
    final pose = _poseForViseme(viseme);
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final lipWidth = size.width * pose.widthFactor;
    final opening = size.height * pose.openFactor;
    final cornerLift = size.height * pose.cornerLift;

    final leftCorner = Offset(
      center.dx - (lipWidth / 2),
      center.dy + cornerLift,
    );
    final rightCorner = Offset(
      center.dx + (lipWidth / 2),
      center.dy + cornerLift,
    );
    final topPeak = Offset(
      center.dx,
      center.dy - opening - (size.height * 0.07),
    );
    final bottomDip = Offset(
      center.dx,
      center.dy + opening + (size.height * 0.06),
    );

    final upperLip = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.23),
        topPeak.dy,
        center.dx,
        center.dy - (opening * 0.52),
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.23),
        topPeak.dy,
        rightCorner.dx,
        rightCorner.dy,
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.24),
        center.dy - (opening * 0.25),
        center.dx,
        center.dy - (opening * 0.12),
      )
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.24),
        center.dy - (opening * 0.25),
        leftCorner.dx,
        leftCorner.dy,
      )
      ..close();

    final lowerLip = Path()
      ..moveTo(leftCorner.dx, leftCorner.dy)
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.30),
        bottomDip.dy,
        center.dx,
        center.dy + (opening * 0.46),
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.30),
        bottomDip.dy,
        rightCorner.dx,
        rightCorner.dy,
      )
      ..quadraticBezierTo(
        center.dx + (lipWidth * 0.20),
        center.dy + (opening * 0.05),
        center.dx,
        center.dy + (opening * 0.02),
      )
      ..quadraticBezierTo(
        center.dx - (lipWidth * 0.20),
        center.dy + (opening * 0.05),
        leftCorner.dx,
        leftCorner.dy,
      )
      ..close();

    final lipOutline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF9F1239).withOpacity(isPlaying ? 0.88 : 0.72)
      ..strokeCap = StrokeCap.round;

    final upperFill = Paint()
      ..shader =
          LinearGradient(
            colors: [
              const Color(0xFFFB7185).withOpacity(isPlaying ? 0.95 : 0.78),
              const Color(0xFFE11D48).withOpacity(isPlaying ? 0.92 : 0.74),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: lipWidth,
              height: size.height * 0.24,
            ),
          );

    final lowerFill = Paint()
      ..shader =
          LinearGradient(
            colors: [
              const Color(0xFFFB7185).withOpacity(isPlaying ? 0.88 : 0.72),
              const Color(0xFFBE123C).withOpacity(isPlaying ? 0.86 : 0.68),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(
            Rect.fromCenter(
              center: center,
              width: lipWidth,
              height: size.height * 0.28,
            ),
          );

    canvas.drawPath(lowerLip, lowerFill);
    canvas.drawPath(upperLip, upperFill);
    canvas.drawPath(lowerLip, lipOutline);
    canvas.drawPath(upperLip, lipOutline);

    final mouthRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + (opening * 0.06)),
      width: lipWidth * pose.innerWidth,
      height: (opening * 1.32).clamp(4.0, size.height * 0.42),
    );

    final mouthCavity = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF1E1B4B).withOpacity(isPlaying ? 0.82 : 0.62);
    canvas.drawRRect(
      RRect.fromRectAndRadius(mouthRect, Radius.circular(mouthRect.height)),
      mouthCavity,
    );

    if (mouthRect.height > 10) {
      final teethRect = Rect.fromLTWH(
        mouthRect.left + 3,
        mouthRect.top + 2,
        mouthRect.width - 6,
        (mouthRect.height * 0.28).clamp(2.5, 6.0),
      );
      final teethPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFFF7ED).withOpacity(0.9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(teethRect, const Radius.circular(999)),
        teethPaint,
      );

      final tongueRect = Rect.fromCenter(
        center: Offset(
          mouthRect.center.dx,
          mouthRect.bottom - (mouthRect.height * 0.24),
        ),
        width: mouthRect.width * 0.58,
        height: mouthRect.height * 0.32,
      );
      final tonguePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFFB7185).withOpacity(0.44);
      canvas.drawRRect(
        RRect.fromRectAndRadius(tongueRect, Radius.circular(tongueRect.height)),
        tonguePaint,
      );
    }

    final gloss = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(isPlaying ? 0.26 : 0.18);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          center.dx - (lipWidth * 0.17),
          center.dy - (opening * 0.58),
        ),
        width: lipWidth * 0.24,
        height: 6,
      ),
      gloss,
    );
  }

  @override
  bool shouldRepaint(covariant _LipsPainter oldDelegate) {
    return oldDelegate.viseme != viseme || oldDelegate.isPlaying != isPlaying;
  }
}

class _LipPose {
  final double widthFactor;
  final double openFactor;
  final double cornerLift;
  final double innerWidth;

  const _LipPose({
    required this.widthFactor,
    required this.openFactor,
    required this.cornerLift,
    required this.innerWidth,
  });
}

_LipPose _poseForViseme(_Viseme viseme) {
  switch (viseme) {
    case _Viseme.openA:
      return const _LipPose(
        widthFactor: 0.38,
        openFactor: 0.19,
        cornerLift: 0.0,
        innerWidth: 0.78,
      );
    case _Viseme.rounded:
      return const _LipPose(
        widthFactor: 0.24,
        openFactor: 0.20,
        cornerLift: -0.01,
        innerWidth: 0.76,
      );
    case _Viseme.spread:
      return const _LipPose(
        widthFactor: 0.46,
        openFactor: 0.09,
        cornerLift: -0.015,
        innerWidth: 0.84,
      );
    case _Viseme.consonant:
      return const _LipPose(
        widthFactor: 0.34,
        openFactor: 0.10,
        cornerLift: -0.004,
        innerWidth: 0.8,
      );
    case _Viseme.tight:
      return const _LipPose(
        widthFactor: 0.30,
        openFactor: 0.07,
        cornerLift: 0.0,
        innerWidth: 0.75,
      );
    case _Viseme.neutral:
      return const _LipPose(
        widthFactor: 0.35,
        openFactor: 0.095,
        cornerLift: 0.0,
        innerWidth: 0.8,
      );
  }
}

class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _RecordingWaveform extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final bool isRecording;
  final bool isPlayable;
  final bool isPlayingBack;
  final VoidCallback? onTap;

  const _RecordingWaveform({
    required this.samples,
    required this.progress,
    required this.isRecording,
    required this.isPlayable,
    required this.isPlayingBack,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 96,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isPlayable
                ? Border.all(
                    color: isPlayingBack
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFBFDBFE),
                    width: 1.4,
                  )
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WaveformPainter(
                    samples: samples,
                    progress: progress,
                    isRecording: isRecording,
                  ),
                ),
              ),
              if (isPlayable)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Icon(
                    isPlayingBack
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: isPlayingBack
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF0369A1),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final bool isRecording;

  const _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.isRecording,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final baseline = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, centerY), Offset(size.width, centerY), baseline);

    final progressPaint = Paint()
      ..color = isRecording
          ? const Color(0xFF16A34A).withOpacity(0.16)
          : const Color(0xFF0EA5E9).withOpacity(0.12)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * progress.clamp(0.0, 1.0), size.height),
      progressPaint,
    );

    if (samples.isEmpty) {
      return;
    }

    final barWidth = size.width / (samples.length * 1.55);
    final gap = barWidth * 0.55;
    final totalWidth =
        (barWidth * samples.length) + (gap * (samples.length - 1));
    var startX = (size.width - totalWidth) / 2;

    final barPaint = Paint()
      ..color = isRecording ? const Color(0xFFDC2626) : const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    for (final sample in samples) {
      final clamped = sample.clamp(0.04, 1.0);
      final barHeight = (size.height - 16) * clamped;
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(startX + (barWidth / 2), centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(999),
      );
      canvas.drawRRect(rect, barPaint);
      startX += barWidth + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.progress != progress ||
        oldDelegate.isRecording != isRecording;
  }
}

class _RecorderBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _RecorderBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _AnalysisStepContent extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final bool hasRecording;
  final PronunciationAnalysisReport? report;
  final VoidCallback onRetryWord;

  const _AnalysisStepContent({
    required this.isLoading,
    required this.error,
    required this.hasRecording,
    required this.report,
    required this.onRetryWord,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!hasRecording) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.analytics_outlined, color: Color(0xFF94A3B8)),
        title: Text('Record a sample first'),
        subtitle: Text(
          'Analysis becomes available after you confirm a recording.',
        ),
      );
    }

    if (isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Gemini is analyzing your pronunciation at phoneme level...',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF334155),
              ),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Text(
          error!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF991B1B),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (report == null) {
      return const Text(
        'Confirm your recording to run Gemini pronunciation analysis.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _ScoreRing(score: report!.overallScore),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pronunciation Score',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${report!.overallScore}/100',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (report!.heardText.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Gemini heard: ${report!.heardText}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (report!.strengths.isNotEmpty)
          _AnalysisListCard(
            title: 'Strengths',
            icon: Icons.thumb_up_alt_outlined,
            items: report!.strengths,
            emptyText: 'No clear strengths identified yet.',
            color: const Color(0xFF166534),
          ),
        if (report!.strengths.isNotEmpty) const SizedBox(height: 12),
        if (report!.priorities.isNotEmpty)
          _AnalysisListCard(
            title: 'Needs Work',
            icon: Icons.track_changes_outlined,
            items: report!.priorities,
            emptyText: 'No major issues identified.',
            color: const Color(0xFF9A3412),
          ),
        if (report!.priorities.isNotEmpty) const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phoneme Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              ...report!.phonemeBreakdown.map(
                (entry) => _PhonemeFeedbackCard(entry: entry),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Next Try',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                report!.nextTryInstruction,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onRetryWord,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Retry Same Word'),
          ),
        ),
      ],
    );
  }
}

class _RetryHintCard extends StatelessWidget {
  final PronunciationAnalysisReport report;

  const _RetryHintCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final topPriorities = report.priorities.take(2).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Tips',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 8),
          if (topPriorities.isNotEmpty) ...[
            ...topPriorities.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 7,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: const Color(0xFF78350F)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (report.nextTryInstruction.isNotEmpty)
            Text(
              report.nextTryInstruction,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _AnalysisListCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  final String emptyText;
  final Color color;

  const _AnalysisListCard({
    required this.title,
    required this.icon,
    required this.items,
    required this.emptyText,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(emptyText)
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.toLowerCase()) {
      'correct' => (const Color(0xFF16A34A), '✓'),
      'incorrect' => (const Color(0xFFDC2626), '✗'),
      'partial' => (const Color(0xFF0284C7), '◐'),
      _ => (const Color(0xFF64748B), '?'),
    };

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _PhonemeFeedbackCard extends StatelessWidget {
  final PronunciationPhonemeFeedback entry;

  const _PhonemeFeedbackCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MouthShapeBadge(description: entry.lipShape),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.phoneme,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              _StatusBadge(status: entry.status),
            ],
          ),
          const SizedBox(height: 8),
          if (entry.lipShape.isNotEmpty) ...[
            Text(
              'Lip shape: ${entry.lipShape}',
              style: const TextStyle(
                color: Color(0xFF075985),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text('Heard: ${entry.observed}'),
          const SizedBox(height: 4),
          Text('Tip: ${entry.tip}'),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  final int score;

  const _ScoreRing({required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 8,
            backgroundColor: const Color(0xFFDCFCE7),
            color: const Color(0xFF16A34A),
          ),
          Center(
            child: Text(
              '$score',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MouthShapeType { rounded, spread, open, narrow, neutral }

class _MouthShapeBadge extends StatelessWidget {
  final String description;

  const _MouthShapeBadge({required this.description});

  _MouthShapeType _resolveType(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('round') ||
        normalized.contains('rounded') ||
        normalized.contains('forward') ||
        normalized.contains('o ') ||
        normalized.contains('u ') ||
        normalized.contains('ö') ||
        normalized.contains('ü')) {
      return _MouthShapeType.rounded;
    }
    if (normalized.contains('spread') ||
        normalized.contains('smile') ||
        normalized.contains('wide e') ||
        normalized.contains('e ')) {
      return _MouthShapeType.spread;
    }
    if (normalized.contains('wide open') ||
        normalized.contains('jaw dropped') ||
        normalized.contains('open') ||
        normalized.contains('a ')) {
      return _MouthShapeType.open;
    }
    if (normalized.contains('tight') ||
        normalized.contains('narrow') ||
        normalized.contains('small opening')) {
      return _MouthShapeType.narrow;
    }
    return _MouthShapeType.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final type = _resolveType(description);
    final accent = switch (type) {
      _MouthShapeType.rounded => const Color(0xFF2563EB),
      _MouthShapeType.spread => const Color(0xFF7C3AED),
      _MouthShapeType.open => const Color(0xFFEA580C),
      _MouthShapeType.narrow => const Color(0xFF0891B2),
      _MouthShapeType.neutral => const Color(0xFF64748B),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.10),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: CustomPaint(
        painter: _MouthShapePainter(type: type, accent: accent),
      ),
    );
  }
}

class _MouthShapePainter extends CustomPainter {
  final _MouthShapeType type;
  final Color accent;

  const _MouthShapePainter({required this.type, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final facePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final outlinePaint = Paint()
      ..color = accent.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final faceRect = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    canvas.drawOval(faceRect, facePaint);
    canvas.drawOval(faceRect, outlinePaint);

    final mouthPaint = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    switch (type) {
      case _MouthShapeType.rounded:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 + 3),
            width: 10,
            height: 13,
          ),
          mouthPaint,
        );
        break;
      case _MouthShapeType.spread:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2 + 3),
              width: 15,
              height: 5,
            ),
            const Radius.circular(999),
          ),
          mouthPaint,
        );
        break;
      case _MouthShapeType.open:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2 + 4),
            width: 13,
            height: 16,
          ),
          mouthPaint,
        );
        break;
      case _MouthShapeType.narrow:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(size.width / 2, size.height / 2 + 3),
              width: 8,
              height: 12,
            ),
            const Radius.circular(999),
          ),
          mouthPaint,
        );
        break;
      case _MouthShapeType.neutral:
        canvas.drawLine(
          Offset(size.width / 2 - 6, size.height / 2 + 4),
          Offset(size.width / 2 + 6, size.height / 2 + 4),
          mouthPaint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MouthShapePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.accent != accent;
  }
}
