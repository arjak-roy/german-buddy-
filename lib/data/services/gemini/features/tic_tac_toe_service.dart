import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../core/gemini_ai_client.dart';
import '../core/gemini_models.dart';
import '../models/tic_tac_toe_turn_plan.dart';
import '../prompts/system_prompts.dart';
import '../utils/function_call_utils.dart';

class GeminiTicTacToeService {
  GeminiTicTacToeService({GeminiAiClient? aiClient})
    : _aiClient = aiClient ?? GeminiAiClient();

  static const String _toolName = 'resolve_tic_tac_toe_turn';
  final GeminiAiClient _aiClient;

  Future<TicTacToeTurnPlan> planTurn({
    required String userUtterance,
    required List<String> board,
    required bool isGameOver,
    required String? winner,
    required bool isGerman,
  }) async {
    final model = _aiClient.ai.generativeModel(
      model: GeminiModels.model,
      systemInstruction: Content.system(GeminiSystemPrompts.ticTacToe),
      tools: [
        Tool.functionDeclarations([
          FunctionDeclaration(
            _toolName,
            'Resolve the user turn intent and provide legal Tic-Tac-Toe moves plus a spoken response.',
            parameters: {
              'action': Schema.enumString(
                enumValues: ['player_move', 'reset_game', 'help', 'invalid'],
              ),
              'playerMoveIndex': Schema.integer(
                description:
                    'Index 0..8 for player X move. Required when action is player_move.',
              ),
              'assistantMoveIndex': Schema.integer(
                description:
                    'Index 0..8 for assistant O move. Required for player_move unless game ends after player move.',
              ),
              'spokenResponse': Schema.string(
                description:
                    'Short conversational line for the app to speak to the user.',
              ),
              'englishTranslation': Schema.string(
                description:
                    'English translation of spokenResponse. If spokenResponse is already English, repeat it.',
              ),
            },
            optionalParameters: const ['playerMoveIndex', 'assistantMoveIndex'],
          ),
        ]),
      ],
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig.any({_toolName}),
      ),
      generationConfig: GenerationConfig(
        temperature: 0.35,
        maxOutputTokens: 300,
      ),
    );

    final promptJson = jsonEncode({
      'userUtterance': userUtterance,
      'board': board,
      'isGameOver': isGameOver,
      'winner': winner,
      'isGerman': isGerman,
    });

    final response = await model.generateContent([Content.text(promptJson)]);
    final functionArgs = extractFunctionArgsFromResponse(response, _toolName);
    if (functionArgs == null) {
      throw Exception('Gemini did not return $_toolName.');
    }

    return TicTacToeTurnPlan.fromFunctionArgs(functionArgs);
  }
}
