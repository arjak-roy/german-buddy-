import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';

import 'package:http/http.dart' as http;

import '../../core/constants/app_keys.dart';
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

  const BuddyDialogResponse({
    required this.text,
    this.audioBytes,
    this.audioMimeType,
  });
}

class GeminiService {
  static const _model =
      'gemini-3.1-flash-lite-preview'; // Note: check current available models
  static const _buddyModel = 'gemini-2.5-flash-preview-native-audio-dialog';
  static const _audioModel = 'gemini-3-flash-preview';
    static const _buddyLiveModel = 'gemini-2.5-flash-native-audio-preview-12-2025';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
    static const _baseLiveWsUrl =
      'wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent';
  static const _ticTacToeToolName = 'resolve_tic_tac_toe_turn';

  String get _endpoint =>
    '$_baseUrl/$_model:generateContent?key=${AppKeys.geminiApiKey}';
  String get _buddyEndpoint =>
    '$_baseUrl/$_buddyModel:generateContent?key=${AppKeys.geminiApiKey}';
  String get _audioEndpoint =>
    '$_baseUrl/$_audioModel:generateContent?key=${AppKeys.geminiApiKey}';
  String get _buddyLiveEndpoint =>
      '$_baseLiveWsUrl?key=${AppKeys.geminiApiKey}';

  WebSocket? _buddyLiveSocket;
  StreamSubscription<dynamic>? _buddyLiveSocketSub;
  bool _buddyLiveReady = false;
  String? _buddyLiveLastError;
  bool? _buddyLiveModelAvailable;
  Completer<void>? _buddyLiveSetupCompleter;
  Completer<BuddyDialogResponse>? _buddyLivePending;
  BytesBuilder? _buddyLiveAudioBuilder;
  StringBuffer? _buddyLiveTextBuffer;

  void _debugLive(String message) {
    assert(() {
      // ignore: avoid_print
      print('[BuddyLive] $message');
      return true;
    }());
  }

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

  Future<String> ask(String userMessage, [String? systemPrompt]) async {
    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : _buddySystemPrompt;
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
          {'text': prompt},
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

  Future<BuddyDialogResponse> askBuddy(
    String userMessage, [
    String? systemPrompt,
  ]) async {
    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : _buddySystemPrompt;

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage},
          ],
        },
      ],
      'systemInstruction': {
        'parts': [
          {'text': prompt},
        ],
      },
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 500,
        'responseModalities': ['TEXT', 'AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': 'Aoede'}
          }
        },
      },
    };

    try {
      final data = await _postPayload(payload, endpoint: _buddyEndpoint);
      final text = _extractFirstText(data);
      final audio = _extractFirstInlineAudio(data);

      if (text != null && text.trim().isNotEmpty) {
        return BuddyDialogResponse(
          text: text,
          audioBytes: audio?.bytes,
          audioMimeType: audio?.mimeType,
        );
      }
      return BuddyDialogResponse(
        text: 'Unexpected response format',
        audioBytes: audio?.bytes,
        audioMimeType: audio?.mimeType,
      );
    } catch (_) {
      // If the native-audio-dialog model/region is unavailable, fall back to the
      // existing text model so Buddy remains usable.
      return BuddyDialogResponse(text: await ask(userMessage, prompt));
    }
  }

  bool get isBuddyLiveConnected => _buddyLiveSocket != null && _buddyLiveReady;
  String? get lastBuddyLiveError => _buddyLiveLastError;

  Future<bool> isBuddyLiveModelAvailable() async {
    if (_buddyLiveModelAvailable != null) {
      return _buddyLiveModelAvailable!;
    }

    final url = '$_baseUrl?key=${AppKeys.geminiApiKey}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _buddyLiveLastError =
            'Could not verify model access (HTTP ${response.statusCode}).';
        _buddyLiveModelAvailable = false;
        return false;
      }

      final decoded = jsonDecode(response.body);
      final models = decoded is Map<String, dynamic> ? decoded['models'] : null;
      if (models is! List) {
        _buddyLiveLastError = 'Model list response was invalid.';
        _buddyLiveModelAvailable = false;
        return false;
      }

      final available = models.any((m) {
        if (m is! Map<String, dynamic>) return false;
        final name = (m['name'] ?? '').toString();
        return name == 'models/$_buddyLiveModel';
      });

      _buddyLiveModelAvailable = available;
      if (!available) {
        _buddyLiveLastError =
            'Live model $_buddyLiveModel is not enabled for this API key/project.';
      }
      return available;
    } catch (e) {
      _buddyLiveLastError = 'Model availability check failed: $e';
      _buddyLiveModelAvailable = false;
      return false;
    }
  }

  Future<void> startBuddyLiveSession([String? systemPrompt]) async {
    if (isBuddyLiveConnected) return;

    await closeBuddyLiveSession();

    final prompt = (systemPrompt != null && systemPrompt.isNotEmpty)
        ? systemPrompt
        : _buddySystemPrompt;

    await _openBuddyLiveSocketAndConfigure(
      prompt: prompt,
      topLevelConfigKey: 'setup',
    );
  }

  Future<void> _openBuddyLiveSocketAndConfigure({
    required String prompt,
    required String topLevelConfigKey,
  }) async {
    _debugLive('Opening websocket to Buddy Live endpoint...');

    late final WebSocket socket;
    try {
      socket = await WebSocket.connect(
        _buddyLiveEndpoint,
        compression: CompressionOptions.compressionOff,
      );
    } catch (e) {
      _buddyLiveLastError = 'Buddy live websocket connect failed: $e';
      _debugLive(_buddyLiveLastError!);
      rethrow;
    }

    _debugLive('Websocket connected.');
    _buddyLiveSocket = socket;
    _buddyLiveReady = false;
    _buddyLiveLastError = null;
    _buddyLiveSetupCompleter = Completer<void>();

    _buddyLiveSocketSub = socket.listen(
      _handleBuddyLiveMessage,
      onError: (_) {
        _buddyLiveLastError = 'Buddy live socket error';
        _debugLive(_buddyLiveLastError!);
        if (_buddyLiveSetupCompleter != null &&
            !_buddyLiveSetupCompleter!.isCompleted) {
          _buddyLiveSetupCompleter!
              .completeError(StateError(_buddyLiveLastError!));
        }
        _completeBuddyLiveWithFallbackError();
      },
      onDone: () {
        final code = socket.closeCode;
        final reason = socket.closeReason;
        _buddyLiveLastError =
            'Buddy live socket closed (code: ${code ?? 'n/a'}, reason: ${reason ?? 'n/a'})';
        _debugLive(_buddyLiveLastError!);
        if (_buddyLiveSetupCompleter != null &&
            !_buddyLiveSetupCompleter!.isCompleted) {
          _buddyLiveSetupCompleter!
              .completeError(StateError(_buddyLiveLastError!));
        }
        _completeBuddyLiveWithFallbackError();
        _buddyLiveReady = false;
      },
      cancelOnError: false,
    );

    final configBody = {
      'model': 'models/$_buddyLiveModel',
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': 'Aoede'}
          }
        },
      },
      'systemInstruction': {
        'parts': [
          {'text': prompt},
        ],
      },
      'outputAudioTranscription': {},
    };

    final setup = {topLevelConfigKey: configBody};

    _debugLive(
      'Sending $topLevelConfigKey payload for model $_buddyLiveModel',
    );
    socket.add(jsonEncode(setup));
    await _buddyLiveSetupCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _buddyLiveLastError = 'Buddy live setup timeout';
        _debugLive(_buddyLiveLastError!);
        throw StateError(_buddyLiveLastError!);
      },
    );
    _buddyLiveReady = true;
    _debugLive('Setup complete. Live session connected.');
  }

  Future<void> closeBuddyLiveSession() async {
    _debugLive('Closing live session...');
    _buddyLiveReady = false;
    _buddyLiveSetupCompleter = null;
    _buddyLivePending = null;
    _buddyLiveAudioBuilder = null;
    _buddyLiveTextBuffer = null;

    await _buddyLiveSocketSub?.cancel();
    _buddyLiveSocketSub = null;

    await _buddyLiveSocket?.close();
    _buddyLiveSocket = null;
  }

  Future<BuddyDialogResponse> askBuddyLive(
    String userMessage, [
    String? systemPrompt,
  ]) async {
    try {
      await startBuddyLiveSession(systemPrompt);

      final socket = _buddyLiveSocket;
      if (socket == null || !_buddyLiveReady) {
        return askBuddy(userMessage, systemPrompt);
      }

      if (_buddyLivePending != null && !_buddyLivePending!.isCompleted) {
        return askBuddy(userMessage, systemPrompt);
      }

      final pending = Completer<BuddyDialogResponse>();
      _buddyLivePending = pending;
      _buddyLiveAudioBuilder = BytesBuilder(copy: false);
      _buddyLiveTextBuffer = StringBuffer();

      final payload = {
        'clientContent': {
          'turns': [
            {
              'role': 'user',
              'parts': [
                {'text': userMessage},
              ],
            },
          ],
          'turnComplete': true,
        },
      };

      socket.add(jsonEncode(payload));

      return pending.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () async {
          _buddyLivePending = null;
          return askBuddy(userMessage, systemPrompt);
        },
      );
    } catch (_) {
      return askBuddy(userMessage, systemPrompt);
    }
  }

  Future<void> startBuddyLiveDuplexTurn([String? systemPrompt]) async {
    await startBuddyLiveSession(systemPrompt);

    if (_buddyLivePending != null && !_buddyLivePending!.isCompleted) {
      throw StateError('A buddy live turn is already in progress.');
    }

    _buddyLivePending = Completer<BuddyDialogResponse>();
    _buddyLiveAudioBuilder = BytesBuilder(copy: false);
    _buddyLiveTextBuffer = StringBuffer();
    _debugLive('Duplex turn started. Awaiting realtime audio chunks...');
  }

  void sendBuddyLiveAudioChunk(
    Uint8List pcmChunk, {
    String mimeType = 'audio/pcm;rate=16000',
  }) {
    final socket = _buddyLiveSocket;
    if (socket == null || !_buddyLiveReady) return;
    if (pcmChunk.isEmpty) return;

    final payload = {
      'realtimeInput': {
        'audio': {
          'mimeType': mimeType,
          'data': base64Encode(pcmChunk),
        },
      },
    };
    socket.add(jsonEncode(payload));
  }

  Future<BuddyDialogResponse> endBuddyLiveDuplexTurn({
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final socket = _buddyLiveSocket;
    final pending = _buddyLivePending;
    if (socket == null || pending == null) {
      throw StateError('No active buddy live duplex turn.');
    }

    final endPayload = {
      'realtimeInput': {
        'audioStreamEnd': true,
      },
    };
    _debugLive('audioStreamEnd sent. Waiting for model turn completion...');
    socket.add(jsonEncode(endPayload));

    return pending.future.timeout(
      timeout,
      onTimeout: () {
        _buddyLivePending = null;
        _buddyLiveAudioBuilder = null;
        _buddyLiveTextBuffer = null;
        _debugLive('Turn timeout waiting for server turnComplete.');
        return const BuddyDialogResponse(text: 'Unexpected response format');
      },
    );
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
            'overallScore': {
              'type': 'INTEGER',
              'description': 'Score from 0-100',
            },
            'heardText': {
              'type': 'STRING',
              'description': 'The literal transcription of what was heard',
            },
            'phonemeBreakdown': {
              'type': 'ARRAY',
              'items': {
                'type': 'OBJECT',
                'properties': {
                  'phoneme': {
                    'type': 'STRING',
                    'description': 'IPA symbol',
                  },
                  'status': {
                    'type': 'STRING',
                    'enum': ['correct', 'incorrect', 'partial'],
                    'description': 'Whether the phoneme was pronounced correctly',
                  },
                  'observed': {
                    'type': 'STRING',
                    'description': 'What sound was actually made',
                  },
                  'lipShape': {
                    'type': 'STRING',
                    'description': 'Specific physical cue for mouth positioning',
                  },
                  'tip': {
                    'type': 'STRING',
                    'description': 'Short friendly advice',
                  },
                },
                'required': [
                  'phoneme',
                  'status',
                  'observed',
                  'lipShape',
                  'tip',
                ],
              },
            },
            'strengths': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
              'description': 'List of things the learner did well (2-3 items)',
            },
            'priorities': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
              'description': 'List of top areas needing work (1-3 items, ranked by importance)',
            },
            'nextTryInstruction': {
              'type': 'STRING',
              'description': 'One sentence for the user to improve',
            },
          },
          'required': [
            'overallScore',
            'heardText',
            'strengths',
            'priorities',
            'phonemeBreakdown',
            'nextTryInstruction',
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
    ).timeout(const Duration(seconds: 30));

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

  Future<BreadShopNegotiation> negotiateBreadShop({
    required String userUtterance,
    required double currentBudgetEur,
    required List<String> purchasedItems,
    required double currentCartTotalEur,
    required bool isGerman,
    required List<Map<String, dynamic>> conversationHistory,
  }) async {
    final payload = {
      'systemInstruction': {
        'parts': [
          {'text': _breadShopSystemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text': jsonEncode({
                'conversationHistory': conversationHistory,
                'userUtterance': userUtterance,
                'currentBudget': currentBudgetEur,
                'purchasedItems': purchasedItems,
                'cartTotal': currentCartTotalEur,
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
              'name': 'negotiate_bread_shop',
              'description':
                  'Handle bakery negotiation with strict budget checks. Compute Remaining_Balance = currentBudget - cartTotal, enforce minimum price (90% of standard), suggest affordable items with offer_item, use counter_offer only for discount requests, reject unaffordable or below-floor offers, and keep German response plus English translation.',
              'parameters': {
                'type': 'OBJECT',
                'properties': {
                  'action': {
                    'type': 'STRING',
                    'enum': [
                      'offer_item',
                      'counter_offer',
                      'accept',
                      'reject',
                      'complete_sale'
                    ],
                    'description':
                        'offer_item for offers/suggestions; counter_offer only when user asks discount; reject for unaffordable requests or below 10% discount floor.',
                  },
                  'item': {
                    'type': 'STRING',
                    'description':
                        'Item name from catalog. Use empty string only for complete_sale or generic reject.',
                  },
                  'itemPrice': {
                    'type': 'NUMBER',
                    'minimum': 0,
                    'description':
                        'Final negotiated unit price in EUR. Must never be below 90% of standard list price for that item.',
                  },
                  'quantity': {
                    'type': 'INTEGER',
                    'minimum': 1,
                    'description':
                        'Number of items in this turn. Use 1 if user did not specify.',
                  },
                  'totalPrice': {
                    'type': 'NUMBER',
                    'minimum': 0,
                    'description':
                        'Must equal itemPrice * quantity, and must be <= currentBudget and <= Remaining_Balance (currentBudget - cartTotal).',
                  },
                  'shopkeeperResponse': {
                    'type': 'STRING',
                    'description':
                        'Response in German. For budget questions, include concrete affordable options.',
                  },
                  'englishTranslation': {
                    'type': 'STRING',
                    'description':
                        'Accurate English translation of shopkeeperResponse.',
                  },
                  'dealAccepted': {
                    'type': 'BOOLEAN',
                    'description':
                        'True only when an item deal is accepted or sale is completed; false for offer/counter_offer/reject.',
                  },
                },
                'required': [
                  'action',
                  'item',
                  'itemPrice',
                  'quantity',
                  'totalPrice',
                  'shopkeeperResponse',
                  'englishTranslation',
                  'dealAccepted',
                ],
              },
            },
          ],
        },
      ],
      'toolConfig': {
        'functionCallingConfig': {
          'mode': 'ANY',
          'allowedFunctionNames': ['negotiate_bread_shop'],
        },
      },
      'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 350},
    };

    final data = await _postPayload(payload);
    final functionArgs =
        _extractFunctionArgs(data, 'negotiate_bread_shop') ??
        _extractBreadShopArgsFromText(data);
    if (functionArgs == null) {
      throw Exception(
        'Baker did not return a valid negotiation response. Please try again.',
      );
    }

    return BreadShopNegotiation.fromFunctionArgs(functionArgs);
  }

  Map<String, dynamic>? _extractBreadShopArgsFromText(
    Map<String, dynamic> data,
  ) {
    final text = _extractFirstText(data);
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

  ({Uint8List bytes, String mimeType})? _extractFirstInlineAudio(
    Map<String, dynamic> data,
  ) {
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) return null;

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    for (final part in parts) {
      if (part is! Map<String, dynamic>) continue;
      final inlineData = part['inlineData'];
      if (inlineData is! Map<String, dynamic>) continue;

      final mimeType = (inlineData['mimeType'] ?? '').toString();
      final dataB64 = (inlineData['data'] ?? '').toString();
      if (!mimeType.startsWith('audio/') || dataB64.isEmpty) continue;

      try {
        final bytes = base64Decode(dataB64);
        if (bytes.isNotEmpty) {
          return (bytes: bytes, mimeType: mimeType);
        }
      } catch (_) {
        // Ignore malformed inline audio and continue scanning parts.
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

  void _handleBuddyLiveMessage(dynamic raw) {
    Map<String, dynamic>? msg;
    try {
      if (raw is String) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) msg = decoded;
      }
    } catch (_) {
      return;
    }
    if (msg == null) return;

    if (msg['setupComplete'] != null) {
      _buddyLiveReady = true;
      _buddyLiveLastError = null;
      _debugLive('Received setupComplete from server.');
      if (_buddyLiveSetupCompleter != null &&
          !_buddyLiveSetupCompleter!.isCompleted) {
        _buddyLiveSetupCompleter!.complete();
      }
      return;
    }

    final serverContent = msg['serverContent'];
    if (serverContent is! Map<String, dynamic>) {
      final error = msg['error'];
      if (error != null) {
        _buddyLiveLastError = 'Buddy live server error: $error';
        _debugLive(_buddyLiveLastError!);
        if (_buddyLiveSetupCompleter != null &&
            !_buddyLiveSetupCompleter!.isCompleted) {
          _buddyLiveSetupCompleter!
              .completeError(StateError(_buddyLiveLastError!));
        }
        _completeBuddyLiveWithFallbackError();
      }
      return;
    }

    final outputTranscription = serverContent['outputTranscription'];
    if (outputTranscription is Map<String, dynamic>) {
      final text = (outputTranscription['text'] ?? '').toString();
      if (text.isNotEmpty) {
        _buddyLiveTextBuffer ??= StringBuffer();
        _buddyLiveTextBuffer!.write(text);
      }
    }

    final modelTurn = serverContent['modelTurn'];
    if (modelTurn is Map<String, dynamic>) {
      final parts = modelTurn['parts'];
      if (parts is List) {
        for (final part in parts) {
          if (part is! Map<String, dynamic>) continue;

          final text = part['text'];
          if (text is String && text.trim().isNotEmpty) {
            _buddyLiveTextBuffer ??= StringBuffer();
            _buddyLiveTextBuffer!.write(text);
          }

          final inlineData = part['inlineData'];
          if (inlineData is! Map<String, dynamic>) continue;
          final mimeType = (inlineData['mimeType'] ?? '').toString();
          final dataB64 = (inlineData['data'] ?? '').toString();
          if (!mimeType.startsWith('audio/') || dataB64.isEmpty) continue;

          try {
            final bytes = base64Decode(dataB64);
            if (bytes.isNotEmpty) {
              _buddyLiveAudioBuilder ??= BytesBuilder(copy: false);
              _buddyLiveAudioBuilder!.add(bytes);
            }
          } catch (_) {
            // Ignore malformed chunk and continue.
          }
        }
      }
    }

    final turnComplete = serverContent['turnComplete'] == true;
    if (turnComplete) {
      _debugLive('Received server turnComplete.');
      final pending = _buddyLivePending;
      if (pending != null && !pending.isCompleted) {
        final text = (_buddyLiveTextBuffer?.toString() ?? '').trim();
        final audioBytes = _buddyLiveAudioBuilder?.takeBytes();
        pending.complete(
          BuddyDialogResponse(
            text: text.isEmpty ? 'Unexpected response format' : text,
            audioBytes: (audioBytes == null || audioBytes.isEmpty)
                ? null
                : audioBytes,
            audioMimeType:
                (audioBytes == null || audioBytes.isEmpty) ? null : 'audio/pcm',
          ),
        );
      }
      _buddyLivePending = null;
      _buddyLiveAudioBuilder = null;
      _buddyLiveTextBuffer = null;
    }
  }

  void _completeBuddyLiveWithFallbackError() {
    if (_buddyLiveSetupCompleter != null &&
        !_buddyLiveSetupCompleter!.isCompleted) {
      _buddyLiveLastError ??= 'Buddy live setup did not complete';
      _debugLive(_buddyLiveLastError!);
      _buddyLiveSetupCompleter!
        .completeError(StateError(_buddyLiveLastError!));
    }
    final pending = _buddyLivePending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const BuddyDialogResponse(text: 'Unexpected response format'));
    }
    _buddyLivePending = null;
    _buddyLiveAudioBuilder = null;
    _buddyLiveTextBuffer = null;
  }
}
