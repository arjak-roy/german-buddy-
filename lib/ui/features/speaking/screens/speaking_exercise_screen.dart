import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../providers/app_providers.dart';
import '../../../../providers/speaking_session_provider.dart';
import '../../../../providers/speech_provider.dart';
import '../../../../providers/speaking_engine_provider.dart';
import '../../pronunciation/models/pronunciation_item.dart';
import '../../pronunciation/screens/pronunciation_lesson_screen.dart';
import '../../pronunciation/widgets/pronunciation_mini_lab.dart';
import '../models/speaking_exercise_state.dart';
import '../engine/speaking_engine_models.dart';

class SpeakingExerciseScreen extends ConsumerStatefulWidget {
  final SpeakingExercise item;

  const SpeakingExerciseScreen({super.key, required this.item});

  @override
  ConsumerState<SpeakingExerciseScreen> createState() => _SpeakingExerciseScreenState();
}

class _SpeakingExerciseScreenState extends ConsumerState<SpeakingExerciseScreen> {
  late final FlutterTts _tts;
  String? _lastAutoAnalyzedPayload;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _tts.setLanguage('de-DE');
    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(false);
    
    _tts.setStartHandler(() {
      if (!mounted) return;
      ref.read(speakingSessionNotifierProvider(widget.item).notifier).setTtsStarted();
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      ref.read(speakingSessionNotifierProvider(widget.item).notifier).setTtsStopped();
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      ref.read(speakingSessionNotifierProvider(widget.item).notifier).setTtsStopped();
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      ref.read(speakingSessionNotifierProvider(widget.item).notifier).setTtsStopped();
    });
    _tts.setProgressHandler((text, startOffset, endOffset, word) {
      if (!mounted) return;
      final notifier = ref.read(speakingSessionNotifierProvider(widget.item).notifier);
      final spans = _wordSpans(text);
      if (spans.isEmpty) return;

      var idx = -1;
      for (var i = 0; i < spans.length; i++) {
        final span = spans[i];
        if (startOffset >= span.start && startOffset < span.end) {
          idx = i;
          break;
        }
      }
      if (idx == -1) {
        for (var i = 0; i < spans.length; i++) {
          final span = spans[i];
          if (endOffset > span.start && endOffset <= span.end + 1) {
            idx = i;
            break;
          }
        }
      }
      
      final currentIdx = ref.read(speakingSessionNotifierProvider(widget.item)).ttsWordIndex;
      if (idx != -1 && idx != currentIdx) {
        notifier.setTtsWordIndex(idx);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final speech = ref.read(speechProviderNotifier);
      speech.setLanguage(SpeechLanguage.german);
      speech.allowAutoLanguageSwitch = false;
      speech.clearTranscript();
      speech.ensureInitialized();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    ref.read(speechProviderNotifier).allowAutoLanguageSwitch = true;
    super.dispose();
  }

  List<String> _tokenize(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r"[^a-z0-9A-ZäöüßÄÖÜ' ]"), ' ').trim();
    if (cleaned.isEmpty) return const [];
    return cleaned.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();
  }

  String _normalizeSpanToken(String rawToken) {
    final raw = rawToken.trim();
    if (raw.isEmpty) return '';
    final bracketMatch = RegExp(r'^\[(.+)\]$').firstMatch(raw);
    if (bracketMatch != null) {
      return (bracketMatch.group(1) ?? '').trim().toLowerCase();
    }
    final tokens = _tokenize(raw);
    return tokens.isEmpty ? '' : tokens.first;
  }

  bool _isIgnoredWordSpan(_WordSpan span) {
    final w = span.normalized.toLowerCase();
    if (widget.item.ignoreWords.contains(w)) return true;
    if (w.startsWith('[') && w.endsWith(']')) return true;
    return false;
  }

  String _translationForWord(String word) {
    final lower = word.toLowerCase();
    return widget.item.translations[lower] ?? '';
  }

  List<_WordSpan> _wordSpans(String sentence) {
    final matches = RegExp(r'\[[^\]]+\]|\S+').allMatches(sentence);
    return matches.map((m) => _WordSpan(
      raw: m.group(0) ?? '',
      normalized: _normalizeSpanToken(m.group(0) ?? ''),
      start: m.start,
      end: m.end,
    )).where((span) => span.raw.isNotEmpty).toList();
  }

  double _matchRate(List<String> target, Set<String> spoken) {
    if (target.isEmpty) return 0;
    var matched = 0;
    for (final token in target) {
      if (spoken.contains(token)) matched += 1;
    }
    return matched / target.length;
  }

  Color _wordColor({required bool matched, required double confidence}) {
    if (!matched) return Colors.grey.shade500;
    if (confidence >= 0.75) return Colors.green.shade600;
    if (confidence >= 0.5) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  Future<void> _speakCurrentSentence(String sentence, double ttsSpeed) async {
    final name = widget.item.spokenName ?? 'Mustername';
    final ttsSentence = sentence.replaceAllMapped(
      RegExp(r'\[\s*your\s+name\s*\]', caseSensitive: false),
      (_) => name,
    );
    await _tts.setSpeechRate(ttsSpeed);
    await _tts.stop();
    await _tts.speak(ttsSentence);
  }

  String _emojiForConfidence(double confidence) {
    if (confidence >= 0.75) return '🤩';
    if (confidence >= 0.5) return '🙂';
    return '😟';
  }

  String _emojiHintForConfidence(double confidence) {
    if (confidence >= 0.75) return 'Great clarity! Keep going.';
    if (confidence >= 0.5) return 'Good attempt. Slow down a bit.';
    return 'Try again, a bit clearer and slower.';
  }

  void _goToPreviousSentence(SpeechProvider speech, SpeakingSessionNotifier notifier) {
    speech.clearTranscript();
    notifier.goToPreviousSentence();
  }

  void _goToNextSentence(SpeechProvider speech, SpeakingSessionNotifier notifier) {
    speech.clearTranscript();
    final moved = notifier.goToNextSentence();
    if (!moved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attempt the last sentence once to unlock analysis.')),
      );
    }
  }

  Future<void> _toggleListening(SpeechProvider speech, SpeakingSessionNotifier notifier, SpeakingSessionState state) async {
    if (state.isCompleted) return;
    if (speech.isListening) {
      final capture = await speech.stopListeningAndCollect();
      if ((capture?.text.trim().isNotEmpty ?? false) && mounted) {
        notifier.markCurrentSentenceAttempted();
      }
      return;
    }
    speech.clearTranscript();
    await speech.startListening();
  }

  Future<void> _openWordPronunciationLab(BuildContext context, String word, double _) async {
    final item = findPronunciationItemByWord(word);
    if (item == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pronunciation data found for "$word" yet.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Pronunciation Lab: ${item.german}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                PronunciationMiniLab(item: item),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPronunciationLessonForWord(String word) async {
    final item = findPronunciationItemByWord(word);
    if (item == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No pronunciation page data found for "$word".')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PronunciationLessonScreen(item: item)),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 80) return const Color(0xFF00A388); // Success Teal
    if (score >= 60) return const Color(0xFFFFB300); // Amber 600
    if (score >= 40) return const Color(0xFFFF8F00); // Amber 800
    return const Color(0xFFE91E63); // Rose 500
  }

  Widget _buildAnalysisPage(BuildContext context, SpeakingSessionState state, SpeakingSessionNotifier notifier) {
    final theme = Theme.of(context);
    final isAnalyzing = state.uiState is SpeakingExerciseAnalyzing;
    final isError = state.uiState is SpeakingExerciseError;
    final isSuccess = state.uiState is SpeakingExerciseSuccess;
    final successState = isSuccess ? (state.uiState as SpeakingExerciseSuccess) : null;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_rounded),
                    const SizedBox(width: 8),
                    Text(
                      'Session Analysis',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This is the final analysis card. Your full session JSON is sent to Gemini for word-specific feedback.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: isAnalyzing ? null : () => notifier.runGeminiSessionAnalysis(),
                      icon: isAnalyzing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome_rounded),
                      label: Text(isAnalyzing ? 'Analyzing...' : 'Analyze with Gemini'),
                    ),
                  ],
                ),
                
                if (isError) ...[
                  const SizedBox(height: 10),
                  Text(
                    (state.uiState as SpeakingExerciseError).error,
                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
                
                if (isSuccess && successState != null) ...[
                  const SizedBox(height: 20),
                  // Overall Result Badge
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _scoreColor(successState.score),
                          _scoreColor(successState.score).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: _scoreColor(successState.score).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${successState.score.toStringAsFixed(0)}%',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'SESSION ACCURACY',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Word Performance Section (FIRST)
                  if (successState.wordAnalysis.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.spellcheck_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Word Performance',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...successState.wordAnalysis.map((itemObj) {
                      final item = itemObj as Map<String, dynamic>;
                      final score = (item['score'] as num).toDouble();
                      final word = item['word'].toString();
                      final issue = item['issue']?.toString() ?? '';
                      final suggestion = item['suggestion']?.toString() ?? '';
                      return _WordScoreBar(
                        word: word,
                        score: score,
                        color: _scoreColor(score),
                        issue: issue,
                        suggestion: suggestion,
                        onPractice: () => _openPronunciationLessonForWord(word),
                      );
                    }),
                  ],

                  const SizedBox(height: 16),
                  
                  // Gemini Summary & Insights (SECOND)
                  if (successState.summary.isNotEmpty || successState.suggestions.isNotEmpty)
                    _SectionCard(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: theme.colorScheme.primary,
                      label: 'AI Feedback & Insights',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (successState.summary.isNotEmpty)
                            Text(
                              successState.summary,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                              ),
                            ),
                          if (successState.suggestions.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 12),
                            Text(
                              'GROWTH SUGGESTIONS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...successState.suggestions.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(s)),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final practiceProvider = speakingSessionNotifierProvider(widget.item);
    final practiceState = ref.watch(practiceProvider);
    final practiceNotifier = ref.read(practiceProvider.notifier);
    final speech = ref.watch(speechProviderNotifier);

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isAnalysisCard = practiceState.isCompleted;
              final sentence = practiceState.currentSentence;
              final sentenceWordSpans = _wordSpans(sentence);
              final engine = ref.watch(speakingEngineProvider(widget.item));
              final targetTokens = engine
                  .tokenize(sentence)
                  .where((t) => !t.ignored)
                  .map((t) => t.normalized)
                  .where((token) => token.isNotEmpty)
                  .toList();
              final spokenTokens = engine
                  .tokenize(speech.currentTranscript)
                  .where((t) => !t.ignored)
                  .map((t) => t.normalized)
                  .toSet();
              final confidence = (speech.lastConfidence ?? 0.0).clamp(0.0, 1.0);
              final liveWordConfidence = speech.liveWordConfidence;
              final matchedConfidences = targetTokens
                  .where(spokenTokens.contains)
                  .map((word) => speech.confidenceForWord(word) ?? confidence)
                  .toList();
              final averageWordConfidence = matchedConfidences.isEmpty
                  ? confidence
                  : matchedConfidences.reduce((a, b) => a + b) / matchedConfidences.length;
                  
              if (!isAnalysisCard) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  practiceNotifier.updateWordConfidenceReport(
                    sentence: sentence,
                    targetTokens: targetTokens,
                    spokenTokens: spokenTokens,
                    confidence: confidence,
                    liveWordConfidence: liveWordConfidence,
                  );
                });
              }
              
              final rate = _matchRate(targetTokens, spokenTokens);
              final isLastSentence = practiceState.currentSentenceIndex == practiceState.script.length - 1;
              final nextLocked = isLastSentence && !practiceState.hasAttemptedCurrentSentence;
              final showEmojiCoach = !isAnalysisCard &&
                  (speech.isListening || practiceState.isTtsSpeaking || spokenTokens.isNotEmpty);

              if (isAnalysisCard) {
                final payload = practiceState.latestWordConfidenceJson.trim();
                final bool isAnalyzingSession = practiceState.uiState is SpeakingExerciseAnalyzing;
                final canAutoRun = payload.isNotEmpty &&
                    payload != '{}' &&
                    !isAnalyzingSession &&
                    _lastAutoAnalyzedPayload != payload;
                    
                if (canAutoRun) {
                  _lastAutoAnalyzedPayload = payload;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    practiceNotifier.runGeminiSessionAnalysis();
                  });
                }
              }

              final compact = constraints.maxHeight < 760;
              final sectionGap = compact ? 8.0 : 12.0;
              final centerFlex = compact ? 7 : 8;
              final bottomFlex = compact ? 3 : 2;

              return Column(
                children: [
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 10 : 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.record_voice_over_rounded, color: colors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isAnalysisCard
                                  ? 'Final card: analyze your full session JSON and get word-specific suggestions.'
                                  : 'Read each sentence out loud. Words turn green/orange/red based on live confidence.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: sectionGap),
                  if (showEmojiCoach) ...[
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 260),
                      tween: Tween<double>(
                        begin: 1.0,
                        end: speech.isListening ? (1.0 + (confidence * 0.22)) : 1.0,
                      ),
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 14,
                          vertical: compact ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: _wordColor(matched: true, confidence: confidence).withAlpha(28),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _wordColor(matched: true, confidence: confidence).withAlpha(90)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_emojiForConfidence(confidence), style: const TextStyle(fontSize: 28)),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                _emojiHintForConfidence(confidence),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: sectionGap),
                  ],
                  Expanded(
                    flex: centerFlex,
                    child: isAnalysisCard
                        ? _buildAnalysisPage(context, practiceState, practiceNotifier)
                        : Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 2,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.all(compact ? 12 : 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'Sentence ${practiceState.currentSentenceIndex + 1}/${practiceState.script.length}',
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: compact ? 6 : 10),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      IconButton.filledTonal(
                                        onPressed: practiceState.currentSentenceIndex == 0
                                            ? null
                                            : () => _goToPreviousSentence(speech, practiceNotifier),
                                        icon: const Icon(Icons.chevron_left_rounded),
                                        tooltip: 'Previous sentence',
                                      ),
                                      IconButton.filled(
                                        onPressed: () => _speakCurrentSentence(sentence, practiceState.ttsSpeed),
                                        icon: const Icon(Icons.volume_up_rounded),
                                        tooltip: 'Play sentence',
                                      ),
                                      IconButton.filledTonal(
                                        onPressed: nextLocked ? null : () => _goToNextSentence(speech, practiceNotifier),
                                        icon: Icon(nextLocked ? Icons.lock_rounded : Icons.chevron_right_rounded),
                                        tooltip: nextLocked ? 'Attempt this sentence once to unlock analysis' : 'Next sentence',
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: compact ? 10 : 16),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: List<Widget>.generate(
                                      sentenceWordSpans.length,
                                      (index) {
                                        final span = sentenceWordSpans[index];
                                        final isIgnored = _isIgnoredWordSpan(span);
                                        final matched = !isIgnored && spokenTokens.contains(span.normalized);
                                        final wordConfidence = (isIgnored || !matched)
                                            ? 0.0
                                            : (speech.confidenceForWord(span.normalized) ?? confidence);
                                        final color = isIgnored ? Colors.blueGrey.shade600 : _wordColor(matched: matched, confidence: wordConfidence);
                                        final isTtsWord = practiceState.isTtsSpeaking && index == practiceState.ttsWordIndex;
                                        final maxChipWidth = (MediaQuery.of(context).size.width * 0.28).clamp(86.0, 150.0);
                                        return InkWell(
                                          borderRadius: BorderRadius.circular(20),
                                          onTap: isIgnored ? null : () => _openWordPronunciationLab(context, span.raw, practiceState.ttsSpeed),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 140),
                                            constraints: BoxConstraints(maxWidth: maxChipWidth),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: isIgnored ? Colors.blueGrey.shade50 : (isTtsWord ? colors.primary.withAlpha(40) : color.withAlpha(30)),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: isIgnored ? Colors.blueGrey.shade300 : (isTtsWord ? colors.primary : color)),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  span.raw,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: theme.textTheme.bodyLarge?.copyWith(
                                                    color: isIgnored ? Colors.blueGrey.shade700 : (isTtsWord ? colors.primary : color),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (_translationForWord(span.normalized).isNotEmpty)
                                                  Text(
                                                    _translationForWord(span.normalized),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: colors.onSurfaceVariant,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: compact ? 10 : 18),
                                  if (!practiceState.isCompleted)
                                    Text(
                                      'Match: ${(rate * 100).toStringAsFixed(0)}%  |  Word conf: ${(averageWordConfidence * 100).toStringAsFixed(0)}%',
                                      style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                                    ),
                                  if (nextLocked) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Speak this final sentence once to unlock analysis.',
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                  ),
                  if (!isAnalysisCard) ...[
                    SizedBox(height: sectionGap),
                    Expanded(
                      flex: bottomFlex,
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        speech.currentTranscript.trim().isEmpty ? 'Start speaking...' : speech.currentTranscript,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        minimumSize: const Size(0, 34),
                                      ),
                                      onPressed: () => _toggleListening(speech, practiceNotifier, practiceState),
                                      icon: Icon(speech.isListening ? Icons.stop_rounded : Icons.mic_rounded, size: 18),
                                      label: Text(speech.isListening ? 'Stop' : 'Speak', style: theme.textTheme.labelMedium),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _LegendDot(color: Colors.green.shade600, label: 'high'),
                                    const SizedBox(width: 14),
                                    _LegendDot(color: Colors.orange.shade700, label: 'medium'),
                                    const SizedBox(width: 14),
                                    _LegendDot(color: Colors.red.shade600, label: 'low'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.speed_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('TTS speed'),
                                    Expanded(
                                      child: Slider(
                                        min: 0.25,
                                        max: 0.75,
                                        divisions: 10,
                                        value: practiceState.ttsSpeed,
                                        label: practiceState.ttsSpeed.toStringAsFixed(2),
                                        onChanged: (value) {
                                          practiceNotifier.setTtsSpeed(value);
                                          _tts.setSpeechRate(value);
                                        },
                                      ),
                                    ),
                                    Text(practiceState.ttsSpeed.toStringAsFixed(2), style: theme.textTheme.labelSmall),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WordSpan {
  final String raw;
  final String normalized;
  final int start;
  final int end;

  const _WordSpan({required this.raw, required this.normalized, required this.start, required this.end});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  const _SectionCard({required this.icon, required this.iconColor, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(color: iconColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _WordScoreBar extends StatelessWidget {
  final String word;
  final double score;
  final String? issue;
  final String? suggestion;
  final VoidCallback? onPractice;
  final Color color;

  const _WordScoreBar({
    required this.word,
    required this.score,
    required this.color,
    this.issue,
    this.suggestion,
    this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLow = score < 60;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              Text(
                '${score.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          if ((issue?.isNotEmpty ?? false) || (suggestion?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 12),
            if (issue?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        issue!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (suggestion?.isNotEmpty ?? false)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      suggestion!,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
          ],
          if (isLow && onPractice != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onPractice,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.record_voice_over_rounded, size: 18),
                label: const Text('Practice Word'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

