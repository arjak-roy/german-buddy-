import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../models/bread_shop_transaction.dart';
import '../core/gemini_ai_client.dart';
import '../core/gemini_models.dart';
import '../prompts/system_prompts.dart';
import '../utils/function_call_utils.dart';

class GeminiBreadShopService {
  GeminiBreadShopService({GeminiAiClient? aiClient})
    : _aiClient = aiClient ?? GeminiAiClient();

  final GeminiAiClient _aiClient;

  Future<BreadShopNegotiation> negotiate({
    required String userUtterance,
    required double currentBudgetEur,
    required List<String> purchasedItems,
    required double currentCartTotalEur,
    required bool isGerman,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    const functionName = 'negotiate_bread_shop';

    final model = _aiClient.ai.generativeModel(
      model: GeminiModels.model,
      systemInstruction: Content.system(GeminiSystemPrompts.breadShop),
      tools: [
        Tool.functionDeclarations([
          FunctionDeclaration(
            functionName,
            'Handle bakery negotiation with strict budget checks. Compute Remaining_Balance = currentBudget - cartTotal, enforce minimum price (90% of standard), suggest affordable items with offer_item, use counter_offer only for discount requests, reject unaffordable or below-floor offers, and keep German response plus English translation.',
            parameters: {
              'action': Schema.enumString(
                enumValues: [
                  'offer_item',
                  'counter_offer',
                  'accept',
                  'reject',
                  'complete_sale',
                ],
              ),
              'item': Schema.string(),
              'itemPrice': Schema.number(minimum: 0),
              'quantity': Schema.integer(minimum: 1),
              'totalPrice': Schema.number(minimum: 0),
              'shopkeeperResponse': Schema.string(),
              'englishTranslation': Schema.string(),
              'dealAccepted': Schema.boolean(),
            },
          ),
        ]),
      ],
      toolConfig: ToolConfig(
        functionCallingConfig: FunctionCallingConfig.any({functionName}),
      ),
      generationConfig: GenerationConfig(
        temperature: 0.5,
        maxOutputTokens: 350,
      ),
    );

    final promptJson = jsonEncode({
      'conversationHistory': conversationHistory,
      'userUtterance': userUtterance,
      'currentBudget': currentBudgetEur,
      'purchasedItems': purchasedItems,
      'cartTotal': currentCartTotalEur,
      'isGerman': isGerman,
    });

    final response = await model.generateContent([Content.text(promptJson)]);
    final functionArgs =
        extractFunctionArgsFromResponse(response, functionName) ??
        _extractBreadShopArgsFromText(response.text);
    if (functionArgs == null) {
      throw Exception(
        'Baker did not return a valid negotiation response. Please try again.',
      );
    }

    return BreadShopNegotiation.fromFunctionArgs(functionArgs);
  }

  Map<String, dynamic>? _extractBreadShopArgsFromText(String? text) {
    final decoded = extractJsonArgsFromText(text);
    if (decoded == null) return null;
    if (decoded['action'] == null) return null;
    return decoded;
  }
}
