import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';

import '../../../../data/services/gemini_service.dart';
import '../../../../providers/speech_provider.dart';
import '../../../shared/widgets/speech_action_bar.dart';

class TicTacToeScreen extends StatefulWidget {
  const TicTacToeScreen({super.key});

  @override
  State<TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<TicTacToeScreen> {
  static const String _playerMark = 'X';
  static const String _agentMark = 'O';
  static const List<List<int>> _winningLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  final List<String> _board = List<String>.filled(9, '');
  final List<_TicTacToeMessage> _messages = <_TicTacToeMessage>[];
  final GeminiService _gemini = GeminiService();
  late final FlutterTts _tts;
  late final ConfettiController _confettiController;
  bool _gameOver = false;
  bool _isResolvingTurn = false;
  String _status = 'Say a move like top left or oben links.';
  String? _winner;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
    _confettiController = ConfettiController(
      duration: const Duration(milliseconds: 1800),
    );
    _messages.add(
      const _TicTacToeMessage(
        text:
            'Welcome. Say top left, center, unten rechts, or reset to play Tic-Tac-Toe.',
        translated: 'Welcome. Say top left, center, bottom right, or reset to play Tic-Tac-Toe.',
        isUser: false,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _speakLatestAssistantMessage();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _handleCommand(String rawText) async {
    final command = rawText.trim();
    if (command.isEmpty) return;

    setState(() {
      _messages.add(_TicTacToeMessage(text: command, isUser: true));
    });

    if (_isResolvingTurn) {
      await _respond(
        _isGermanUi(context)
            ? 'Einen Moment, ich verarbeite noch den letzten Zug.'
            : 'One moment, I am still processing the previous turn.',
        englishTranslation: 'One moment, I am still processing the previous turn.',
      );
      return;
    }

    setState(() {
      _isResolvingTurn = true;
    });

    try {
      final turnPlan = await _gemini.planTicTacToeTurn(
        userUtterance: command,
        board: List<String>.from(_board),
        isGameOver: _gameOver,
        winner: _winner,
        isGerman: _isGermanUi(context),
      );

      await _applyTurnPlan(turnPlan);
    } catch (_) {
      await _respond(
        _isGermanUi(context)
            ? 'Ich konnte den Zug gerade nicht verarbeiten. Versuche es bitte noch einmal.'
            : 'I could not process that turn right now. Please try again.',
        englishTranslation:
            'I could not process that turn right now. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingTurn = false;
        });
      }
    }
  }

  Future<void> _applyTurnPlan(TicTacToeTurnPlan plan) async {
    final action = plan.action.trim().toLowerCase();

    if (action == 'reset_game') {
      _resetGame(
        customStatus: plan.spokenResponse,
        customEnglishTranslation: plan.englishTranslation,
      );
      return;
    }

    if (action == 'help') {
      await _respond(
        plan.spokenResponse.isNotEmpty
            ? plan.spokenResponse
            : (_isGermanUi(context)
                ? 'Sage zum Beispiel oben links, mitte, unten rechts oder reset.'
                : 'Say for example top left, center, bottom right, or reset.'),
        englishTranslation: plan.englishTranslation.isNotEmpty
            ? plan.englishTranslation
            : 'Say for example top left, center, bottom right, or reset.',
      );
      return;
    }

    if (action != 'player_move') {
      await _respond(
        plan.spokenResponse.isNotEmpty
            ? plan.spokenResponse
            : (_isGermanUi(context)
                ? 'Ich habe den Zug nicht verstanden. Bitte buchstabiere es korrekt.'
                : 'I did not understand that move. Please spell it correctly.'),
        englishTranslation: plan.englishTranslation.isNotEmpty
            ? plan.englishTranslation
            : 'I did not understand that move. Please spell it correctly.',
      );
      return;
    }

    if (_gameOver) {
      await _respond(
        _isGermanUi(context)
            ? 'Das Spiel ist vorbei. Sage reset für eine neue Runde.'
            : 'The game is over. Say reset for a new round.',
        englishTranslation: 'The game is over. Say reset for a new round.',
      );
      return;
    }

    final playerMove = plan.playerMoveIndex;
    if (playerMove == null || !_isLegalMove(playerMove)) {
      await _respond(
        plan.spokenResponse.isNotEmpty
            ? plan.spokenResponse
            : (_isGermanUi(context)
                ? 'Bitte nenne ein freies Feld von eins bis neun.'
                : 'Please name a free square from one to nine.'),
        englishTranslation: plan.englishTranslation.isNotEmpty
            ? plan.englishTranslation
            : 'Please name a free square from one to nine.',
      );
      return;
    }

    setState(() {
      _board[playerMove] = _playerMark;
    });

    final playerWin = _findWinner();
    if (playerWin != null) {
      _finishGame(playerWin);
      return;
    }

    if (_isDraw()) {
      _finishDraw();
      return;
    }

    final assistantMove = _resolveAssistantMove(plan.assistantMoveIndex);
    if (assistantMove != null) {
      setState(() {
        _board[assistantMove] = _agentMark;
      });
    }

    final agentWin = _findWinner();
    if (agentWin != null) {
      _finishGame(agentWin);
      return;
    }

    if (_isDraw()) {
      _finishDraw();
      return;
    }

    await _respond(
      plan.spokenResponse.isNotEmpty
          ? plan.spokenResponse
          : (_isGermanUi(context)
              ? 'Ich habe meinen Zug gemacht. Du bist dran.'
              : 'I made my move. Your turn.'),
      englishTranslation: plan.englishTranslation.isNotEmpty
          ? plan.englishTranslation
          : 'I made my move. Your turn.',
    );
  }

  Future<void> _handleBoardTap(int index) async {
    if (_gameOver || _board[index].isNotEmpty) return;

    if (_isResolvingTurn) {
      await _respond(
        _isGermanUi(context)
            ? 'Einen Moment, ich verarbeite noch den letzten Zug.'
            : 'One moment, I am still processing the previous turn.',
        englishTranslation: 'One moment, I am still processing the previous turn.',
      );
      return;
    }

    final utterance = _isGermanUi(context)
        ? 'Ich spiele Feld ${index + 1}'
        : 'I play square ${index + 1}';

    setState(() {
      _messages.add(_TicTacToeMessage(text: utterance, isUser: true));
      _isResolvingTurn = true;
    });

    try {
      final plan = await _gemini.planTicTacToeTurn(
        userUtterance: utterance,
        board: List<String>.from(_board),
        isGameOver: _gameOver,
        winner: _winner,
        isGerman: _isGermanUi(context),
      );

      await _applyTurnPlan(
        TicTacToeTurnPlan(
          action: 'player_move',
          playerMoveIndex: index,
          assistantMoveIndex: plan.assistantMoveIndex,
          spokenResponse: plan.spokenResponse,
          englishTranslation: plan.englishTranslation,
        ),
      );
    } catch (_) {
      await _applyTurnPlan(
        TicTacToeTurnPlan(
          action: 'player_move',
          playerMoveIndex: index,
          assistantMoveIndex: null,
          spokenResponse: _isGermanUi(context)
              ? 'Ich habe deinen Zug gesetzt. Du bist dran.'
              : 'I placed your move. Your turn.',
          englishTranslation: 'I placed your move. Your turn.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResolvingTurn = false;
        });
      }
    }
  }

  bool _isLegalMove(int index) {
    return index >= 0 && index < _board.length && _board[index].isEmpty;
  }

  int? _resolveAssistantMove(int? plannedMove) {
    if (plannedMove != null && _isLegalMove(plannedMove)) {
      return plannedMove;
    }

    final winningMove = _findStrategicMove(_agentMark);
    if (winningMove != null) return winningMove;

    final blockingMove = _findStrategicMove(_playerMark);
    if (blockingMove != null) return blockingMove;

    if (_isLegalMove(4)) return 4;

    for (final preferred in const [0, 2, 6, 8, 1, 3, 5, 7]) {
      if (_isLegalMove(preferred)) return preferred;
    }

    return null;
  }

  int? _findStrategicMove(String mark) {
    for (final line in _winningLines) {
      final values = line.map((index) => _board[index]).toList();
      final markCount = values.where((value) => value == mark).length;
      final emptyCount = values.where((value) => value.isEmpty).length;
      if (markCount == 2 && emptyCount == 1) {
        return line.firstWhere((index) => _board[index].isEmpty);
      }
    }
    return null;
  }

  String _squarePhrase(int index, {required bool german}) {
    const english = <String>[
      'top left',
      'top center',
      'top right',
      'middle left',
      'center',
      'middle right',
      'bottom left',
      'bottom center',
      'bottom right',
    ];
    const germanPhrases = <String>[
      'oben links',
      'oben mitte',
      'oben rechts',
      'mitte links',
      'mitte',
      'mitte rechts',
      'unten links',
      'unten mitte',
      'unten rechts',
    ];
    return german ? germanPhrases[index] : english[index];
  }

  void _finishGame(
    String winner,
  ) {
    final german = winner == _playerMark
        ? 'Du gewinnst. Sage reset für ein neues Spiel.'
        : 'Ich gewinne. Sage reset für ein neues Spiel.';
    final english = winner == _playerMark
        ? 'You win. Say reset for a new game.'
        : 'I win. Say reset for a new game.';

    setState(() {
      _winner = winner;
      _gameOver = true;
      _status = winner == _playerMark ? 'You win.' : 'Agent wins.';
    });

    if (winner == _playerMark) {
      _confettiController.play();
    }

    _respond(
      _isGermanUi(context) ? german : english,
      englishTranslation: english,
    );
  }

  void _finishDraw() {
    setState(() {
      _winner = 'draw';
      _gameOver = true;
      _status = 'Draw game.';
    });

    _respond(
      _isGermanUi(context)
          ? 'Unentschieden. Sage reset für ein neues Spiel.'
          : 'Draw. Say reset for a new game.',
      englishTranslation: 'Draw. Say reset for a new game.',
    );
  }

  void _resetGame({
    String? customStatus,
    String? customEnglishTranslation,
  }) {
    setState(() {
      for (var index = 0; index < _board.length; index++) {
        _board[index] = '';
      }
      _gameOver = false;
      _winner = null;
      _status = customStatus?.isNotEmpty == true
          ? customStatus!
          : (_isGermanUi(context)
              ? 'Neues Spiel. Du beginnst als X.'
              : 'New game. You start as X.');
    });

    _respond(
      _status,
      englishTranslation: customEnglishTranslation?.isNotEmpty == true
          ? customEnglishTranslation!
          : 'New game. You start as X.',
    );
  }

  Future<void> _respond(String text, {String? englishTranslation}) async {
    if (!mounted) return;
    setState(() {
      _messages.add(
        _TicTacToeMessage(
          text: text,
          translated: englishTranslation,
          isUser: false,
        ),
      );
      _status = text;
    });
    await _speakLatestAssistantMessage();
  }

  Future<void> _speakLatestAssistantMessage() async {
    final message = _messages.lastWhere(
      (entry) => !entry.isUser,
      orElse: () => const _TicTacToeMessage(text: '', isUser: false),
    );
    if (message.text.isEmpty) return;

    try {
      await _tts.setLanguage(_isGermanUi(context) ? 'de-DE' : 'en-US');
      await _tts.stop();
      await _tts.speak(message.text);
    } catch (_) {
      // Ignore TTS issues so the game remains playable.
    }
  }

  String? _findWinner() {
    for (final line in _winningLines) {
      final a = _board[line[0]];
      final b = _board[line[1]];
      final c = _board[line[2]];
      if (a.isNotEmpty && a == b && b == c) {
        return a;
      }
    }
    return null;
  }

  bool _isDraw() {
    return _board.every((cell) => cell.isNotEmpty) && _findWinner() == null;
  }

  bool _isGermanUi(BuildContext context) {
    return context.read<SpeechProvider>().isGerman;
  }

  Future<void> _speakGermanHint(String text) async {
    try {
      await _tts.setLanguage('de-DE');
      await _tts.setSpeechRate(0.4);
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Keep hints non-blocking even if TTS fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = context.watch<SpeechProvider>();
    final isGerman = speech.isGerman;
    final showDebug = speech.showDebugPanel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentic AI Tic-Tac-Toe'),
        actions: [
          IconButton(
            icon: Icon(showDebug ? Icons.bug_report : Icons.info_outline),
            tooltip: showDebug
                ? 'Hide STT debug panel'
                : 'Show STT debug panel',
            onPressed: () => context.read<SpeechProvider>().toggleDebugPanel(),
          ),
          IconButton(
            onPressed: () => _resetGame(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isGerman ? 'Neustart' : 'Restart',
          ),
        ],
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _StatusCard(
                    title: isGerman ? 'Sprich deinen Zug' : 'Speak your move',
                    status: _status,
                    winner: _winner,
                    isGerman: isGerman,
                  ),
                  const SizedBox(height: 16),
                  _Board(
                    board: _board,
                    onTap: _handleBoardTap,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...List<Widget>.generate(9, (index) {
                        final phrase = _squarePhrase(index, german: isGerman);
                        return _HintChip(
                          label: '${index + 1}. $phrase',
                          onTap: isGerman
                              ? () => _speakGermanHint('Feld ${index + 1}, $phrase')
                              : null,
                        );
                      }),
                      _HintChip(
                        label: isGerman ? 'reset' : 'reset',
                        onTap: isGerman
                            ? () => _speakGermanHint('reset')
                            : null,
                      ),
                    ],
                  ),
                  if (_isResolvingTurn) ...[
                    const SizedBox(height: 12),
                    Text(
                      isGerman ? 'Gemini denkt...' : 'Gemini is thinking...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    isGerman ? 'Spielverlauf' : 'Voice log',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ..._messages.reversed.map(
                    (message) => _VoiceLogBubble(message: message),
                  ),
                ],
                  ),
                ),
                SpeechActionBar(
                  keyboardLabel: isGerman ? 'Zug eingeben' : 'Type a move',
                  onSubmitted: _handleCommand,
                ),
              ],
            ),
          ),
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                emissionFrequency: 0.05,
                numberOfParticles: 24,
                gravity: 0.2,
                maxBlastForce: 28,
                minBlastForce: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final String? winner;
  final bool isGerman;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.winner,
    required this.isGerman,
  });

  @override
  Widget build(BuildContext context) {
    final outcome = switch (winner) {
      'X' => isGerman ? 'Du führst als X.' : 'You are X.',
      'O' => isGerman ? 'Die KI ist O.' : 'The AI is O.',
      'draw' => isGerman ? 'Unentschieden.' : 'Draw.',
      _ => isGerman ? 'Du bist X. Die KI ist O.' : 'You are X. The AI is O.',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: const TextStyle(color: Colors.white, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(outcome, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  final List<String> board;
  final ValueChanged<int> onTap;

  const _Board({required this.board, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: board.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final value = board[index];
        final isX = value == 'X';
        final color = isX ? const Color(0xFF0F766E) : const Color(0xFFB45309);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onTap(index),
            borderRadius: BorderRadius.circular(20),
            child: Ink(
              decoration: BoxDecoration(
                color: value.isEmpty ? const Color(0xFFF8FAFC) : color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value.isEmpty
                      ? const Color(0xFFCBD5E1)
                      : color.withOpacity(0.7),
                ),
              ),
              child: Center(
                child: Text(
                  value.isEmpty ? '${index + 1}' : value,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: value.isEmpty
                        ? const Color(0xFF64748B)
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HintChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _HintChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _VoiceLogBubble extends StatelessWidget {
  final _TicTacToeMessage message;

  const _VoiceLogBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = message.isUser
        ? const Color(0xFFDBEAFE)
        : const Color(0xFFF1F5F9);

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(message.text),
        ),
        if (!message.isUser && (message.translated?.trim().isNotEmpty ?? false))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message.translated!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}

class _TicTacToeMessage {
  final String text;
  final String? translated;
  final bool isUser;

  const _TicTacToeMessage({
    required this.text,
    this.translated,
    required this.isUser,
  });
}
