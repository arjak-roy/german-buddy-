import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;
import 'dart:ui';

import '../../../../data/models/bread_shop_transaction.dart';
import '../../../../data/services/gemini_service.dart';
import '../../../../providers/app_providers.dart';
import '../../../shared/widgets/speech_action_bar.dart';

class BreadShopScreen extends ConsumerStatefulWidget {
  const BreadShopScreen({super.key});

  @override
  ConsumerState<BreadShopScreen> createState() => _BreadShopScreenState();
}

class _BreadShopScreenState extends ConsumerState<BreadShopScreen>
    with TickerProviderStateMixin {
  final GeminiService _bakery = GeminiService();
  late final FlutterTts _tts;
  final List<BreadShopNegotiation> _transactions = [];
  final ScrollController _scrollController = ScrollController();
  double _totalSpent = 0.0;
  final double _budget = 20.0; // EUR
  final List<String> _bagItems = [];
  bool _isLoading = false;
  bool _dealComplete = false;
  bool _missionFailed = false;
  bool _showHints = true;
  String? _errorMessage;
  final List<Map<String, dynamic>> _conversationHistory = [];
  late AnimationController _confettiController;
  late AnimationController _bagController;

  /// Hint phrases grouped by conversation stage.
  /// Stage 0 = greeting (no transactions yet)
  /// Stage 1 = ordering (1+ turns, no accepted deal yet)
  /// Stage 2 = negotiating (any counter-offer seen)
  /// Stage 3 = finishing (at least one item in bag)
  static const List<List<_HintPhrase>> _hints = [
    // Stage 0 – opening
    [
      _HintPhrase('Guten Morgen!', 'Good morning!'),
      _HintPhrase('Ich möchte Brot kaufen.', 'I would like to buy bread.'),
      _HintPhrase(
        'Was haben Sie heute frisch?',
        'What do you have fresh today?',
      ),
      _HintPhrase(
        'Ich suche etwas Süßes.',
        'I am looking for something sweet.',
      ),
    ],
    // Stage 1 – ordering items
    [
      _HintPhrase('Ich nehme zwei Brötchen.', 'I will take two bread rolls.'),
      _HintPhrase('Haben Sie Croissants?', 'Do you have croissants?'),
      _HintPhrase('Ein Bauernbrot, bitte.', 'One farmhouse bread, please.'),
      _HintPhrase(
        'Was kostet der Apfelstrudel?',
        'How much is the apple strudel?',
      ),
      _HintPhrase('Drei Brezel, bitte.', 'Three pretzels, please.'),
    ],
    // Stage 2 – negotiating price
    [
      _HintPhrase('Können Sie einen Rabatt geben?', 'Can you give a discount?'),
      _HintPhrase('Das ist etwas teuer.', 'That is a bit expensive.'),
      _HintPhrase(
        'Ich kaufe fünf – gibt es einen Mengenrabatt?',
        'I am buying five - is there a bulk discount?',
      ),
      _HintPhrase('Wie wäre es mit €2,00?', 'How about EUR 2.00?'),
      _HintPhrase('Einverstanden!', 'Agreed!'),
    ],
    // Stage 3 – wrapping up
    [
      _HintPhrase('Noch etwas, bitte.', 'Something else, please.'),
      _HintPhrase(
        'Ich nehme auch ein Croissant.',
        'I will also take a croissant.',
      ),
      _HintPhrase('Das reicht, danke.', 'That is enough, thank you.'),
      _HintPhrase('Tschüss und auf Wiedersehen!', 'Bye and see you again!'),
    ],
  ];

  List<_HintPhrase> get _currentHints {
    if (_dealComplete || _missionFailed) return [];
    if (_transactions.isEmpty) return _hints[0];
    final hasCounterOffer = _transactions.any(
      (t) => t.action == 'counter_offer' || t.action == 'reject',
    );
    if (_bagItems.isNotEmpty) return _hints[3];
    if (hasCounterOffer) return _hints[2];
    return _hints[1];
  }

  static const String _staticGreeting =
      'Guten Morgen! Willkommen in unserer Bäckerei! '
      'Was darf es heute sein?';
  static const String _staticGreetingEn =
      'Good morning! Welcome to our bakery! What can I get you today?';

  _BakerMood get _bakerMood {
    if (_missionFailed) return _BakerMood.concerned;
    if (_errorMessage != null) return _BakerMood.concerned;
    if (_dealComplete) return _BakerMood.celebrating;
    if (_isLoading) return _BakerMood.thinking;
    if (_transactions.isEmpty) return _BakerMood.welcoming;

    final last = _transactions.last;
    if (last.action == 'counter_offer') return _BakerMood.negotiating;
    if (last.action == 'reject') return _BakerMood.concerned;
    if (last.action == 'accept' || last.dealAccepted) return _BakerMood.happy;
    if (last.action == 'complete_sale') return _BakerMood.celebrating;
    return _BakerMood.welcoming;
  }

  String get _bakerCue {
    switch (_bakerMood) {
      case _BakerMood.welcoming:
        return 'Ready to take your order.';
      case _BakerMood.thinking:
        return 'Considering your request...';
      case _BakerMood.negotiating:
        return 'Negotiation mode: best offer incoming.';
      case _BakerMood.happy:
        return 'Great choice. Deal accepted!';
      case _BakerMood.concerned:
        return _missionFailed
            ? 'Budget exceeded. Mission failed.'
            : 'Something is off. Try a clearer phrase.';
      case _BakerMood.celebrating:
        return 'Sale complete. Danke and bis bald!';
    }
  }

  void _retryMission() {
    setState(() {
      _transactions.clear();
      _conversationHistory.clear();
      _bagItems.clear();
      _totalSpent = 0.0;
      _isLoading = false;
      _dealComplete = false;
      _missionFailed = false;
      _showHints = true;
      _errorMessage = null;
    });
    _confettiController.reset();
  }

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE'); // fallback; overridden by _applyVoiceSettings
    _tts.setPitch(1.0);
    _tts.setSpeechRate(0.45);
    _tts.awaitSpeakCompletion(false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyVoiceSettings());
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _bagController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tts.stop();
    _scrollController.dispose();
    _confettiController.dispose();
    _bagController.dispose();
    super.dispose();
  }

  Future<void> _applyVoiceSettings() async {
    if (!mounted) return;
    final vp = ref.read(voiceProviderNotifier);
    await vp.loadVoices();
    if (!mounted) return;
    await vp.applyTo(_tts);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isGermanUi() => ref.read(speechProviderNotifier).isGerman;

  // Kept for reference; TTS is now inlined in _handleUtterance to avoid
  // calling context.read across an async gap.

  // Called by both SpeechActionBar (voice) and keyboard submit
  Future<void> _handleUtterance(String text) async {
    final utterance = text.trim();
    if (utterance.isEmpty || _isLoading || _dealComplete || _missionFailed) {
      return;
    }

    // Capture locale and providers before any async gap
    final isGerman = _isGermanUi();
    final voiceProvider = ref.read(voiceProviderNotifier);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _bakery.negotiateBreadShop(
        userUtterance: utterance,
        currentBudgetEur: _budget,
        purchasedItems: List.unmodifiable(_bagItems),
        currentCartTotalEur: _totalSpent,
        isGerman: isGerman,
        conversationHistory: List.unmodifiable(_conversationHistory),
      );

      setState(() {
        _transactions.add(response);
        _conversationHistory.add({
          'turn': _conversationHistory.length + 1,
          'customer': utterance,
          'baker': response.shopkeeperResponse,
          'action': response.action,
          'item': response.item,
          'itemPrice': response.itemPrice,
          'quantity': response.quantity,
          'dealAccepted': response.dealAccepted,
        });

        // Only update cart totals when a specific item deal is struck
        if (response.dealAccepted && response.itemPrice > 0) {
          _totalSpent += response.itemPrice * response.quantity;
          if (response.item.isNotEmpty) {
            _bagItems.add('${response.quantity}x ${response.item}');
          }

          if (_totalSpent > _budget) {
            _missionFailed = true;
            _errorMessage =
                'Mission failed: Budget exceeded (€${_totalSpent.toStringAsFixed(2)} / €${_budget.toStringAsFixed(2)}).';
          }
        }

        // Only end the session when the baker explicitly completes the sale
        if (response.action == 'complete_sale') {
          _dealComplete = true;
          _confettiController.forward();
        }

        _isLoading = false;
      });
      _scrollToBottom();

      // Update hint stage after each turn
      setState(() {});

      // Always use German TTS voice for bakery roleplay output.
      final speakText = response.shopkeeperResponse.isNotEmpty
          ? response.shopkeeperResponse
          : response.englishTranslation;
      if (speakText.isNotEmpty) {
        try {
          await voiceProvider.applyTo(_tts);
          await _tts.stop();
          await _tts.speak(speakText);
        } catch (_) {}
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _showHowToPlay() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Text('🥖', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('How to Play'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                'Welcome to the German Bakery!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You have a €20 budget. Practice your German by '
                'ordering and negotiating with the baker.',
              ),
              SizedBox(height: 16),
              _HowToRow(
                icon: '🗣️',
                text: 'Tap the mic or type in German to speak to the baker.',
              ),
              _HowToRow(
                icon: '🛒',
                text: 'Ask for items: "Ich möchte zwei Brötchen."',
              ),
              _HowToRow(
                icon: '💰',
                text: 'Negotiate prices — bulk orders get discounts!',
              ),
              _HowToRow(
                icon: '✅',
                text: 'Accept a deal: "Einverstanden!" or "Abgemacht!"',
              ),
              _HowToRow(
                icon: '👜',
                text: 'Accepted items land in your shopping bag.',
              ),
              _HowToRow(
                icon: '🏁',
                text: 'Say "Das reicht, danke!" or "Tschüss!" when done.',
              ),
              SizedBox(height: 16),
              Text(
                'Useful phrases',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              _PhraseRow(
                de: 'Was haben Sie heute frisch?',
                en: 'What do you have fresh today?',
              ),
              _PhraseRow(de: 'Was kostet das?', en: 'How much does that cost?'),
              _PhraseRow(
                de: 'Können Sie einen Rabatt geben?',
                en: 'Can you give a discount?',
              ),
              _PhraseRow(
                de: 'Ich nehme das Angebot!',
                en: "I'll take the offer!",
              ),
              _PhraseRow(de: 'Das ist zu teuer.', en: 'That is too expensive.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Baeckerei Atelier'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How to play',
            onPressed: _showHowToPlay,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _BakeryBackdrop()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
                  child: Row(
                    children: [
                      Text(
                        'Warm oven. Fresh language practice.',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'SATURDAY MARKET',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Top section: Budget & Bag – use Expanded so Row children are bounded
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _BudgetCard(spent: _totalSpent, budget: _budget),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ShoppingBag(
                          items: _bagItems,
                          controller: _bagController,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _BakerCharacterCard(mood: _bakerMood, cue: _bakerCue),
                ),
                const SizedBox(height: 2),

                // Conversation area
                Expanded(
                  child: Stack(
                    children: [
                      ListView(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                          12,
                          12,
                          12,
                          (_showHints && _currentHints.isNotEmpty) ? 112 : 16,
                        ),
                        children: [
                          // Static baker greeting always shown
                          _StaticGreetingCard(
                            german: _staticGreeting,
                            english: _staticGreetingEn,
                          ),
                          ..._transactions.map(
                            (t) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _TransactionCard(transaction: t),
                            ),
                          ),
                          // Error message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      scheme.errorContainer,
                                      scheme.surface,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: scheme.error.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: scheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMessage!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onErrorContainer,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Loading indicator in the list
                          if (_isLoading)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text('Baker is weighing your offer...'),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_showHints && _currentHints.isNotEmpty)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 8,
                          child: _HintStrip(
                            hints: _currentHints,
                            onHintTap: (hint) {
                              if (!_isLoading &&
                                  !_dealComplete &&
                                  !_missionFailed) {
                                _handleUtterance(hint.de);
                              }
                            },
                            onDismiss: () => setState(() => _showHints = false),
                          ),
                        ),
                    ],
                  ),
                ),

                // Input area
                if (!_dealComplete && !_missionFailed)
                  Container(
                    margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      color: Colors.white.withValues(alpha: 0.76),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.16),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: SpeechActionBar(
                          keyboardLabel: 'Deine Nachricht auf Deutsch...',
                          onSubmitted: _handleUtterance,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (_missionFailed) ...[
                          Text(
                            'Mission failed: You exceeded the budget.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Spent: EUR ${_totalSpent.toStringAsFixed(2)} / EUR ${_budget.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: _retryMission,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ] else ...[
                          Text(
                            'Vielen Dank! Auf Wiedersehen!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: EUR ${_totalSpent.toStringAsFixed(2)}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Confetti overlay
          if (_dealComplete)
            IgnorePointer(child: _Confetti(controller: _confettiController)),
        ],
      ),
    );
  }
}

class _BakeryBackdrop extends StatelessWidget {
  _BakeryBackdrop();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.surface,
            scheme.surfaceContainerLowest,
            scheme.surfaceContainerLow,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -70,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.secondary.withValues(alpha: 0.10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticGreetingCard extends StatelessWidget {
  final String german;
  final String english;

  const _StaticGreetingCard({required this.german, required this.english});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primaryContainer.withValues(alpha: 0.75),
              scheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.26),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Oven Greeting',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Baker',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              german,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              english,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

enum _BakerMood {
  welcoming,
  thinking,
  negotiating,
  happy,
  concerned,
  celebrating,
}

class _BakerCharacterCard extends StatelessWidget {
  final _BakerMood mood;
  final String cue;

  const _BakerCharacterCard({required this.mood, required this.cue});

  (String emoji, Color color, String title) _visualForMood(
    BuildContext context,
  ) {
    switch (mood) {
      case _BakerMood.welcoming:
        return ('👨‍🍳', Colors.brown, 'Baker: Welcoming');
      case _BakerMood.thinking:
        return ('🤔', Colors.indigo, 'Baker: Thinking');
      case _BakerMood.negotiating:
        return ('🧾', Colors.blue, 'Baker: Negotiating');
      case _BakerMood.happy:
        return ('😊', Colors.green, 'Baker: Happy');
      case _BakerMood.concerned:
        return ('😬', Colors.red, 'Baker: Concerned');
      case _BakerMood.celebrating:
        return ('🎉', Colors.purple, 'Baker: Celebrating');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, color, title) = _visualForMood(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.32), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                emoji,
                key: ValueKey<String>(emoji),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    cue,
                    key: ValueKey<String>(cue),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final double spent;
  final double budget;

  const _BudgetCard({required this.spent, required this.budget});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = (budget - spent).clamp(0.0, budget);
    final progress = (spent / budget).clamp(0.0, 1.0);
    final overBudget = spent > budget;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.45),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: overBudget ? scheme.error : scheme.primary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (overBudget ? scheme.error : scheme.primary).withValues(
              alpha: 0.14,
            ),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'Budget',
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'EUR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Use LayoutBuilder so LinearProgressIndicator has a bounded width
          LayoutBuilder(
            builder: (context, constraints) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: scheme.surfaceContainerHighest,
                color: overBudget ? scheme.error : scheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'EUR ${spent.toStringAsFixed(2)} / EUR ${budget.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'EUR ${remaining.toStringAsFixed(2)} left',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: remaining > 0 ? scheme.primary : scheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShoppingBag extends StatelessWidget {
  final List<String> items;
  final AnimationController controller;

  const _ShoppingBag({required this.items, required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final itemChips = items.take(4).toList(growable: false);
    final remaining = items.length - itemChips.length;

    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.95,
        end: 1.05,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -6,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 56,
                height: 18,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  scheme.primaryContainer.withValues(alpha: 0.68),
                  scheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.42),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.18),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'My Bag',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${items.length}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Text(
                    'No items yet. Start ordering!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...itemChips.map((item) => _BagItemChip(label: item)),
                      if (remaining > 0)
                        _BagItemChip(label: '+$remaining more'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BagItemChip extends StatelessWidget {
  final String label;

  const _BagItemChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final BreadShopNegotiation transaction;

  const _TransactionCard({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAccepted =
        transaction.dealAccepted || transaction.action == 'accept';
    final isCounter = transaction.action == 'counter_offer';
    final isRejected = transaction.action == 'reject';
    final tone = isAccepted
        ? const Color(0xFF16A34A)
        : (isCounter
              ? scheme.primary
              : (isRejected ? scheme.error : scheme.secondary));

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: tone.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                'Baker',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  transaction.action.replaceAll('_', ' '),
                  style: TextStyle(
                    fontSize: 10,
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (transaction.item.isNotEmpty)
            Text(
              '${transaction.item} - EUR ${transaction.itemPrice.toStringAsFixed(2)} x ${transaction.quantity}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          if (transaction.item.isNotEmpty) const SizedBox(height: 4),
          Text(
            transaction.shopkeeperResponse,
            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            transaction.englishTranslation,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          if (transaction.totalPrice > 0 ||
              (transaction.itemPrice > 0 && transaction.quantity > 0)) ...[
            const SizedBox(height: 8),
            Text(
              transaction.dealAccepted
                  ? 'Deal: EUR ${(transaction.itemPrice * transaction.quantity).toStringAsFixed(2)}'
                  : 'Offer: EUR ${transaction.totalPrice > 0 ? transaction.totalPrice.toStringAsFixed(2) : (transaction.itemPrice * transaction.quantity).toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: transaction.dealAccepted
                    ? const Color(0xFF16A34A)
                    : scheme.primary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Confetti extends AnimatedWidget {
  const _Confetti({required AnimationController controller})
    : super(listenable: controller);

  @override
  Widget build(BuildContext context) {
    final controller = listenable as AnimationController;
    final t = controller.value;
    final size = MediaQuery.of(context).size;

    return Stack(
      children: List.generate(30, (index) {
        final random = math.Random(index);
        final angle = random.nextDouble() * math.pi * 2;
        final speed = 0.4 + random.nextDouble() * 0.6;
        final startX = size.width * (0.2 + random.nextDouble() * 0.6);
        final startY = size.height * 0.4;
        final dx = math.cos(angle) * speed * 300 * t;
        final dy = math.sin(angle) * speed * 300 * t + 200 * t * t;
        final opacity = (1.0 - t).clamp(0.0, 1.0);
        final emojis = ['🥖', '🥐', '🥯', '🍞', '✨', '⭐'];

        return Positioned(
          left: startX + dx,
          top: startY + dy,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: random.nextDouble() * math.pi * 4 * t,
              child: Text(
                emojis[index % emojis.length],
                style: const TextStyle(fontSize: 26),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HintStrip extends StatelessWidget {
  final List<_HintPhrase> hints;
  final void Function(_HintPhrase hint) onHintTap;
  final VoidCallback onDismiss;

  const _HintStrip({
    required this.hints,
    required this.onHintTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    size: 14,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Try saying',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: hints.map((hint) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hint.de,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              hint.en,
                              style: TextStyle(
                                fontSize: 10,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: scheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        side: BorderSide(
                          color: scheme.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        onPressed: () => onHintTap(hint),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HintPhrase {
  final String de;
  final String en;

  const _HintPhrase(this.de, this.en);
}

class _HowToRow extends StatelessWidget {
  final String icon;
  final String text;

  const _HowToRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PhraseRow extends StatelessWidget {
  final String de;
  final String en;

  const _PhraseRow({required this.de, required this.en});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            de,
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            en,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
