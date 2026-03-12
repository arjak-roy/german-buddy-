class PronunciationPhonemeFeedback {
  final String phoneme;
  final int score;
  final String lipShape;
  final String observed;
  final String issue;
  final String suggestion;

  const PronunciationPhonemeFeedback({
    required this.phoneme,
    required this.score,
    required this.lipShape,
    required this.observed,
    required this.issue,
    required this.suggestion,
  });

  factory PronunciationPhonemeFeedback.fromMap(Map<String, dynamic> map) {
    int parseScore(dynamic value) {
      if (value is int) return value.clamp(0, 100);
      if (value is num) return value.round().clamp(0, 100);
      if (value is String) {
        return (int.tryParse(value) ?? 0).clamp(0, 100);
      }
      return 0;
    }

    return PronunciationPhonemeFeedback(
      phoneme: (map['phoneme'] ?? '').toString().trim(),
      score: parseScore(map['score']),
      lipShape: (map['lipShape'] ?? '').toString().trim(),
      observed: (map['observed'] ?? '').toString().trim(),
      issue: (map['issue'] ?? '').toString().trim(),
      suggestion: (map['suggestion'] ?? '').toString().trim(),
    );
  }
}

class PronunciationAnalysisReport {
  final int overallScore;
  final String summary;
  final String heardText;
  final String mouthShapeGuide;
  final List<String> strengths;
  final List<String> priorities;
  final String nextTry;
  final List<PronunciationPhonemeFeedback> phonemeBreakdown;

  const PronunciationAnalysisReport({
    required this.overallScore,
    required this.summary,
    required this.heardText,
    required this.mouthShapeGuide,
    required this.strengths,
    required this.priorities,
    required this.nextTry,
    required this.phonemeBreakdown,
  });

  factory PronunciationAnalysisReport.fromMap(Map<String, dynamic> map) {
    int parseScore(dynamic value) {
      if (value is int) return value.clamp(0, 100);
      if (value is num) return value.round().clamp(0, 100);
      if (value is String) {
        return (int.tryParse(value) ?? 0).clamp(0, 100);
      }
      return 0;
    }

    List<String> parseStrings(dynamic value) {
      if (value is List) {
        return value.map((entry) => entry.toString().trim()).toList();
      }
      return const <String>[];
    }

    List<PronunciationPhonemeFeedback> parseBreakdown(dynamic value) {
      if (value is! List) return const <PronunciationPhonemeFeedback>[];
      return value
          .whereType<Map>()
          .map(
            (entry) => PronunciationPhonemeFeedback.fromMap(
              Map<String, dynamic>.from(entry),
            ),
          )
          .toList();
    }

    return PronunciationAnalysisReport(
      overallScore: parseScore(map['overallScore']),
      summary: (map['summary'] ?? '').toString().trim(),
      heardText: (map['heardText'] ?? '').toString().trim(),
      mouthShapeGuide: (map['mouthShapeGuide'] ?? '').toString().trim(),
      strengths: parseStrings(map['strengths']),
      priorities: parseStrings(map['priorities']),
      nextTry: (map['nextTry'] ?? '').toString().trim(),
      phonemeBreakdown: parseBreakdown(map['phonemeBreakdown']),
    );
  }
}
