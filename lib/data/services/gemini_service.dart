import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _apiKey = 'AIzaSyCqctOY_BBPX3deLwT2jWq9IQP_GHeCuW8'; // Use Flutter Dotenv for MVP speed
  static const _model = 'gemini-3.1-flash-lite-preview'; // Note: check current available models
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  String get _endpoint => '$_baseUrl/$_model:generateContent?key=$_apiKey';

  Future<String> ask(String userMessage) async {
    const systemPrompt = 
        'You are a helpful and patient German language trainer. '
        'Always respond with two lines: first the correct German sentence, '
        'then a newline with the English translation (you may wrap it in '
        'parentheses). Do not include any extra commentary. '
        'Correct the user politely and provide explanations in German '
        'with brief English translations. Keep answers concise.'
        ' For example, if the user says "Ich bin hungrig", you might respond: "Ich habe Hunger.\n(I am hungry.)"'
        ;

    // 1. Correct Payload Structure
    final payload = {
      'contents': [
        {
          'role': 'user', // Required
          'parts': [
            {'text': userMessage} // System prompt is better handled in systemInstruction
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 400,
      }
    };

    try {
      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        throw Exception('Gemini request failed: ${response.body}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      // 2. Correct Response Parsing
      // Path: candidates[0] -> content -> parts[0] -> text
      if (data.containsKey('candidates') && data['candidates'].isNotEmpty) {
        final candidate = data['candidates'][0];
        if (candidate.containsKey('content') && 
            candidate['content']['parts'] != null && 
            candidate['content']['parts'].isNotEmpty) {
          
          return candidate['content']['parts'][0]['text'] ?? 'No text found';
        }
      }
      
      return 'Unexpected response format';
    } catch (e) {
      return 'Error: $e';
    }
  }
}