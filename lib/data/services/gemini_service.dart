import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/pronunciation_analysis_report.dart';

class TicTacToeTurnPlan {
  final String action;
  final int? playerMoveIndex;
  final int? assistantMoveIndex;
  final String spokenResponse;
  final String englishTranslation;

  const TicTacToeTurnPlan({
    required this.action,
    required this.playerMoveIndex,
    required this.assistantMoveIndex,
    required this.spokenResponse,
    required this.englishTranslation,
  });

  factory TicTacToeTurnPlan.fromFunctionArgs(Map<String, dynamic> args) {
    int? parseIndex(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return TicTacToeTurnPlan(
      action: (args['action'] ?? 'invalid').toString(),
      playerMoveIndex: parseIndex(args['playerMoveIndex']),
      assistantMoveIndex: parseIndex(args['assistantMoveIndex']),
      spokenResponse: (args['spokenResponse'] ?? '').toString().trim(),
      englishTranslation: (args['englishTranslation'] ?? '').toString().trim(),
    );
  }
}

class GeminiService {
  static const _apiKey =
      'AIzaSyC3oONewy_6MuxJeyTs0JhyGdXXe416tfE'; // Use Flutter Dotenv for MVP speed
  static const _model =
      'gemini-3.1-flash-lite-preview'; // Note: check current available models
  static const _audioModel = 'gemini-3-flash-preview';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const _ticTacToeToolName = 'resolve_tic_tac_toe_turn';

  String get _endpoint => '$_baseUrl/$_model:generateContent?key=$_apiKey';
  String get _audioEndpoint =>
      '$_baseUrl/$_audioModel:generateContent?key=$_apiKey';

  static const String _ticTacToeSystemPrompt =
      'You are Wunderbar TicTacToe, a bilingual (German/English) game host and opponent. '
      'You must always respond by calling the function resolve_tic_tac_toe_turn exactly once. '
      'No plain text output is allowed outside that function call. '
      'Given the user utterance and board state, infer intent and game move. '
      'Rules: player is X, assistant is O, indexes are 0..8 left-to-right top-to-bottom. '
      'Actions: player_move, reset_game, help, invalid. '
      'For player_move: include a legal playerMoveIndex for an empty cell, and choose a legal assistantMoveIndex for O if game is not over after the player move. '
      'Never choose occupied cells. Never skip assistantMoveIndex unless the player move immediately ends the game (win or draw). '
      'spokenResponse must be conversational and short. '
      'englishTranslation must always contain the English translation of spokenResponse. '
      'Use German if isGerman is true, otherwise English. '
      'If intent is unclear or does not sound like a move, set action to invalid and tell the user to spell it correctly.';

  static const String _pronunciationSystemPrompt =
      'You are a strict but helpful German pronunciation coach. '
      'You analyze a learner audio clip for one target German word. '
      'Your task is to compare the learner audio against the target word and target phonetic guide at phoneme level. '
      'Return only structured JSON. '
      'Focus on likely pronunciation evidence from the audio, but avoid inventing impossible certainty. '
      'Give an overall score from 0 to 100, concise coaching, phoneme-level notes, and one specific next attempt suggestion. '
      'Phoneme-level comments must be actionable and simple for a learner. '
      'For each phoneme, provide a short lipShape cue with practical mouth shape guidance, such as: '
      '"O: lips rounded and forward", "E: lips spread and relaxed", "A: mouth wide open, jaw dropped", '
      '"U: tight rounded lips", "Umlaut ö: rounded but less tight than o", "Umlaut ü: rounded lips with forward tongue", '
      '"Sch/ch: lips slightly rounded, airflow continuous". '
      'Also provide one short mouthShapeGuide summary for German vowels and common consonant clusters.';

  Future<String> ask(String userMessage) async {
    const systemPrompt =
        'You are a bubbly, warm, and incredibly patient German language friend. '
        'Always respond with exactly two lines: the natural German sentence first, '
        'followed by the English translation in parentheses on a new line. '
        'Be very friendly and proactive! If the user is quiet, ask what they have '
        'done since this morning or what they had for lunch. '
        'If they make a mistake, provide the correct version naturally and a '
        'tiny explanation in German (with English in brackets). '
        'Example response: "Was hast du heute zu Mittag gegessen? 😊\n'
        '(What did you eat for lunch today?)"';
    // 1. Correct Payload Structure
    final payload = {
      'contents': [
        {
          'role': 'user', // Required
          'parts': [
            {
              'text': userMessage,
            }, // System prompt is better handled in systemInstruction
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 400},
    };

    try {
      final data = await _postPayload(payload);
      final text = _extractFirstText(data);
      return text ?? 'Unexpected response format';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<TicTacToeTurnPlan> planTicTacToeTurn({
    required String userUtterance,
    required List<String> board,
    required bool isGameOver,
    required String? winner,
    required bool isGerman,
  }) async {
    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': _ticTacToeSystemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': jsonEncode({
                'userUtterance': userUtterance,
                'board': board,
                'isGameOver': isGameOver,
                'winner': winner,
                'isGerman': isGerman,
              }),
            },
          ],
        },
      ],
      'tools': [
        {
          'functionDeclarations': [
            {
              'name': _ticTacToeToolName,
              'description':
                  'Resolve the user turn intent and provide legal Tic-Tac-Toe moves plus a spoken response.',
              'parameters': {
                'type': 'OBJECT',
                'properties': {
                  'action': {
                    'type': 'STRING',
                    'enum': ['player_move', 'reset_game', 'help', 'invalid'],
                  },
                  'playerMoveIndex': {
                    'type': 'INTEGER',
                    'description':
                        'Index 0..8 for player X move. Required when action is player_move.',
                  },
                  'assistantMoveIndex': {
                    'type': 'INTEGER',
                    'description':
                        'Index 0..8 for assistant O move. Required for player_move unless game ends after player move.',
                  },
                  'spokenResponse': {
                    'type': 'STRING',
                    'description':
                        'Short conversational line for the app to speak to the user.',
                  },
                  'englishTranslation': {
                    'type': 'STRING',
                    'description':
                        'English translation of spokenResponse. If spokenResponse is already English, repeat it.',
                  },
                },
                'required': ['action', 'spokenResponse', 'englishTranslation'],
              },
            },
          ],
        },
      ],
      'toolConfig': {
        'functionCallingConfig': {
          'mode': 'ANY',
          'allowedFunctionNames': [_ticTacToeToolName],
        },
      },
      'generationConfig': {'temperature': 0.35, 'maxOutputTokens': 300},
    };

    final data = await _postPayload(payload);
    final functionArgs = _extractFunctionArgs(data, _ticTacToeToolName);
    if (functionArgs == null) {
      throw Exception('Gemini did not return $_ticTacToeToolName.');
    }

    return TicTacToeTurnPlan.fromFunctionArgs(functionArgs);
  }

  Future<PronunciationAnalysisReport> analyzePronunciationAudio({
    required String targetWord,
    required String targetEnglish,
    required String targetPhonetic,
    required String audioFilePath,
  }) async {
    final audioBytes = await File(audioFilePath).readAsBytes();
    if (audioBytes.isEmpty) {
      throw Exception('Recorded audio file is empty.');
    }

    final prompt =
        'Analyze this learner pronunciation recording for the German word "$targetWord". '
        'English meaning: "$targetEnglish". '
        'Target phonetic guide: "$targetPhonetic". '
        'Tasks: '
        '1. Estimate what the learner most likely said. '
        '2. Score pronunciation from 0 to 100. '
        '3. Identify strengths. '
        '4. Identify top issues. '
        '5. Provide phoneme-level feedback for the target pronunciation. '
        '6. Give one concise next attempt instruction. '
        '7. Include lip shape suggestions for each phoneme and a short overall mouth-shape guide. '
        'Be direct, short, and useful for a learner.';

    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': _pronunciationSystemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inlineData': {
                'mimeType': _audioMimeTypeForPath(audioFilePath),
                'data': base64Encode(audioBytes),
              },
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'overallScore': {'type': 'INTEGER'},
            'summary': {'type': 'STRING'},
            'heardText': {'type': 'STRING'},
            'mouthShapeGuide': {'type': 'STRING'},
            'strengths': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'priorities': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'nextTry': {'type': 'STRING'},
            'phonemeBreakdown': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'phoneme': {'type': 'STRING'},
                  'score': {'type': 'INTEGER'},
                  'lipShape': {'type': 'STRING'},
                  'observed': {'type': 'STRING'},
                  'issue': {'type': 'STRING'},
                  'suggestion': {'type': 'STRING'},
                },
                'required': [
                  'phoneme',
                  'score',
                  'lipShape',
                  'observed',
                  'issue',
                  'suggestion',
                ],
              },
            },
          },
          'required': [
            'overallScore',
            'summary',
            'heardText',
            'mouthShapeGuide',
            'strengths',
            'priorities',
            'nextTry',
            'phonemeBreakdown',
          ],
        },
      },
    };

    final data = await _postPayload(payload, endpoint: _audioEndpoint);
    final text = _extractFirstText(data);
    if (text == null || text.trim().isEmpty) {
      throw Exception('Gemini did not return a pronunciation analysis.');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'Gemini returned an invalid pronunciation analysis format.',
      );
    }

    return PronunciationAnalysisReport.fromMap(decoded);
  }

  Future<Map<String, dynamic>> _postPayload(
    Map<String, dynamic> payload, {
    String? endpoint,
  }) async {
    final response = await http.post(
      Uri.parse(endpoint ?? _endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Gemini request failed: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _audioMimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mp3';
    return 'audio/wav';
  }

  String? _extractFirstText(Map<String, dynamic> data) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) return null;

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    for (final part in parts) {
      if (part is Map<String, dynamic> && part['text'] is String) {
        return part['text'] as String;
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractFunctionArgs(
    Map<String, dynamic> data,
    String functionName,
  ) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) return null;

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final functionCall = part['functionCall'];
      if (functionCall is! Map<String, dynamic>) continue;
      if (functionCall['name'] != functionName) continue;

      final args = functionCall['args'];
      if (args is Map<String, dynamic>) {
        return args;
      }
    }

    return null;
  }
}
