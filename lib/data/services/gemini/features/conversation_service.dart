import 'package:firebase_ai/firebase_ai.dart';

import '../core/gemini_ai_client.dart';
import '../core/gemini_models.dart';
import '../models/buddy_dialog_response.dart';
import '../prompts/system_prompts.dart';

class GeminiConversationService {
  GeminiConversationService({GeminiAiClient? aiClient})
    : _aiClient = aiClient ?? GeminiAiClient();

  final GeminiAiClient _aiClient;

  Future<String> ask(
    String userMessage, [
    String? systemPrompt,
    bool forceJsonResponse = false,
  ]) async {
    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : GeminiSystemPrompts.buddy;

    try {
      final model = _aiClient.ai.generativeModel(
        model: GeminiModels.model,
        systemInstruction: Content.system(prompt),
        generationConfig: GenerationConfig(
          temperature: 0.1,
          maxOutputTokens: 2048,
          responseMimeType: forceJsonResponse ? 'application/json' : null,
        ),
      );

      final response = await model.generateContent([Content.text(userMessage)]);
      final text = response.text;
      return (text == null || text.trim().isEmpty)
          ? 'Unexpected response format'
          : text;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<BuddyDialogResponse> askBuddy(
    String userMessage, [
    String? systemPrompt,
  ]) async {
    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : GeminiSystemPrompts.buddy;

    try {
      final model = _aiClient.ai.generativeModel(
        model: GeminiModels.buddyModel,
        systemInstruction: Content.system(prompt),
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 500,
          responseModalities: const [ResponseModalities.text],
        ),
      );

      final response = await model.generateContent([Content.text(userMessage)]);
      final text = response.text;

      if (text != null && text.trim().isNotEmpty) {
        return BuddyDialogResponse(text: text);
      }

      return const BuddyDialogResponse(text: 'Unexpected response format');
    } catch (_) {
      return BuddyDialogResponse(text: await ask(userMessage, prompt));
    }
  }
}
