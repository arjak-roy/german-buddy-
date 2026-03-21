import 'dart:typed_data';

import '../../models/bread_shop_transaction.dart';
import '../../models/pronunciation_analysis_report.dart';
import 'features/bread_shop_service.dart';
import 'features/buddy_live_service.dart';
import 'features/conversation_service.dart';
import 'features/pronunciation_service.dart';
import 'features/tic_tac_toe_service.dart';
import 'models/buddy_dialog_response.dart';
import 'models/tic_tac_toe_turn_plan.dart';

class GeminiService {
  GeminiService({
    GeminiConversationService? conversation,
    GeminiBuddyLiveService? buddyLive,
    GeminiTicTacToeService? ticTacToe,
    GeminiPronunciationService? pronunciation,
    GeminiBreadShopService? breadShop,
  }) : _conversation = conversation ?? GeminiConversationService(),
       _buddyLive = buddyLive ?? GeminiBuddyLiveService(),
       _ticTacToe = ticTacToe ?? GeminiTicTacToeService(),
       _pronunciation = pronunciation ?? GeminiPronunciationService(),
       _breadShop = breadShop ?? GeminiBreadShopService();

  final GeminiConversationService _conversation;
  final GeminiBuddyLiveService _buddyLive;
  final GeminiTicTacToeService _ticTacToe;
  final GeminiPronunciationService _pronunciation;
  final GeminiBreadShopService _breadShop;

  Stream<void> get buddyLiveInterruptedStream =>
      _buddyLive.buddyLiveInterruptedStream;
  bool get isBuddyLiveConnected => _buddyLive.isBuddyLiveConnected;
  String? get buddyLiveLastError => _buddyLive.buddyLiveLastError;

  Future<String> ask(
    String userMessage, [
    String? systemPrompt,
    bool forceJsonResponse = false,
  ]) {
    return _conversation.ask(userMessage, systemPrompt, forceJsonResponse);
  }

  Future<BuddyDialogResponse> askBuddy(
    String userMessage, [
    String? systemPrompt,
  ]) {
    return _conversation.askBuddy(userMessage, systemPrompt);
  }

  Future<void> startBuddyLiveSession([String? systemPrompt]) {
    return _buddyLive.startBuddyLiveSession(systemPrompt);
  }

  Future<void> closeBuddyLiveSession() {
    return _buddyLive.closeBuddyLiveSession();
  }

  Future<BuddyDialogResponse> askBuddyLive(
    String userMessage, [
    String? systemPrompt,
  ]) {
    return _buddyLive.askBuddyLive(userMessage, systemPrompt);
  }

  Future<void> startBuddyLiveAudioTurn(
    Stream<Uint8List> audioStream, {
    int sampleRateHz = 16000,
    String? systemPrompt,
  }) {
    return _buddyLive.startBuddyLiveAudioTurn(
      audioStream,
      sampleRateHz: sampleRateHz,
      systemPrompt: systemPrompt,
    );
  }

  Future<BuddyDialogResponse> finishBuddyLiveAudioTurn() {
    return _buddyLive.finishBuddyLiveAudioTurn();
  }

  Future<void> cancelBuddyLiveAudioTurn() {
    return _buddyLive.cancelBuddyLiveAudioTurn();
  }

  Future<TicTacToeTurnPlan> planTicTacToeTurn({
    required String userUtterance,
    required List<String> board,
    required bool isGameOver,
    required String? winner,
    required bool isGerman,
  }) {
    return _ticTacToe.planTurn(
      userUtterance: userUtterance,
      board: board,
      isGameOver: isGameOver,
      winner: winner,
      isGerman: isGerman,
    );
  }

  Future<PronunciationAnalysisReport> analyzePronunciationAudio({
    required String targetWord,
    required String targetEnglish,
    required String targetPhonetic,
    required String audioFilePath,
  }) {
    return _pronunciation.analyzeAudio(
      targetWord: targetWord,
      targetEnglish: targetEnglish,
      targetPhonetic: targetPhonetic,
      audioFilePath: audioFilePath,
    );
  }

  Future<BreadShopNegotiation> negotiateBreadShop({
    required String userUtterance,
    required double currentBudgetEur,
    required List<String> purchasedItems,
    required double currentCartTotalEur,
    required bool isGerman,
    required List<Map<String, dynamic>> conversationHistory,
  }) {
    return _breadShop.negotiate(
      userUtterance: userUtterance,
      currentBudgetEur: currentBudgetEur,
      purchasedItems: purchasedItems,
      currentCartTotalEur: currentCartTotalEur,
      isGerman: isGerman,
      conversationHistory: conversationHistory,
    );
  }

  Future<void> disposeBuddyLive() {
    return _buddyLive.disposeBuddyLive();
  }
}
