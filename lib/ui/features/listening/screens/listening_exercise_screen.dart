import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/listening_exercise_item.dart';

class ListeningExerciseScreen extends StatefulWidget {
  final ListeningExerciseItem item;
  const ListeningExerciseScreen({super.key, required this.item});

  @override
  State<ListeningExerciseScreen> createState() =>
      _ListeningExerciseScreenState();
}

class _ListeningExerciseScreenState extends State<ListeningExerciseScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _currentStep = 0;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  Duration _maxListenedPosition = Duration.zero;
  bool _isAudioReady = false;
  bool _hasCompletedAudioOnce = false;

  // Sample MCQs
  final List<Map<String, Object>> _questions = [
    {
      'question': 'Was war das Hauptthema des Audios?',
      'options': ['Ein Apfel', 'Eine Banane', 'Ein Auto', 'Ein Haus'],
      'correct': 0,
    },
    {
      'question': 'Wo fand das Gespräch statt?',
      'options': ['Im Supermarkt', 'In der Schule', 'Im Kino', 'Im Park'],
      'correct': 0,
    },
  ];

  late List<int?> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<int?>.filled(_questions.length, null);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _position = Duration.zero;
        _maxListenedPosition = _duration;
        _hasCompletedAudioOnce = true;
      });
    });
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() {
        _duration = d;
      });
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() {
        _position = p;
        if (p > _maxListenedPosition) {
          _maxListenedPosition = p;
        }
      });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause() async {
    try {
      debugPrint(
        'ListeningAudio: tap playPause isPlaying=$_isPlaying isAudioReady=$_isAudioReady position=$_position duration=$_duration',
      );
      if (_isPlaying) {
        await _audioPlayer.pause();
        debugPrint('ListeningAudio: paused');
        return;
      }

      if (!_isAudioReady) {
        // AssetSource is prefixed by 'assets/' by audioplayers.
        await _audioPlayer.setSource(AssetSource('test.mp3'));
        _isAudioReady = true;
        _maxListenedPosition = Duration.zero;
        _hasCompletedAudioOnce = false;
        debugPrint('ListeningAudio: source loaded assets/test.mp3');
      }

      await _audioPlayer.resume();
      debugPrint('ListeningAudio: resume called');
    } catch (e) {
      debugPrint('ListeningAudio: error $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Audio failed to play: $e')));
    }
  }

  void _goToNext() {
    if (_currentStep == 0 && !_hasCompletedAudioOnce) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please listen to the full audio first.')),
      );
      return;
    }
    if (_currentStep < 2) setState(() => _currentStep += 1);
  }

  void _goToBack() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  int _computeScore() {
    var score = 0;
    for (var i = 0; i < _questions.length; i++) {
      final correct = _questions[i]['correct'] as int;
      if (_selected[i] != null && _selected[i] == correct) score += 1;
    }
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final total = _questions.length;
    final score = _computeScore();

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Listening Exercise',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow the steps to listen, answer, and get your results.',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Stepper(
                currentStep: _currentStep,
                physics: const ClampingScrollPhysics(),
                onStepTapped: (s) {
                  if (s > 0 && !_hasCompletedAudioOnce) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Finish the full audio before continuing.',
                        ),
                      ),
                    );
                    return;
                  }
                  setState(() => _currentStep = s);
                },
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Row(
                      children: [
                        if (_currentStep > 0)
                          TextButton(
                            onPressed: _goToBack,
                            child: const Text('Back'),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed:
                              _currentStep == 0 && !_hasCompletedAudioOnce
                              ? null
                              : () {
                                  if (_currentStep == 1) {
                                    final allAnswered = _selected.every(
                                      (e) => e != null,
                                    );
                                    if (!allAnswered) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Please answer all questions.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                  }
                                  if (_currentStep == 2) {
                                    setState(() {
                                      _selected = List<int?>.filled(
                                        _questions.length,
                                        null,
                                      );
                                      _currentStep = 0;
                                      _hasCompletedAudioOnce = false;
                                      _maxListenedPosition = Duration.zero;
                                    });
                                    return;
                                  }
                                  _goToNext();
                                },
                          child: Text(_currentStep == 2 ? 'Restart' : 'Next'),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text('Play German Audio'),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      children: [
                        Text('Tap play to listen to the native German audio.'),
                        const SizedBox(height: 12),
                        IconButton(
                          iconSize: 64,
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle : Icons.play_circle,
                          ),
                          onPressed: _playPause,
                        ),
                        Slider(
                          min: 0,
                          max: _duration.inSeconds > 0
                              ? _duration.inSeconds.toDouble()
                              : 1,
                          value: _position.inSeconds
                              .clamp(0, _duration.inSeconds)
                              .toDouble(),
                          onChanged: (v) async {
                            final pos = Duration(seconds: v.toInt());
                            if (!_hasCompletedAudioOnce &&
                                pos > _maxListenedPosition) {
                              await _audioPlayer.seek(_maxListenedPosition);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'You can\'t skip ahead before finishing the audio once.',
                                  ),
                                ),
                              );
                              return;
                            }
                            await _audioPlayer.seek(pos);
                          },
                        ),
                        Text(
                          '${_position.toString().split('.').first} / ${_duration.toString().split('.').first}',
                        ),
                      ],
                    ),
                  ),
                  Step(
                    title: const Text('Answer Questions'),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1
                        ? StepState.complete
                        : StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List<Widget>.generate(_questions.length, (i) {
                        final q = _questions[i];
                        final options = q['options'] as List<String>;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text('Buddy: ${q['question'] as String}'),
                            ),
                            ...List<Widget>.generate(options.length, (optIdx) {
                              final option = options[optIdx];
                              return RadioListTile<int>(
                                title: Text(option),
                                value: optIdx,
                                groupValue: _selected[i],
                                onChanged: (v) {
                                  setState(() {
                                    _selected[i] = v;
                                  });
                                },
                              );
                            }),
                          ],
                        );
                      }),
                    ),
                  ),
                  Step(
                    title: const Text('Results & Analysis'),
                    isActive: _currentStep >= 2,
                    state: StepState.indexed,
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'You scored $score / $total',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.generate(_questions.length, (
                                i,
                              ) {
                                final q = _questions[i];
                                final options = q['options'] as List<String>;
                                final correct = q['correct'] as int;
                                final selected = _selected[i];
                                final correctText = options[correct];
                                final selectedText = selected == null
                                    ? '—'
                                    : options[selected];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Q${i + 1}: ${q['question'] as String}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Your answer: $selectedText'),
                                      Text(
                                        'Correct: $correctText',
                                        style: const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selected = List<int?>.filled(
                                _questions.length,
                                null,
                              );
                              _currentStep = 0;
                            });
                          },
                          child: const Text('Try Again'),
                        ),
                      ],
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
