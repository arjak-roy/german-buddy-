import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class PronunciationRecordingProvider extends ChangeNotifier {
  static const Duration maxDuration = Duration(seconds: 5);
  static const Duration _amplitudeInterval = Duration(milliseconds: 75);
  static const Duration _progressInterval = Duration(milliseconds: 100);

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<void>? _playerCompleteSubscription;
  Timer? _progressTimer;
  DateTime? _recordingStartedAt;

  bool _isRecording = false;
  bool _isPlayingBack = false;
  bool _isBusy = false;
  bool _hasPermission = false;
  String? _recordedFilePath;
  String? _error;
  String? _wordKey;
  Duration _recordingDuration = Duration.zero;
  final List<double> _waveformSamples = <double>[];

  bool get isRecording => _isRecording;
  bool get isPlayingBack => _isPlayingBack;
  bool get isBusy => _isBusy;
  bool get hasPermission => _hasPermission;
  bool get hasRecording => _recordedFilePath != null;
  String? get recordedFilePath => _recordedFilePath;
  String? get error => _error;
  String? get wordKey => _wordKey;
  Duration get recordingDuration => _recordingDuration;
  List<double> get waveformSamples =>
      List<double>.unmodifiable(_waveformSamples);
  double get progress =>
      (_recordingDuration.inMilliseconds / maxDuration.inMilliseconds).clamp(
        0.0,
        1.0,
      );

  static const String _pluginUnavailableMessage =
      'Audio recorder plugin is not available in the running app. Stop the app completely and start it again so the native plugin can register.';

  Future<void> prepareForWord(String word) async {
    if (_wordKey == word) return;
    await clearRecording();
    _wordKey = word;
    notifyListeners();
  }

  Future<void> initializePlayback() async {
    await _playerCompleteSubscription?.cancel();
    _playerCompleteSubscription = _player.onPlayerComplete.listen((_) {
      _isPlayingBack = false;
      notifyListeners();
    });
  }

  Future<bool> startRecording() async {
    if (_isRecording || _isBusy) return false;

    _isBusy = true;
    _error = null;
    notifyListeners();

    try {
      _hasPermission = await _recorder.hasPermission(request: true);
      if (!_hasPermission) {
        _error = 'Microphone permission is required to record.';
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final safeWord = (_wordKey ?? 'pronunciation')
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final outputPath =
          '${tempDir.path}/${safeWord.isEmpty ? 'pronunciation' : safeWord}_${DateTime.now().millisecondsSinceEpoch}.wav';

      _waveformSamples
        ..clear()
        ..add(0.04);
      await _stopPlayback();
      _recordedFilePath = null;
      _recordingDuration = Duration.zero;
      _recordingStartedAt = DateTime.now();

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(_amplitudeInterval)
          .listen((amplitude) {
            if (!_isRecording) return;
            _waveformSamples.add(_normalizeAmplitude(amplitude.current));
            if (_waveformSamples.length > 120) {
              _waveformSamples.removeAt(0);
            }
            notifyListeners();
          });

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: outputPath,
      );

      _isRecording = true;
      _startProgressTimer();
      return true;
    } on MissingPluginException {
      _error = _pluginUnavailableMessage;
      return false;
    } catch (error) {
      _error = 'Recording failed to start: $error';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> stopRecording() async {
    if (!_isRecording || _isBusy) return false;

    _isBusy = true;
    notifyListeners();

    try {
      _stopProgressTimer();
      final path = await _recorder.stop();
      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;

      _recordedFilePath = path;
      _isRecording = false;
      _recordingStartedAt = null;

      if (_waveformSamples.isEmpty) {
        _waveformSamples.add(0.04);
      }

      return path != null;
    } on MissingPluginException {
      _error = _pluginUnavailableMessage;
      _isRecording = false;
      _recordingStartedAt = null;
      return false;
    } catch (error) {
      _error = 'Recording failed to stop: $error';
      _isRecording = false;
      _recordingStartedAt = null;
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> togglePlayback() async {
    if (_isRecording || _isBusy || _recordedFilePath == null) {
      return false;
    }

    try {
      if (_isPlayingBack) {
        await _stopPlayback();
        return true;
      }

      _error = null;
      await _player.stop();
      await _player.play(DeviceFileSource(_recordedFilePath!));
      _isPlayingBack = true;
      notifyListeners();
      return true;
    } on MissingPluginException {
      _error =
          'Audio playback plugin is not available in the running app. Stop the app completely and start it again so the native plugin can register.';
      _isPlayingBack = false;
      notifyListeners();
      return false;
    } catch (error) {
      _error = 'Playback failed: $error';
      _isPlayingBack = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _stopPlayback() async {
    await _player.stop();
    _isPlayingBack = false;
    notifyListeners();
  }

  Future<void> clearRecording() async {
    _stopProgressTimer();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _stopPlayback();

    if (_isRecording) {
      try {
        await _recorder.cancel();
      } catch (_) {
        // Ignore recorder cancel errors while resetting transient state.
      }
    }

    _isRecording = false;
    _isPlayingBack = false;
    _isBusy = false;
    _recordedFilePath = null;
    _error = null;
    _recordingDuration = Duration.zero;
    _recordingStartedAt = null;
    _waveformSamples.clear();
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(_progressInterval, (timer) {
      final startedAt = _recordingStartedAt;
      if (!_isRecording || startedAt == null) {
        timer.cancel();
        return;
      }

      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed >= maxDuration) {
        _recordingDuration = maxDuration;
        timer.cancel();
        unawaited(stopRecording());
      } else {
        _recordingDuration = elapsed;
        notifyListeners();
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  double _normalizeAmplitude(double currentDb) {
    if (currentDb.isNaN || currentDb.isInfinite) {
      return 0.04;
    }

    final normalized = (currentDb + 45) / 45;
    return math.max(0.04, normalized.clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _stopProgressTimer();
    unawaited(_amplitudeSubscription?.cancel());
    unawaited(_playerCompleteSubscription?.cancel());
    unawaited(_player.dispose());
    unawaited(_recorder.dispose());
    super.dispose();
  }
}
