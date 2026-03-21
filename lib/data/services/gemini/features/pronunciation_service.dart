import 'dart:convert';
import 'dart:io';

import 'package:firebase_ai/firebase_ai.dart';

import '../../../models/pronunciation_analysis_report.dart';
import '../core/gemini_ai_client.dart';
import '../core/gemini_models.dart';
import '../prompts/system_prompts.dart';

class GeminiPronunciationService {
  GeminiPronunciationService({GeminiAiClient? aiClient})
    : _aiClient = aiClient ?? GeminiAiClient();

  final GeminiAiClient _aiClient;

  Future<PronunciationAnalysisReport> analyzeAudio({
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
        'TARGET WORD: "$targetWord"\n'
        'English meaning: "$targetEnglish"\n'
        'Expected IPA/Phonetic Guide: "$targetPhonetic"\n\n'
        'ANALYSIS INSTRUCTIONS:\n'
        '1. Listen carefully to the full audio recording.\n'
        '2. Transcribe phonetically (in IPA notation) exactly what you hear the learner say.\n'
        '3. For each phoneme in the TARGET word, compare what was EXPECTED vs. what was OBSERVED.\n'
        '4. Classify each phoneme as: correct (matches target), partial (minor deviation, still intelligible), or incorrect (wrong sound/category).\n'
        '5. Identify the top pronunciation issue (vowel quality, consonant distortion, length error, aspiration, stress, or rhythm).\n'
        '6. Provide a highly specific lip-shape/articulation cue for the learner\'s next attempt.\n'
        '7. Score overall intelligibility: How easily would a native speaker understand this word? (0=unintelligible, 100=native-like)\n\n'
        'COMMON GERMAN LEARNER ERRORS TO LISTEN FOR:\n'
        '- Failure to round lips for /ö/, /ü/ (sounds like /e/ or /i/ instead)\n'
        '- Confusing /ç/ (ich-Laut) with /k/ or /x/ (ach-Laut)\n'
        '- Not devoicing final consonants (/d/ sounds like /d/ instead of /t/)\n'
        '- Incorrect vowel length (short when should be long, or vice versa)\n'
        '- Weak aspiration or over-aspiration on /p/, /t/, /k/\n'
        '- Stress on wrong syllable, especially in compound words\n'
        '- Schwa insertion in unstressed syllables\n\n'
        'OUTPUT: Respond with ONLY a valid JSON object matching the specified schema.';

    final model = _aiClient.ai.generativeModel(
      model: GeminiModels.audioModel,
      systemInstruction: Content.system(GeminiSystemPrompts.pronunciation),
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        responseSchema: Schema.object(
          properties: {
            'overallScore': Schema.integer(description: 'Score from 0-100'),
            'heardText': Schema.string(
              description: 'The literal transcription of what was heard',
            ),
            'phonemeBreakdown': Schema.array(
              items: Schema.object(
                properties: {
                  'phoneme': Schema.string(description: 'IPA symbol'),
                  'status': Schema.enumString(
                    enumValues: ['correct', 'incorrect', 'partial'],
                    description: 'Whether the phoneme was pronounced correctly',
                  ),
                  'observed': Schema.string(
                    description: 'What sound was actually made',
                  ),
                  'lipShape': Schema.string(
                    description: 'Specific physical cue for mouth positioning',
                  ),
                  'tip': Schema.string(description: 'Short friendly advice'),
                },
              ),
            ),
            'strengths': Schema.array(items: Schema.string()),
            'priorities': Schema.array(items: Schema.string()),
            'nextTryInstruction': Schema.string(
              description: 'One sentence for the user to improve',
            ),
          },
        ),
      ),
    );

    final response = await model.generateContent([
      Content.multi([
        InlineDataPart(_audioMimeTypeForPath(audioFilePath), audioBytes),
        TextPart(prompt),
      ]),
    ]);

    final text = response.text;
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

  String _audioMimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg') || lower.endsWith('.opus')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mp3';
    return 'audio/wav';
  }
}
