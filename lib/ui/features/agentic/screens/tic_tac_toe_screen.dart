import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';

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
  final Random _random = Random();
  late final FlutterTts _tts;
  bool _gameOver = false;
  String _status = 'Say a move like top left or oben links.';
  String? _winner;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
    _messages.add(
      const _TicTacToeMessage(
        text:
            'Welcome. Say top left, center, unten rechts, or reset to play Tic-Tac-Toe.',
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
    super.dispose();
  }

  Future<void> _handleCommand(String rawText) async {
    final command = rawText.trim();
    if (command.isEmpty) return;

    setState(() {
      _messages.add(_TicTacToeMessage(text: command, isUser: true));
    });

    final normalized = _normalize(command);

    if (_matchesAny(normalized, const ['reset', 'restart', 'new game'])) {
      _resetGame();
      return;
    }

    if (_matchesAny(normalized, const ['hilfe', 'help', 'anleitung'])) {
      await _respond(
        _isGermanUi(context)
            ? 'Sage oben links, mitte, unten rechts oder eine Zahl von eins bis neun. Du bist X.'
            : 'Say top left, center, bottom right, or a number from one to nine. You are X.',
      );
      return;
    }

    if (_gameOver) {
      await _respond(
        _isGermanUi(context)
            ? 'Das Spiel ist vorbei. Sage reset für eine neue Runde.'
            : 'The game is over. Say reset for a new round.',
      );
      return;
    }

    final move = _parseMove(normalized);
    if (move == null) {
      await _respond(
        _isGermanUi(context)
            ? 'Ich habe den Zug nicht verstanden. Versuche oben links, mitte oder Feld fünf.'
            : 'I did not understand that move. Try top left, center, or square five.',
      );
      return;
    }

    if (_board[move].isNotEmpty) {
      await _respond(
        _isGermanUi(context)
            ? 'Dieses Feld ist schon belegt. Wähle ein anderes.'
            : 'That square is already taken. Choose another one.',
      );
      return;
    }

    _applyPlayerMove(move);
  }

  void _applyPlayerMove(int index) {
    setState(() {
      _board[index] = _playerMark;
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

    final agentMove = _chooseAgentMove();
    setState(() {
      _board[agentMove] = _agentMark;
    });

    final agentWin = _findWinner();
    if (agentWin != null) {
      _finishGame(agentWin);
      return;
    }

    if (_isDraw()) {
      _finishDraw();
      return;
    }

    final cellName = _localizedCellName(
      agentMove,
      german: _isGermanUi(context),
    );
    _respond(
      _isGermanUi(context)
          ? 'Ich spiele $cellName. Du bist dran.'
          : 'I play $cellName. Your turn.',
    );
  }

  void _finishGame(String winner) {
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

    _respond(_isGermanUi(context) ? german : english);
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
    );
  }

  void _resetGame() {
    setState(() {
      for (var index = 0; index < _board.length; index++) {
        _board[index] = '';
      }
      _gameOver = false;
      _winner = null;
      _status = _isGermanUi(context)
          ? 'Neues Spiel. Du beginnst als X.'
          : 'New game. You start as X.';
    });

    _respond(_status);
  }

  Future<void> _respond(String text) async {
    if (!mounted) return;
    setState(() {
      _messages.add(_TicTacToeMessage(text: text, isUser: false));
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

  int _chooseAgentMove() {
    final winning = _findStrategicMove(_agentMark);
    if (winning != null) return winning;

    final blocking = _findStrategicMove(_playerMark);
    if (blocking != null) return blocking;

    if (_board[4].isEmpty) return 4;

    final corners = [
      0,
      2,
      6,
      8,
    ].where((index) => _board[index].isEmpty).toList();
    if (corners.isNotEmpty) {
      return corners[_random.nextInt(corners.length)];
    }

    final available = _emptySquares();
    return available[_random.nextInt(available.length)];
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

  List<int> _emptySquares() {
    return List<int>.generate(
      _board.length,
      (index) => index,
    ).where((index) => _board[index].isEmpty).toList();
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

  int? _parseMove(String normalized) {
    final directNumber = _parseNumber(normalized);
    if (directNumber != null) return directNumber;

    final compact = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    if (compact.contains('center') ||
        compact.contains('centre') ||
        compact.contains('mitte')) {
      return 4;
    }

    final hasTop = compact.contains('top') || compact.contains('oben');
    final hasBottom = compact.contains('bottom') || compact.contains('unten');
    final hasLeft = compact.contains('left') || compact.contains('links');
    final hasRight = compact.contains('right') || compact.contains('rechts');

    if (hasTop && hasLeft) return 0;
    if (hasTop && hasRight) return 2;
    if (hasBottom && hasLeft) return 6;
    if (hasBottom && hasRight) return 8;
    if (hasTop) return 1;
    if (hasBottom) return 7;
    if (hasLeft) return 3;
    if (hasRight) return 5;

    if (compact.contains('row one') || compact.contains('erste reihe')) {
      if (compact.contains('column one') || compact.contains('erste spalte')) {
        return 0;
      }
      if (compact.contains('column two') || compact.contains('zweite spalte')) {
        return 1;
      }
      if (compact.contains('column three') ||
          compact.contains('dritte spalte')) {
        return 2;
      }
    }

    if (compact.contains('row two') || compact.contains('zweite reihe')) {
      if (compact.contains('column one') || compact.contains('erste spalte')) {
        return 3;
      }
      if (compact.contains('column two') || compact.contains('zweite spalte')) {
        return 4;
      }
      if (compact.contains('column three') ||
          compact.contains('dritte spalte')) {
        return 5;
      }
    }

    if (compact.contains('row three') || compact.contains('dritte reihe')) {
      if (compact.contains('column one') || compact.contains('erste spalte')) {
        return 6;
      }
      if (compact.contains('column two') || compact.contains('zweite spalte')) {
        return 7;
      }
      if (compact.contains('column three') ||
          compact.contains('dritte spalte')) {
        return 8;
      }
    }

    return null;
  }

  int? _parseNumber(String normalized) {
    const numbers = <String, int>{
      '1': 0,
      'one': 0,
      'eins': 0,
      '2': 1,
      'two': 1,
      'zwei': 1,
      '3': 2,
      'three': 2,
      'drei': 2,
      '4': 3,
      'four': 3,
      'vier': 3,
      '5': 4,
      'five': 4,
      'fuenf': 4,
      'funf': 4,
      'fünf': 4,
      '6': 5,
      'six': 5,
      'sechs': 5,
      '7': 6,
      'seven': 6,
      'sieben': 6,
      '8': 7,
      'eight': 7,
      'acht': 7,
      '9': 8,
      'nine': 8,
      'neun': 8,
    };

    for (final entry in numbers.entries) {
      if (RegExp(
        '(^| )${RegExp.escape(entry.key)}( |\$)',
      ).hasMatch(normalized)) {
        return entry.value;
      }
    }
    return null;
  }

  bool _matchesAny(String text, List<String> patterns) {
    return patterns.any((pattern) => text.contains(pattern));
  }

  String _normalize(String text) {
    return text.toLowerCase().replaceAll('ö', 'o').replaceAll('ü', 'u');
  }

  bool _isGermanUi(BuildContext context) {
    return context.read<SpeechProvider>().isGerman;
  }

  String _localizedCellName(int index, {required bool german}) {
    const english = <int, String>{
      0: 'top left',
      1: 'top center',
      2: 'top right',
      3: 'middle left',
      4: 'center',
      5: 'middle right',
      6: 'bottom left',
      7: 'bottom center',
      8: 'bottom right',
    };
    const germanMap = <int, String>{
      0: 'oben links',
      1: 'oben mitte',
      2: 'oben rechts',
      3: 'mitte links',
      4: 'mitte',
      5: 'mitte rechts',
      6: 'unten links',
      7: 'unten mitte',
      8: 'unten rechts',
    };
    return german ? germanMap[index]! : english[index]!;
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
            onPressed: _resetGame,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: isGerman ? 'Neustart' : 'Restart',
          ),
        ],
      ),
      body: SafeArea(
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
                    onTap: (index) {
                      if (_gameOver || _board[index].isNotEmpty) return;
                      _applyPlayerMove(index);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HintChip(label: isGerman ? 'oben links' : 'top left'),
                      _HintChip(label: isGerman ? 'mitte' : 'center'),
                      _HintChip(
                        label: isGerman ? 'unten rechts' : 'bottom right',
                      ),
                      _HintChip(label: isGerman ? 'Feld 5' : 'square 5'),
                      _HintChip(label: isGerman ? 'reset' : 'reset'),
                    ],
                  ),
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

  const _HintChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
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
      ],
    );
  }
}

class _TicTacToeMessage {
  final String text;
  final bool isUser;

  const _TicTacToeMessage({required this.text, required this.isUser});
}
