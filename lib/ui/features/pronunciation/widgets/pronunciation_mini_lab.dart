import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../models/pronunciation_item.dart';
import '../utils/phoneme_mapping.dart';
import 'pronunciation_lips_visual.dart';

class PronunciationMiniLab extends StatefulWidget {
  final PronunciationItem item;
  final bool showSpeedControl;

  const PronunciationMiniLab({
    super.key,
    required this.item,
    this.showSpeedControl = true,
  });

  @override
  State<PronunciationMiniLab> createState() => _PronunciationMiniLabState();
}

class _PronunciationMiniLabState extends State<PronunciationMiniLab> {
  late final FlutterTts _tts;
  Timer? _segmentTimer;
  int _activeSegmentIndex = -1;
  bool _isPlaying = false;
  double _speechRate = 0.45;

  List<String> get _segments => widget.item.segments;
  List<PronunciationViseme> get _visemes => visemesForSegments(_segments);

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE');
    _tts.setSpeechRate(_speechRate);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(false);

    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlaying = true;
      });
    });
    _tts.setCompletionHandler(_stopPlaybackUi);
    _tts.setCancelHandler(_stopPlaybackUi);
    _tts.setErrorHandler((_) => _stopPlaybackUi());
  }

  @override
  void dispose() {
    _segmentTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  Future<void> _playWord() async {
    _segmentTimer?.cancel();
    setState(() {
      _isPlaying = true;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: PronunciationAnimatedLips(
            isPlaying: _isPlaying,
            activeIndex: _activeSegmentIndex,
            visemes: _visemes,
            width: 158,
            height: 108,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.item.german,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.item.english,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(_segments.length, (index) {
            final active = _isPlaying && index == _activeSegmentIndex;
            final passed = _isPlaying && index < _activeSegmentIndex;
            final background = active
                ? const Color(0xFF16A34A)
                : (passed ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0));
            final foreground = active || passed
                ? Colors.white
                : const Color(0xFF334155);

            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _segments[index],
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _playWord,
              icon: Icon(
                _isPlaying ? Icons.equalizer : Icons.volume_up_rounded,
              ),
              label: Text(_isPlaying ? 'Playing...' : 'Hear word'),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: _stopPlaybackUi,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Stop'),
            ),
          ],
        ),
        if (widget.showSpeedControl) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.speed_rounded, size: 18),
              const SizedBox(width: 8),
              const Text('Speed'),
              Expanded(
                child: Slider(
                  value: _speechRate,
                  min: 0.25,
                  max: 0.7,
                  divisions: 9,
                  label: _speechRate.toStringAsFixed(2),
                  onChanged: (value) {
                    setState(() {
                      _speechRate = value;
                    });
                    _tts.setSpeechRate(value);
                  },
                ),
              ),
              Text(_speechRate.toStringAsFixed(2)),
            ],
          ),
        ],
      ],
    );
  }
}
