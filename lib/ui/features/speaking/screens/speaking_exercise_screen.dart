import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../../data/services/gemini_service.dart';
import '../../../../providers/app_providers.dart';
import '../../../../providers/introduce_yourself_practice_provider.dart';
import '../../../../providers/speech_provider.dart';
import '../../pronunciation/models/pronunciation_item.dart';
import '../../pronunciation/screens/pronunciation_lesson_screen.dart';
import '../../pronunciation/widgets/pronunciation_mini_lab.dart';
import '../models/speaking_exercise_item.dart';

const List<String> _introduceYourselfScript = [
  'Hallo, ich heiße [Your Name]',
  'Ich komme aus Indien und wohne jetzt in Berlin.',
  'Ich lerne Deutsch, weil ich hier arbeiten mochte.',
];

const String _introduceYourselfSpokenName = 'Arjak';

const Map<String, String> _introduceYourselfWordTranslations = {
  'hallo': 'hello',
  'ich': 'I',
  'heiße': 'am called',
  'your name': 'your name',
  '...': '[Your Name]',
  'komme': 'come',
  'aus': 'from',
  'indien': 'India',
  'und': 'and',
  'wohne': 'live',
  'jetzt': 'now',
  'in': 'in',
  'berlin': 'Berlin',
  'lerne': 'learn',
  'deutsch': 'German',
  'weil': 'because',
  'hier': 'here',
  'arbeiten': 'work',
  'mochte': 'would like to',
};

// Add custom placeholders/words here to exclude them from matching and score.
// Examples: '[Your Name]' (bracket placeholder) and free-form literal tokens.
const Set<String> _introduceYourselfIgnoredWords = {
  'your name',
  '...'
};

final introduceYourselfPracticeProviderNotifier =
    ChangeNotifierProvider.autoDispose<IntroduceYourselfPracticeProvider>((ref) {
  throw UnimplementedError(
    'introduceYourselfPracticeProviderNotifier must be overridden in ProviderScope.',
  );
});

class SpeakingExerciseScreen extends StatelessWidget {
  final SpeakingExerciseItem item;

  const SpeakingExerciseScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isIntroduceYourself = item.title.toLowerCase() == 'introduce yourself';

    if (isIntroduceYourself) {
      return ProviderScope(
        overrides: [
          introduceYourselfPracticeProviderNotifier.overrideWith(
            (ref) => IntroduceYourselfPracticeProvider(
              script: _introduceYourselfScript,
            ),
          ),
        ],
        child: _IntroduceYourselfExerciseScreen(item: item),
      );
    }

    return _GenericSpeakingExerciseScreen(item: item);
  }
}

class _GenericSpeakingExerciseScreen extends StatelessWidget {
  final SpeakingExerciseItem item;

  const _GenericSpeakingExerciseScreen({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(item.title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Scenario card
          _SectionCard(
            icon: Icons.theater_comedy_rounded,
            iconColor: colors.primary,
            label: 'Scenario',
            child: Text(
              item.scenario,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),

          // Prompt card
          _SectionCard(
            icon: Icons.record_voice_over_rounded,
            iconColor: Colors.blueAccent,
            label: 'Your Task',
            child: Text(
              item.prompt,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Useful phrases
          _SectionCard(
            icon: Icons.lightbulb_outline_rounded,
            iconColor: Colors.amber,
            label: 'Useful Phrases',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: item.usefulPhrases
                  .map(
                    (phrase) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(
                              phrase,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 32),

          // Coming soon banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withAlpha(120),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.primary.withAlpha(80)),
            ),
            child: Column(
              children: [
                Icon(Icons.mic_rounded, size: 40, color: colors.primary),
                const SizedBox(height: 12),
                Text(
                  'Interactive recording coming soon!',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'You will be able to record your response and get AI feedback on your pronunciation and fluency.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _IntroduceYourselfExerciseScreen extends ConsumerStatefulWidget {
  final SpeakingExerciseItem item;

  const _IntroduceYourselfExerciseScreen({required this.item});

  @override
  ConsumerState<_IntroduceYourselfExerciseScreen> createState() =>
      _IntroduceYourselfExerciseScreenState();
}

class _IntroduceYourselfExerciseScreenState
    extends ConsumerState<_IntroduceYourselfExerciseScreen> {
  late final FlutterTts _tts;
  final GeminiService _gemini = GeminiService();
  bool _isAnalyzingSession = false;
  String? _analysisError;
  String? _analysisSummary;
  double? _overallAnalysisScore;
  List<String> _analysisSuggestions = const [];
  List<_SessionWordAnalysis> _wordAnalysis = const [];
  String? _lastAutoAnalyzedPayload;

  @override
  void initState() {
    super.initState();
    final practice = ref.read(introduceYourselfPracticeProviderNotifier);
    _tts = FlutterTts();
    _tts.setLanguage('de-DE');
    _tts.setSpeechRate(practice.ttsSpeed);
    _tts.setPitch(1.0);
    _tts.awaitSpeakCompletion(false);
    _tts.setStartHandler(() {
      if (!mounted) return;
      ref.read(introduceYourselfPracticeProviderNotifier).setTtsStarted();
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      ref.read(introduceYourselfPracticeProviderNotifier).setTtsStopped();
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      ref.read(introduceYourselfPracticeProviderNotifier).setTtsStopped();
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      ref.read(introduceYourselfPracticeProviderNotifier).setTtsStopped();
    });
    _tts.setProgressHandler((text, startOffset, endOffset, _) {
      if (!mounted) return;
      final practice = ref.read(introduceYourselfPracticeProviderNotifier);
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

      if (idx != -1 && idx != practice.ttsWordIndex) {
        practice.setTtsWordIndex(idx);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final speech = ref.read(speechProviderNotifier);
      speech.setLanguage(SpeechLanguage.german);
      speech.clearTranscript();
      speech.ensureInitialized();
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  List<String> _tokenize(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9A-ZäöüßÄÖÜ' ]"), ' ')
        .trim();
    if (cleaned.isEmpty) return const [];
    return cleaned
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
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
    final raw = span.raw.trim().toLowerCase();
    if (raw.isEmpty) return true;
    if (RegExp(r'^\[[^\]]+\]$').hasMatch(raw)) return true;
    if (_introduceYourselfIgnoredWords.contains(raw)) return true;
    return _introduceYourselfIgnoredWords.contains(span.normalized);
  }

  String _translationForWord(String normalizedWord) {
    return _introduceYourselfWordTranslations[normalizedWord] ?? '';
  }

  List<_WordSpan> _wordSpans(String sentence) {
    final matches = RegExp(r'\[[^\]]+\]|\S+').allMatches(sentence);
    return matches
        .map(
          (m) => _WordSpan(
            raw: m.group(0) ?? '',
            normalized: _normalizeSpanToken(m.group(0) ?? ''),
            start: m.start,
            end: m.end,
          ),
        )
        .where((span) => span.raw.isNotEmpty)
        .toList();
  }

  double _matchRate(List<String> target, Set<String> spoken) {
    if (target.isEmpty) return 0;
    var matched = 0;
    for (final token in target) {
      if (spoken.contains(token)) {
        matched += 1;
      }
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
    final ttsSentence = sentence.replaceAllMapped(
      RegExp(r'\[\s*your\s+name\s*\]', caseSensitive: false),
      (_) => _introduceYourselfSpokenName,
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

  void _goToPreviousSentence(SpeechProvider speech) {
    speech.clearTranscript();
    ref.read(introduceYourselfPracticeProviderNotifier).goToPreviousSentence();
  }

  void _goToNextSentence(SpeechProvider speech) {
    speech.clearTranscript();
    final practice = ref.read(introduceYourselfPracticeProviderNotifier);
    final moved = practice.goToNextSentence();
    if (!moved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempt the last sentence once to unlock analysis.'),
        ),
      );
    }
  }

  Future<void> _toggleListening(SpeechProvider speech) async {
    if (ref.read(introduceYourselfPracticeProviderNotifier).isCompleted) return;
    if (speech.isListening) {
      final capture = await speech.stopListeningAndCollect();
      if ((capture?.text.trim().isNotEmpty ?? false) && mounted) {
        ref
            .read(introduceYourselfPracticeProviderNotifier)
            .markCurrentSentenceAttempted();
      }
      return;
    }

    speech.clearTranscript();
    await speech.startListening();
  }

  Future<void> _openWordPronunciationLab(
    BuildContext context,
    String word,
    double _,
  ) async {
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
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
      MaterialPageRoute<void>(
        builder: (_) => PronunciationLessonScreen(item: item),
      ),
    );
  }

  String _analysisSystemPrompt() {
    return 'You are a German speaking coach for the "Introduce Yourself" exercise. '
        'You receive a JSON object with sentence-level and word-level confidence data. '
        'Analyze learner performance and return STRICT JSON only with this schema: '
        '{"overallScore": number(0-100), "summary": string, "suggestions": string[], '
        '"wordAnalysis": [{"word": string, "score": number(0-100), "issue": string, '
        '"suggestion": string, "status": "high|medium|low"}]}. '
        'Rules: 1) Focus on pronunciation clarity and consistency, '
        '2) Use lower score for low-confidence words, 3) Keep suggestions specific and actionable, '
        '4) Mention German mouth shape or stress where helpful, 5) No markdown, no prose outside JSON.';
  }

  Map<String, dynamic>? _extractJsonObject(String raw) {
    final codeBlock = RegExp(r'```json\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(raw)
        ?.group(1);
    final candidate = (codeBlock ?? raw).trim();

    try {
      final decoded = jsonDecode(candidate);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        final decoded = jsonDecode(candidate.substring(start, end + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  Map<String, double> _sessionWordScoresFromPayload(Map<String, dynamic> payload) {
    final out = <String, List<double>>{};
    final sentences = payload['sentences'];
    if (sentences is! List) return const {};

    for (final sentence in sentences) {
      if (sentence is! Map<String, dynamic>) continue;
      final words = sentence['words'];
      if (words is! List) continue;
      for (final entry in words) {
        if (entry is! Map<String, dynamic>) continue;
        final word = (entry['word'] ?? '').toString().trim().toLowerCase();
        if (word.isEmpty) continue;
        final c = (entry['confidence'] as num?)?.toDouble() ?? 0.0;
        out.putIfAbsent(word, () => <double>[]).add(c);
      }
    }

    return out.map((word, values) {
      final avg = values.isEmpty
          ? 0.0
          : values.reduce((a, b) => a + b) / values.length;
      return MapEntry(word, (avg * 100).clamp(0.0, 100.0));
    });
  }

  List<_SentenceScore> _sentenceScoresFromPayload(Map<String, dynamic> payload) {
    final out = <_SentenceScore>[];
    final sentences = payload['sentences'];
    if (sentences is! List) return out;

    for (final sentence in sentences) {
      if (sentence is! Map<String, dynamic>) continue;
      final index = (sentence['sentenceIndex'] as num?)?.toInt() ?? 0;
      final text = (sentence['sentenceText'] ?? '').toString();
      final words = sentence['words'];
      if (words is! List || words.isEmpty) {
        out.add(_SentenceScore(index: index, text: text, score: 0));
        continue;
      }

      var total = 0.0;
      for (final word in words) {
        if (word is! Map<String, dynamic>) continue;
        total += (word['confidence'] as num?)?.toDouble() ?? 0.0;
      }
      final avg = words.isEmpty ? 0.0 : total / words.length;
      out.add(
        _SentenceScore(
          index: index,
          text: text,
          score: (avg * 100).clamp(0.0, 100.0),
        ),
      );
    }

    out.sort((a, b) => a.index.compareTo(b.index));
    return out;
  }

  Widget _buildScoreBar({
    required String label,
    required double score,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (score / 100).clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: const Color(0xFFE2E8F0),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              score.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  List<_SessionWordAnalysis> _fallbackAnalysis(Map<String, dynamic> payload) {
    final scores = _sessionWordScoresFromPayload(payload);
    final list = scores.entries
        .map((entry) {
          final score = entry.value;
          final status = score >= 75
              ? 'high'
              : (score >= 50 ? 'medium' : 'low');
          final issue = status == 'high'
              ? 'Stable and clear production.'
              : (status == 'medium'
                  ? 'Inconsistent clarity across attempts.'
                  : 'Unclear pronunciation and low confidence.');
          final suggestion = status == 'high'
              ? 'Keep this word at natural speed.'
              : (status == 'medium'
                  ? 'Slow down and exaggerate vowels once, then repeat.'
                  : 'Practice syllable by syllable and focus on mouth shape.');
          return _SessionWordAnalysis(
            word: entry.key,
            score: score,
            status: status,
            issue: issue,
            suggestion: suggestion,
          );
        })
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));

    return list;
  }

  List<_SessionWordAnalysis> _parseWordAnalysis(Map<String, dynamic> responseJson) {
    final items = responseJson['wordAnalysis'];
    if (items is! List) return const [];

    return items
        .whereType<Map>()
        .map((item) {
          final map = item.cast<String, dynamic>();
          return _SessionWordAnalysis(
            word: (map['word'] ?? '').toString().trim().toLowerCase(),
            score: ((map['score'] as num?)?.toDouble() ?? 0.0).clamp(0.0, 100.0),
            status: (map['status'] ?? '').toString().toLowerCase(),
            issue: (map['issue'] ?? '').toString().trim(),
            suggestion: (map['suggestion'] ?? '').toString().trim(),
          );
        })
        .where((e) => e.word.isNotEmpty)
        .toList();
  }

  Future<void> _runGeminiSessionAnalysis(
    IntroduceYourselfPracticeProvider practice,
  ) async {
    final jsonPayload = practice.latestWordConfidenceJson.trim();
    if (jsonPayload.isEmpty || jsonPayload == '{}') {
      setState(() {
        _analysisError = 'No session JSON data available yet.';
      });
      return;
    }

    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(jsonPayload) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    setState(() {
      _isAnalyzingSession = true;
      _analysisError = null;
    });

    try {
      final prompt = 'Exercise: Introduce Yourself\\n'
          'Input JSON:\\n$jsonPayload\\n'
          'Analyze this session and return the required strict JSON schema.';

      final raw = await _gemini.ask(prompt, _analysisSystemPrompt(), true);
      final parsed = _extractJsonObject(raw);

      if (parsed == null) {
        if (payload == null) {
          throw StateError('Could not parse analysis JSON response.');
        }
        final fallback = _fallbackAnalysis(payload);
        final overall = fallback.isEmpty
            ? 0.0
            : fallback.map((e) => e.score).reduce((a, b) => a + b) /
                fallback.length;
        setState(() {
          _overallAnalysisScore = overall;
          _analysisSummary =
              'Fallback analysis used because Gemini did not return valid JSON.';
          _analysisSuggestions = const [
            'Re-record difficult words slowly.',
            'Use pronunciation practice buttons for low-score words.',
            'Repeat each sentence at least twice for stability.',
          ];
          _wordAnalysis = fallback;
        });
        return;
      }

      final words = _parseWordAnalysis(parsed);
      if (words.isEmpty && payload != null) {
        final fallback = _fallbackAnalysis(payload);
        setState(() {
          _overallAnalysisScore =
              ((parsed['overallScore'] as num?)?.toDouble() ??
                      (fallback.isEmpty
                          ? 0.0
                          : fallback
                                  .map((e) => e.score)
                                  .reduce((a, b) => a + b) /
                              fallback.length))
                  .clamp(0.0, 100.0);
          _analysisSummary = (parsed['summary'] ?? '').toString().trim();
          _analysisSuggestions = (parsed['suggestions'] is List)
              ? (parsed['suggestions'] as List)
                  .map((e) => e.toString())
                  .where((e) => e.trim().isNotEmpty)
                  .toList()
              : const [];
          _wordAnalysis = fallback;
        });
        return;
      }

      setState(() {
        _overallAnalysisScore =
            ((parsed['overallScore'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 100.0);
        _analysisSummary = (parsed['summary'] ?? '').toString().trim();
        _analysisSuggestions = (parsed['suggestions'] is List)
            ? (parsed['suggestions'] as List)
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty)
                .toList()
            : const [];
        _wordAnalysis = words..sort((a, b) => a.score.compareTo(b.score));
      });
    } catch (e) {
      setState(() {
        _analysisError = 'Analysis failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzingSession = false;
        });
      }
    }
  }

  Color _scoreColor(double score) {
    if (score >= 75) return Colors.green.shade700;
    if (score >= 50) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  Widget _buildAnalysisPage(
    BuildContext context,
    IntroduceYourselfPracticeProvider practice,
  ) {
    final theme = Theme.of(context);
    Map<String, dynamic>? payload;
    try {
      payload = jsonDecode(practice.latestWordConfidenceJson) as Map<String, dynamic>;
    } catch (_) {
      payload = null;
    }

    final sessionWordScores =
        payload == null ? const <String, double>{} : _sessionWordScoresFromPayload(payload);
    final sentenceScores =
        payload == null ? const <_SentenceScore>[] : _sentenceScoresFromPayload(payload);
    final sortedWords = sessionWordScores.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final weakWords = sortedWords.where((e) => e.value < 50).toList();
    final avgSessionScore = sortedWords.isEmpty
        ? 0.0
        : sortedWords.map((e) => e.value).reduce((a, b) => a + b) /
            sortedWords.length;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
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
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This is the final analysis card. Your full session JSON is sent to Gemini for word-specific feedback.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricChip(
                  label: 'Words',
                  value: sortedWords.length.toString(),
                  color: Colors.blue.shade700,
                ),
                _MetricChip(
                  label: 'Weak words',
                  value: weakWords.length.toString(),
                  color: Colors.red.shade700,
                ),
                _MetricChip(
                  label: 'Session avg',
                  value: avgSessionScore.toStringAsFixed(0),
                  color: _scoreColor(avgSessionScore),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isAnalyzingSession
                      ? null
                      : () => _runGeminiSessionAnalysis(practice),
                  icon: _isAnalyzingSession
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isAnalyzingSession
                      ? 'Analyzing...'
                      : 'Analyze with Gemini'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Sentence Bar Graph',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (sentenceScores.isEmpty)
              const Text('No sentence scores yet.')
            else
              ...sentenceScores.map(
                (s) => _buildScoreBar(
                  label: 'S${s.index + 1}',
                  score: s.score,
                  color: _scoreColor(s.score),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Word Bar Graph (lowest first)',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            if (sortedWords.isEmpty)
              const Text('No word data yet.')
            else
              ...sortedWords.take(12).map(
                (entry) => _buildScoreBar(
                  label: entry.key,
                  score: entry.value,
                  color: _scoreColor(entry.value),
                ),
              ),
            if (_analysisError != null) ...[
              const SizedBox(height: 10),
              Text(
                _analysisError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_overallAnalysisScore != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _scoreColor(_overallAnalysisScore!).withAlpha(28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _scoreColor(_overallAnalysisScore!)),
                ),
                child: Row(
                  children: [
                    Text(
                      _overallAnalysisScore!.toStringAsFixed(0),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: _scoreColor(_overallAnalysisScore!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Overall score'),
                  ],
                ),
              ),
            ],
            if ((_analysisSummary ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_analysisSummary!, style: theme.textTheme.bodyMedium),
            ],
            if (_analysisSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Suggestions',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              ..._analysisSuggestions.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $s'),
                ),
              ),
            ],
            if (_wordAnalysis.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Word specific scores',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              ...List<Widget>.generate(_wordAnalysis.length, (index) {
                final item = _wordAnalysis[index];
                final color = _scoreColor(item.score);
                final low = item.score < 50;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withAlpha(120)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.word,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              item.score.toStringAsFixed(0),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (item.issue.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.issue),
                        ],
                        if (item.suggestion.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(item.suggestion),
                        ],
                        if (low) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () => _openPronunciationLessonForWord(item.word),
                            icon: const Icon(Icons.record_voice_over_rounded),
                            label: const Text('Practice this word'),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
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
    final practice = ref.watch(introduceYourselfPracticeProviderNotifier);
    final speech = ref.watch(speechProviderNotifier);

    return Scaffold(
      appBar: AppBar(title: Text(widget.item.title)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isAnalysisCard = practice.isCompleted;
              final sentence = practice.currentSentence;
              final sentenceWordSpans = _wordSpans(sentence);
              final targetTokens = sentenceWordSpans
                  .where((span) => !_isIgnoredWordSpan(span))
                  .map((span) => span.normalized)
                  .where((token) => token.isNotEmpty)
                  .toList();
              final spokenTokens = _tokenize(speech.currentTranscript).toSet();
              final confidence = (speech.lastConfidence ?? 0.0).clamp(0.0, 1.0);
              final liveWordConfidence = speech.liveWordConfidence;
              final matchedConfidences = targetTokens
                  .where(spokenTokens.contains)
                  .map((word) => speech.confidenceForWord(word) ?? confidence)
                  .toList();
              final averageWordConfidence = matchedConfidences.isEmpty
                  ? confidence
                  : matchedConfidences.reduce((a, b) => a + b) /
                      matchedConfidences.length;
              if (!isAnalysisCard) {
                practice.updateWordConfidenceReport(
                  sentence: sentence,
                  targetTokens: targetTokens,
                  spokenTokens: spokenTokens,
                  confidence: confidence,
                  liveWordConfidence: liveWordConfidence,
                  notify: false,
                );
              }
              final rate = _matchRate(targetTokens, spokenTokens);
              final isLastSentence =
                  practice.currentSentenceIndex == practice.script.length - 1;
              final nextLocked = isLastSentence && !practice.hasAttemptedCurrentSentence;
              final showEmojiCoach =
                  !isAnalysisCard &&
                  (speech.isListening ||
                      practice.isTtsSpeaking ||
                      spokenTokens.isNotEmpty);

              if (isAnalysisCard) {
                final payload = practice.latestWordConfidenceJson.trim();
                final canAutoRun = payload.isNotEmpty &&
                    payload != '{}' &&
                    !_isAnalyzingSession &&
                    _lastAutoAnalyzedPayload != payload;
                if (canAutoRun) {
                  _lastAutoAnalyzedPayload = payload;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    _runGeminiSessionAnalysis(practice);
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 10 : 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.record_voice_over_rounded,
                                color: colors.primary,
                              ),
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
                            end: speech.isListening
                                ? (1.0 + (confidence * 0.22))
                                : 1.0,
                          ),
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: EdgeInsets.symmetric(
                              horizontal: compact ? 10 : 14,
                              vertical: compact ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: _wordColor(matched: true, confidence: confidence)
                                  .withAlpha(28),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    _wordColor(matched: true, confidence: confidence)
                                        .withAlpha(90),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _emojiForConfidence(confidence),
                                  style: const TextStyle(fontSize: 28),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    _emojiHintForConfidence(confidence),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
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
                            ? _buildAnalysisPage(context, practice)
                            : Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 2,
                          child: SingleChildScrollView(
                            padding: EdgeInsets.all(compact ? 12 : 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Sentence ${practice.currentSentenceIndex + 1}/${practice.script.length}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: compact ? 6 : 10),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    IconButton.filledTonal(
                                      onPressed: practice.currentSentenceIndex == 0
                                          ? null
                                          : () => _goToPreviousSentence(speech),
                                      icon: const Icon(Icons.chevron_left_rounded),
                                      tooltip: 'Previous sentence',
                                    ),
                                    IconButton.filled(
                                      onPressed: () => _speakCurrentSentence(
                                        sentence,
                                        practice.ttsSpeed,
                                      ),
                                      icon: const Icon(Icons.volume_up_rounded),
                                      tooltip: 'Play sentence',
                                    ),
                                    IconButton.filledTonal(
                                      onPressed: nextLocked
                                          ? null
                                          : () => _goToNextSentence(speech),
                                      icon: Icon(
                                        nextLocked
                                            ? Icons.lock_rounded
                                            : Icons.chevron_right_rounded,
                                      ),
                                      tooltip: nextLocked
                                          ? 'Attempt this sentence once to unlock analysis'
                                          : 'Next sentence',
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
                                      final matched =
                                          !isIgnored &&
                                          spokenTokens.contains(span.normalized);
                                      final wordConfidence = (isIgnored || !matched)
                                          ? 0.0
                                          : (speech.confidenceForWord(
                                                  span.normalized,
                                                ) ??
                                                confidence);
                                      final color = isIgnored
                                          ? Colors.blueGrey.shade600
                                          : _wordColor(
                                              matched: matched,
                                              confidence: wordConfidence,
                                            );
                                      final isTtsWord = practice.isTtsSpeaking &&
                                          index == practice.ttsWordIndex;
                                      final maxChipWidth =
                                          (MediaQuery.of(context).size.width * 0.28)
                                              .clamp(86.0, 150.0);
                                      return InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: isIgnored
                                            ? null
                                            : () => _openWordPronunciationLab(
                                                  context,
                                                  span.raw,
                                                  practice.ttsSpeed,
                                                ),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 140),
                                          constraints: BoxConstraints(
                                            maxWidth: maxChipWidth,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isIgnored
                                                ? Colors.blueGrey.shade50
                                                : (isTtsWord
                                                    ? colors.primary.withAlpha(40)
                                                    : color.withAlpha(30)),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isIgnored
                                                  ? Colors.blueGrey.shade300
                                                  : (isTtsWord
                                                      ? colors.primary
                                                      : color),
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Text(
                                                span.raw,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: theme.textTheme.bodyLarge
                                                    ?.copyWith(
                                                  color: isIgnored
                                                      ? Colors.blueGrey.shade700
                                                      : (isTtsWord
                                                          ? colors.primary
                                                          : color),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              if (_translationForWord(
                                                      span.normalized,
                                                    )
                                                    .isNotEmpty)
                                                Text(
                                                  _translationForWord(
                                                    span.normalized,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color:
                                                        colors.onSurfaceVariant,
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
                                if (!practice.isCompleted)
                                  Text(
                                    'Match: ${(rate * 100).toStringAsFixed(0)}%  |  Word conf: ${(averageWordConfidence * 100).toStringAsFixed(0)}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                if (nextLocked) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Speak this final sentence once to unlock analysis.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  if (!isAnalysisCard) ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            speech.currentTranscript.trim().isEmpty
                                                ? 'Start speaking...'
                                                : speech.currentTranscript,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyMedium,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            minimumSize: const Size(0, 34),
                                          ),
                                          onPressed: () => _toggleListening(speech),
                                          icon: Icon(
                                            speech.isListening
                                                ? Icons.stop_rounded
                                                : Icons.mic_rounded,
                                            size: 18,
                                          ),
                                          label: Text(
                                            speech.isListening ? 'Stop' : 'Speak',
                                            style: theme.textTheme.labelMedium,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        _LegendDot(
                                          color: Colors.green.shade600,
                                          label: 'high',
                                        ),
                                        const SizedBox(width: 14),
                                        _LegendDot(
                                          color: Colors.orange.shade700,
                                          label: 'medium',
                                        ),
                                        const SizedBox(width: 14),
                                        _LegendDot(
                                          color: Colors.red.shade600,
                                          label: 'low',
                                        ),
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
                                            value: practice.ttsSpeed,
                                            label:
                                                practice.ttsSpeed.toStringAsFixed(2),
                                            onChanged: (value) {
                                              practice.setTtsSpeed(value);
                                              _tts.setSpeechRate(value);
                                            },
                                          ),
                                        ),
                                        Text(
                                          practice.ttsSpeed.toStringAsFixed(2),
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Word confidence JSON ready (${practice.latestWordConfidenceJson.length} chars)',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
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

class _SessionWordAnalysis {
  final String word;
  final double score;
  final String status;
  final String issue;
  final String suggestion;

  const _SessionWordAnalysis({
    required this.word,
    required this.score,
    required this.status,
    required this.issue,
    required this.suggestion,
  });
}

class _SentenceScore {
  final int index;
  final String text;
  final double score;

  const _SentenceScore({
    required this.index,
    required this.text,
    required this.score,
  });
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _WordSpan {
  final String raw;
  final String normalized;
  final int start;
  final int end;

  const _WordSpan({
    required this.raw,
    required this.normalized,
    required this.start,
    required this.end,
  });
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

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
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.bold,
                  ),
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
