import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/bread_shop_transaction.dart';
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

class BuddyDialogResponse {
  final String text;
  final Uint8List? audioBytes;
  final String? audioMimeType;
  final String? inputTranscription;
  final String? outputTranscription;

  const BuddyDialogResponse({
    required this.text,
    this.audioBytes,
    this.audioMimeType,
    this.inputTranscription,
    this.outputTranscription,
  });
}

class GeminiService {
  static const _model = 'gemini-2.5-flash-lite';
  static const _buddyModel = 'gemini-2.5-flash';
  static const _buddyLiveModel =
      'gemini-2.5-flash-native-audio-preview-12-2025';
  static const _audioModel = 'gemini-2.5-flash';
  static const _ticTacToeToolName = 'resolve_tic_tac_toe_turn';

  FirebaseAI get _ai => FirebaseAI.googleAI();

  LiveSession? _buddyLiveSession;
  StreamSubscription<Uint8List>? _buddyLiveAudioInputSub;
  bool _buddyLiveTurnInProgress = false;
  bool _buddyLiveReady = false;
  String? _buddyLiveLastError;
  int _buddyLiveSentAudioBytes = 0;
  int _buddyLiveSentAudioPackets = 0;
  final StreamController<void> _buddyLiveInterruptedController =
      StreamController<void>.broadcast();

  Stream<void> get buddyLiveInterruptedStream =>
      _buddyLiveInterruptedController.stream;
  bool get isBuddyLiveConnected => _buddyLiveSession != null && _buddyLiveReady;
  String? get buddyLiveLastError => _buddyLiveLastError;

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
      'ROLE: You are a World-Class German Phonetics Expert and Speech-Language Pathologist specializing in adult learner pronunciation correction.\n\n'
      'TASK: Conduct a rigorous phoneme-level analysis of the learner\'s audio recording against a target German word.\n\n'
      'GERMAN PHONETIC CONTEXT:\n'
      '- Vowels: a /a/, e /ɛ/, i /ɪ/, o /ɔ/, u /ʊ/ (plus long variants)\n'
      '- Umlauts: ä /ɛ/, ö /œ/, ü /ʏ/ (plus long variants ää /ɛː/, öö /œː/, üü /ʏː/)\n'
      '- Consonants: German has 20+ consonants; key: /x/ (ach-Laut), /ç/ (ich-Laut), /ŋ/ (ng), /ʃ/ (sch), /ʒ/, /tʃ/, /pf/\n'
      '- Aspiration: /p/, /t/, /k/ are aspirated at word start, unaspirated in clusters\n'
      '- Vowel Length: Marked by doubled vowel (Saat /zaːt/) or silent-h (Sehne /ˈzeːnə/); affects meaning (Gott vs. Gow)\n'
      '- Final Devoicing: /b,d,g,v,z/ become /p,t,k,f,s/ at word or syllable end (Rad → /raːt/)\n'
      '- Glottal Stop: Often used before vowel-initial syllables, especially after prefixes (ver-ändern)\n\n'
      'ANALYSIS FRAMEWORK:\n'
      '1. TRANSCRIPTION:\n'
      '   - Write EXACTLY what sounds you hear (phonemic representation).\n'
      '   - Mark stress with \'ˈ\' (primary) or \'ˌ\' (secondary).\n'
      '   - Note timing/rhythm issues and any schwa insertions.\n\n'
      '2. PHONEME-BY-PHONEME MAPPING:\n'
      '   - List each target phoneme with its observed realization.\n'
      '   - Mark status: correct, partial (minor deviation), or incorrect (wrong sound family).\n'
      '   - Flag vowel length errors, devoicing failures, or aspiration problems.\n\n'
      '3. ERROR DETECTION & Classification:\n'
      '   - Articulation errors: Wrong place/manner of articulation (e.g., /ʃ/ → /s/).\n'
      '   - Vowel quality: Relaxed vowel, tongue position wrong, rounding absent (e.g., /ʏ/ → /ɪ/).\n'
      '   - Vowel length: Target long, learner produced short (e.g., /zaːt/ → /zat/).\n'
      '   - Aspiration: Missing or excessive air on stop consonants.\n'
      '   - Prosody: Stress on wrong syllable, incorrect rhythm, unnatural intonation.\n'
      '   - German-specific: Failure to devoice finals, weak Umlaut rounding, dropped glottal stops.\n\n'
      '4. LIP SHAPE & ARTICULATION CUES:\n'
      '   - Vowel tips: "Lips spread wide (like smiling) for /e/", "Lips rounded and slightly protruded for /u/", "Tight O-shape with rounded lips for /ö/"\n'
      '   - Consonant tips: "Blow air continuously for /ʃ/", "Place tongue tip between teeth lightly for /θ/", "Drop jaw and open wide for /a/"\n'
      '   - Use vivid mouth-position descriptions for immediate learner application.\n\n'
      '5. SCORING LOGIC:\n'
      '   - overallScore: 0–100 based on intelligibility + phonetic accuracy.\n'
      '     - 90+: Native-like or near-native; minor nuances only.\n'
      '     - 75–89: Clear, mostly correct; 1–2 noticeable errors but word recognizable.\n'
      '     - 60–74: Comprehensible with context; multiple errors in vowels or key consonants.\n'
      '     - 40–59: Accented/strained; significant mispronunciations; occasional misunderstanding risk.\n'
      '     - Below 40: Hard to recognize; severe errors in vowel quality, consonant distortion, or stress.\n\n'
      'OUTPUT REQUIREMENTS:\n'
      '- Return ONLY a valid JSON object; no explanatory text outside the JSON block.\n'
      '- phonemeBreakdown array: One object per phoneme analyzed (in order of target word).\n'
      '- Each phoneme object MUST include: phoneme (IPA symbol), status (correct/incorrect/partial), observed (what was heard), lipShape (practical cue), tip (actionable guidance).\n'
      '- nextTryInstruction: A single, clear directive (1 sentence) for the learner\'s next attempt; prioritize the #1 error or prosodic issue.\n'
      '- heardText: Closest phonetic spelling or IPA representation of what was actually produced.\n'
      '- strengths and priorities: List of specific feedback items (never empty).\n'
      '- All JSON values must be non-empty strings or lists; no null values.';

  static const String _breadShopSystemPrompt =
      'ROLE: You are a friendly, charming German baker (Bäcker/Bäckerin) running a cozy bread and pastry shop in a quaint German town.\n\n'
      'SCENE: It\'s a warm Saturday morning. The shop smells of fresh-baked Brötchen and Kuchen. Warm sunlight streams through the window.\n'
      'Your display case is full: crusty Bauernbrot, fluffy Weizenbrot, sweet Brezel, delicate Macarons, and fruit-filled Torte.\n'
      'You are patient and good-natured, but firm on pricing. You negotiate a little, then hold a clear final price.\n\n'
      'AVAILABLE ITEMS (with standard prices in EUR):\n'
      '- Bauernbrot (Farmhouse Bread): €2.50\n'
      '- Brötchen (Bread Roll): €0.80\n'
      '- Weizenbrot (Wheat Bread): €3.00\n'
      '- Vollkornbrot (Whole Grain Bread): €2.80\n'
      '- Brezel (Pretzel): €1.20\n'
      '- Croissant: €1.50\n'
      '- Apfelstrudel (Apple Strudel): €3.50\n'
      '- Schwarzwälder Kirschtorte (Black Forest Cake): €4.50\n\n'
      'BUDGET GUARDRAILS (MANDATORY EVERY TURN):\n'
      '1. Compute Remaining_Balance = currentBudget - cartTotal before responding.\n'
      '2. You MUST verify affordability before every offer, acceptance, or counter-offer.\n'
      '3. Never return a function call where totalPrice exceeds Remaining_Balance or currentBudget.\n'
      '4. If customer cannot afford the requested item/quantity, use action=reject and explain briefly.\n\n'
      'CONSULTANT MODE (MANDATORY WHEN ASKED):\n'
      '- If customer asks "What can I buy?", "Was kann ich kaufen?", "I only have X left", "Ich habe nur X übrig", or similar:\n'
      '  → Act as a budget consultant.\n'
      '  → Read Remaining_Balance and suggest specific affordable items or combos from the price list.\n'
      '  → Use action=offer_item for these suggestions.\n'
      '  → Do NOT suggest any option whose total exceeds Remaining_Balance.\n\n'
      'STRICT NEGOTIATION CEILING:\n'
      '1. Define Minimum_Price = Standard_Price * 0.9 for each item.\n'
      '2. You must never set itemPrice below Minimum_Price.\n'
      '3. If customer asks below Minimum_Price, use action=reject.\n'
      '4. Use action=counter_offer ONLY when the customer explicitly asks for a discount/lower price.\n'
      '5. If customer does not ask for discount, do not use counter_offer.\n\n'
      'NEGOTIATION RULES:\n'
      '1. GREETING: Only greet if conversationHistory is EMPTY. Otherwise skip greeting.\n'
      '2. When customer requests items, confirm item, quantity, and price clearly.\n'
      '3. Small discounts (3-8%) may be offered for bulk orders (3+ items), but never beyond 10%.\n'
      '4. After one counter-offer on the same item, hold final price and reject lower bids.\n'
      '5. When a single item deal is agreed, use action=accept with dealAccepted=true.\n'
      '6. When customer is done, use action=complete_sale with dealAccepted=true.\n'
      '7. Do not suggest already purchased items unless user explicitly asks again.\n\n'
      'ACTION LOGIC (STRICT):\n'
      '- offer_item: For normal offers, confirmations, and budget-based suggestions/combos.\n'
      '- counter_offer: ONLY when user asks for a discount and your price remains >= Minimum_Price and affordable.\n'
      '- reject: Use when user offer is below Minimum_Price OR requested total is not affordable OR repeated pressure below your final price.\n'
      '- accept: Use when customer accepts your last valid offer for one item.\n'
      '- complete_sale: Use when customer ends shopping.\n\n'
      'SCHEMA CONSISTENCY RULES:\n'
      '- totalPrice MUST equal itemPrice * quantity (final negotiated unit price times quantity).\n'
      '- totalPrice MUST be <= Remaining_Balance and <= currentBudget.\n'
      '- For reject with no item sold, set dealAccepted=false and keep prices aligned with the rejected proposal context.\n'
      '- Do not invent unavailable items or prices not grounded in the list and rules above.\n\n'
      'CONTEXT AWARENESS (CRITICAL):\n'
      '- Always read conversationHistory carefully before responding.\n'
      '- Acceptance phrases (e.g., "Einverstanden", "Abgemacht", "Deal", "I\'ll take it") should map to action=accept using the most recent valid offered item and price.\n'
      '- Pronouns like "it", "das", "die" refer to the latest relevant offered item in conversationHistory.\n\n'
      'LANGUAGE & STYLE:\n'
      '- Always respond in German first, then English translation.\n'
      '- Use warm, friendly tone: "Was darf es sein?", "Das ist eine ausgezeichnete Wahl!", "Möchten Sie noch etwas?"\n'
      '- Keep responses conversational and short (1-2 sentences per turn).\n'
      '- Be polite but firm when the final price is reached.\n\n'
      'OUTPUT: Return ONLY valid JSON. No text outside the JSON block.';

  static const String _buddySystemPrompt =
      'You are Buddy, a friendly German language tutor.\n\n'
      '=== OUTPUT FORMATS ===\n\n'
      'FORMAT A — Plain conversation (default for simple replies):\n'
      'Line 1: German response (natural, conversational).\n'
      'Line 2: English translation of line 1.\n'
      'No extra lines. No markers.\n\n'
      'FORMAT B — Structured output (REQUIRED when any of the following apply):\n'
      '  • The user asks for a table, list, comparison, chart, steps, vocabulary set, or grouped data.\n'
      '  • The answer is naturally tabular (e.g. word genders, verb conjugations, price lists, schedules).\n'
      '  • Showing data in a table would make it clearer than prose.\n'
      'When FORMAT B applies, reply using EXACTLY these markers:\n'
      '[German]\n'
      '<German content in GitHub-Flavored Markdown>\n'
      '[English]\n'
      '<English translation of the same content in GitHub-Flavored Markdown>\n\n'
      'TABLE RULES (always apply inside FORMAT B tables):\n'
      '  • Use GFM table syntax: header row, separator row (---|---), then data rows.\n'
      '  • Every column must have a header.\n'
      '  • Align separators with column widths for readability.\n'
      '  • Do not wrap tables in code fences.\n\n'
      'STRICT RULES:\n'
      '  • Never add text before [German] or after the English section.\n'
      '  • If the user writes in English, still reply in German first, then translate.\n'
      '  • No greetings preamble, no meta-commentary, no "Here is your table:" labels.\n'
      '  • Stay warm, encouraging, and concise.';

  Future<String> ask(
    String userMessage, [
    String? systemPrompt,
    bool forceJsonResponse = false,
  ]) async {
    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : _buddySystemPrompt;

    try {
      final model = _ai.generativeModel(
        model: _model,
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
        : _buddySystemPrompt;

    try {
      final model = _ai.generativeModel(
        model: _buddyModel,
        systemInstruction: Content.system(prompt),
        generationConfig: GenerationConfig(
          temperature: 0.2,
          maxOutputTokens: 500,
          responseModalities: const [
            ResponseModalities.text,
            ResponseModalities.audio,
          ],
        ),
      );

      final response = await model.generateContent([Content.text(userMessage)]);
      final text = response.text;
      final audioPart = response.inlineDataParts
          .where((p) {
            return p.mimeType.startsWith('audio/');
          })
          .cast<InlineDataPart?>()
          .firstWhere((p) => p != null, orElse: () => null);

      if (text != null && text.trim().isNotEmpty) {
        return BuddyDialogResponse(
          text: text,
          audioBytes: audioPart?.bytes,
          audioMimeType: audioPart?.mimeType,
        );
      }
      return BuddyDialogResponse(
        text: 'Unexpected response format',
        audioBytes: audioPart?.bytes,
        audioMimeType: audioPart?.mimeType,
      );
    } catch (_) {
      // If the native-audio-dialog model/region is unavailable, fall back to the
      // existing text model so Buddy remains usable.
      return BuddyDialogResponse(text: await ask(userMessage, prompt));
    }
  }

  Future<void> startBuddyLiveSession([String? systemPrompt]) async {
    if (isBuddyLiveConnected) return;

    await closeBuddyLiveSession();

    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : _buddySystemPrompt;

    final liveModel = _ai.liveGenerativeModel(
      model: _buddyLiveModel,
      systemInstruction: Content.system(prompt),
      liveGenerationConfig: LiveGenerationConfig(
        responseModalities: const [ResponseModalities.audio],
        speechConfig: SpeechConfig(voiceName: 'Aoede'),
        inputAudioTranscription: AudioTranscriptionConfig(),
        outputAudioTranscription: AudioTranscriptionConfig(),
        temperature: 0.2,
        maxOutputTokens: 500,
      ),
    );

    try {
      _buddyLiveSession = await liveModel.connect();
      _buddyLiveLastError = null;
      _buddyLiveReady = true;
    } catch (e) {
      _buddyLiveLastError = 'Buddy live connect failed: $e';
      _buddyLiveSession = null;
      _buddyLiveReady = false;
      rethrow;
    }
  }

  Future<void> closeBuddyLiveSession() async {
    await _buddyLiveAudioInputSub?.cancel();
    _buddyLiveAudioInputSub = null;

    _buddyLiveReady = false;
    _buddyLiveTurnInProgress = false;

    await _buddyLiveSession?.close();
    _buddyLiveSession = null;
  }

  Future<BuddyDialogResponse> askBuddyLive(
    String userMessage, [
    String? systemPrompt,
  ]) async {
    try {
      await startBuddyLiveSession(systemPrompt);

      final session = _buddyLiveSession;
      if (session == null || !_buddyLiveReady) {
        return askBuddy(userMessage, systemPrompt);
      }

      if (_buddyLiveTurnInProgress) {
        return askBuddy(userMessage, systemPrompt);
      }

      _buddyLiveTurnInProgress = true;
      try {
        await session.sendTextRealtime(userMessage);
        await session.send(turnComplete: true);
        return await _collectBuddyLiveTurnResponse(session).timeout(
          const Duration(seconds: 35),
          onTimeout: () {
            _buddyLiveLastError = 'Buddy live text turn timed out.';
            return const BuddyDialogResponse(
              text: 'Unexpected response format',
            );
          },
        );
      } finally {
        _buddyLiveTurnInProgress = false;
      }
    } catch (e) {
      _buddyLiveLastError = 'Buddy live text turn failed: $e';
      await closeBuddyLiveSession();
      return askBuddy(userMessage, systemPrompt);
    }
  }

  Future<void> startBuddyLiveAudioTurn(
    Stream<Uint8List> audioStream, {
    int sampleRateHz = 16000,
    String? systemPrompt,
  }) async {
    await startBuddyLiveSession(systemPrompt);

    final session = _buddyLiveSession;
    if (session == null || !_buddyLiveReady) {
      throw StateError('Buddy live session is not ready.');
    }
    if (_buddyLiveTurnInProgress) {
      throw StateError('Buddy live turn already in progress.');
    }

    _buddyLiveTurnInProgress = true;
    _buddyLiveSentAudioBytes = 0;
    _buddyLiveSentAudioPackets = 0;
    debugPrint(
      '[BuddyLive] start audio turn sampleRateHz=$sampleRateHz ready=$_buddyLiveReady',
    );
    var isFirstChunk = true;
    await _buddyLiveAudioInputSub?.cancel();
    _buddyLiveAudioInputSub = audioStream.listen(
      (chunk) {
        if (chunk.isEmpty) return;

        final prepared = _prepareLivePcmChunk(
          chunk,
          sampleRateHz: sampleRateHz,
          isFirstChunk: isFirstChunk,
        );
        isFirstChunk = false;
        if (prepared == null || prepared.isEmpty) return;

        // Forward each recorder chunk directly (same pattern as Firebase sample).
        _buddyLiveSentAudioPackets += 1;
        _buddyLiveSentAudioBytes += prepared.length;
        unawaited(
          session
              .sendAudioRealtime(InlineDataPart('audio/pcm', prepared))
              .catchError((error) {
                _buddyLiveLastError =
                    'Buddy live audio chunk send failed (sampleRateHz=$sampleRateHz): $error';
                _buddyLiveReady = false;
                debugPrint('[BuddyLive] $_buddyLiveLastError');
              }),
        );
      },
      onError: (error) {
        _buddyLiveLastError = 'Buddy live audio stream failed: $error';
        _buddyLiveReady = false;
        debugPrint('[BuddyLive] $_buddyLiveLastError');
      },
      cancelOnError: false,
    );
  }

  Future<BuddyDialogResponse> finishBuddyLiveAudioTurn() async {
    final session = _buddyLiveSession;
    if (!_buddyLiveTurnInProgress || session == null) {
      _buddyLiveLastError =
          'Buddy live audio turn finished without an active session.';
      return const BuddyDialogResponse(text: '');
    }

    try {
      await _buddyLiveAudioInputSub?.cancel();
      _buddyLiveAudioInputSub = null;

      await session.send(turnComplete: true);
      var reply = await _collectBuddyLiveTurnResponse(session).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          _buddyLiveLastError = 'Buddy live audio turn timed out.';
          return const BuddyDialogResponse(text: '');
        },
      );

      final isEmptyTurn =
          reply.text.trim().isEmpty &&
          (reply.audioBytes == null || reply.audioBytes!.isEmpty) &&
          (reply.inputTranscription ?? '').trim().isEmpty &&
          (reply.outputTranscription ?? '').trim().isEmpty;
      if (isEmptyTurn && _buddyLiveSentAudioBytes > 0) {
        debugPrint(
          '[BuddyLive] empty audio turn; sending one-shot text nudge fallback.',
        );
        await session.sendTextRealtime(
          'Please reply now with one short German sentence and one short English translation.',
        );
        await session.send(turnComplete: true);
        final nudgedReply = await _collectBuddyLiveTurnResponse(session).timeout(
          const Duration(seconds: 20),
          onTimeout: () {
            _buddyLiveLastError =
                'Buddy live nudge fallback timed out after empty audio turn.';
            return const BuddyDialogResponse(text: '');
          },
        );
        final nudgedHasContent =
            nudgedReply.text.trim().isNotEmpty ||
            (nudgedReply.audioBytes != null && nudgedReply.audioBytes!.isNotEmpty) ||
            (nudgedReply.outputTranscription ?? '').trim().isNotEmpty;
        if (nudgedHasContent) {
          _buddyLiveLastError = null;
          reply = nudgedReply;
        }
      } else if (isEmptyTurn && _buddyLiveSentAudioBytes == 0) {
        _buddyLiveLastError =
            'No microphone audio bytes were sent during the live turn.';
      }

      debugPrint(
        '[BuddyLive] finish audio turn '
        'sentPackets=$_buddyLiveSentAudioPackets '
        'sentBytes=$_buddyLiveSentAudioBytes '
        'textLen=${reply.text.length} '
        'audioBytes=${reply.audioBytes?.length ?? 0} '
        'inputTxLen=${reply.inputTranscription?.length ?? 0} '
        'outputTxLen=${reply.outputTranscription?.length ?? 0} '
        'lastError=${_buddyLiveLastError ?? 'none'}',
      );
      return reply;
    } catch (e) {
      _buddyLiveLastError = 'Buddy live audio turn failed: $e';
      debugPrint('[BuddyLive] $_buddyLiveLastError');
      await closeBuddyLiveSession();
      rethrow;
    } finally {
      _buddyLiveTurnInProgress = false;
    }
  }

  Future<void> cancelBuddyLiveAudioTurn() async {
    await _buddyLiveAudioInputSub?.cancel();
    _buddyLiveAudioInputSub = null;
    _buddyLiveTurnInProgress = false;
  }

  Future<TicTacToeTurnPlan> planTicTacToeTurn({
    required String userUtterance,
    required List<String> board,
    required bool isGameOver,
    required String? winner,
    required bool isGerman,
  }) async {
    final model = _ai.generativeModel(
      model: _model,
      systemInstruction: Content.system(_ticTacToeSystemPrompt),
      tools: [
        Tool.functionDeclarations([
          FunctionDeclaration(
            _ticTacToeToolName,
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
        functionCallingConfig: FunctionCallingConfig.any({_ticTacToeToolName}),
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
    final functionArgs = _extractFunctionArgsFromResponse(
      response,
      _ticTacToeToolName,
    );
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

    final model = _ai.generativeModel(
      model: _audioModel,
      systemInstruction: Content.system(_pronunciationSystemPrompt),
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

  Future<BreadShopNegotiation> negotiateBreadShop({
    required String userUtterance,
    required double currentBudgetEur,
    required List<String> purchasedItems,
    required double currentCartTotalEur,
    required bool isGerman,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    const functionName = 'negotiate_bread_shop';

    final model = _ai.generativeModel(
      model: _model,
      systemInstruction: Content.system(_breadShopSystemPrompt),
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
        _extractFunctionArgsFromResponse(response, functionName) ??
        _extractBreadShopArgsFromText(response.text);
    if (functionArgs == null) {
      throw Exception(
        'Baker did not return a valid negotiation response. Please try again.',
      );
    }

    return BreadShopNegotiation.fromFunctionArgs(functionArgs);
  }

  Map<String, dynamic>? _extractBreadShopArgsFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic> && decoded['action'] != null) {
        return decoded;
      }
    } catch (_) {
      // Try markdown-wrapped or mixed text output.
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match == null) return null;
      final candidate = match.group(0);
      if (candidate == null) return null;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic> && decoded['action'] != null) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  Map<String, dynamic>? _extractFunctionArgsFromResponse(
    GenerateContentResponse response,
    String functionName,
  ) {
    for (final call in response.functionCalls) {
      if (call.name != functionName) continue;
      final normalized = <String, dynamic>{};
      call.args.forEach((key, value) {
        normalized[key] = value;
      });
      return normalized;
    }
    return null;
  }

  Future<BuddyDialogResponse> _collectBuddyLiveTurnResponse(
    LiveSession session,
  ) async {
    final audioBuilder = BytesBuilder(copy: false);
    final textBuffer = StringBuffer();
    final inputTranscriptionBuffer = StringBuffer();
    final outputTranscriptionBuffer = StringBuffer();

    await for (final response in session.receive()) {
      final message = response.message;

      if (message is GoingAwayNotice) {
        _buddyLiveLastError =
            'Buddy live session is ending soon (timeLeft: ${message.timeLeft ?? 'n/a'}).';
      }

      if (message is! LiveServerContent) continue;

      if (message.interrupted == true) {
        _buddyLiveInterruptedController.add(null);
      }

      final inputText = (message.inputTranscription?.text ?? '').trim();
      if (inputText.isNotEmpty) {
        inputTranscriptionBuffer.write(inputText);
      }

      final outputText = (message.outputTranscription?.text ?? '').trim();
      if (outputText.isNotEmpty) {
        outputTranscriptionBuffer.write(outputText);
      }

      final modelTurn = message.modelTurn;
      if (modelTurn == null) continue;

      for (final part in modelTurn.parts) {
        if (part is TextPart && part.text.trim().isNotEmpty) {
          textBuffer.write(part.text);
          continue;
        }

        if (part is InlineDataPart && part.mimeType.startsWith('audio/')) {
          if (part.bytes.isNotEmpty) {
            audioBuilder.add(part.bytes);
          }
        }
      }
    }

    final audioBytes = audioBuilder.takeBytes();
    final inputTranscription = inputTranscriptionBuffer.toString().trim();
    final outputTranscription = outputTranscriptionBuffer.toString().trim();
    final text = textBuffer.toString().trim();
    final hasAudio = audioBytes.isNotEmpty;
    String resolvedText = '';
    if (text.isNotEmpty) {
      resolvedText = text;
    } else if (outputTranscription.isNotEmpty) {
      resolvedText = outputTranscription;
    } else if (!hasAudio) {
      _buddyLiveLastError =
          _buddyLiveLastError ?? 'Buddy live returned an empty turn.';
    }

    debugPrint(
      '[BuddyLive] collected response '
      'textLen=${text.length} '
      'audioBytes=${audioBytes.length} '
      'inputTxLen=${inputTranscription.length} '
      'outputTxLen=${outputTranscription.length}',
    );

    return BuddyDialogResponse(
      text: resolvedText,
      audioBytes: audioBytes.isEmpty ? null : audioBytes,
      audioMimeType: audioBytes.isEmpty ? null : 'audio/pcm',
      inputTranscription: inputTranscription.isEmpty
          ? null
          : inputTranscription,
      outputTranscription: outputTranscription.isEmpty
          ? null
          : outputTranscription,
    );
  }

  Uint8List? _prepareLivePcmChunk(
    Uint8List raw, {
    required int sampleRateHz,
    required bool isFirstChunk,
  }) {
    var bytes = raw;

    if (isFirstChunk && _looksLikeWav(bytes)) {
      if (bytes.length <= 44) return null;
      bytes = Uint8List.sublistView(bytes, 44);
    }

    if (_looksLikeUnsupportedAudioContainer(bytes)) {
      _buddyLiveLastError =
          'Buddy live audio stream appears encoded/containerized, but Gemini Live expects raw PCM16. sampleRateHz=$sampleRateHz';
      return null;
    }

    // PCM16 must be aligned to 2-byte samples.
    if (bytes.length.isOdd) {
      if (bytes.length <= 1) return null;
      bytes = Uint8List.sublistView(bytes, 0, bytes.length - 1);
    }

    return bytes;
  }

  bool _looksLikeWav(Uint8List bytes) {
    if (bytes.length < 12) return false;
    return bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x41 &&
        bytes[10] == 0x56 &&
        bytes[11] == 0x45;
  }

  bool _looksLikeUnsupportedAudioContainer(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // OGG/Opus
    final isOgg =
        bytes[0] == 0x4F &&
        bytes[1] == 0x67 &&
        bytes[2] == 0x67 &&
        bytes[3] == 0x53;
    if (isOgg) return true;

    // ADTS AAC (syncword 0xFFFx)
    if (bytes.length >= 2) {
      final isAdts = bytes[0] == 0xFF && (bytes[1] & 0xF0) == 0xF0;
      if (isAdts) return true;
    }

    return false;
  }

  Future<void> disposeBuddyLive() async {
    await cancelBuddyLiveAudioTurn();
    await closeBuddyLiveSession();
    await _buddyLiveInterruptedController.close();
  }
}
