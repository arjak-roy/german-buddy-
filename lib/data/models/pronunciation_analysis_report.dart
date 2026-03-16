class PronunciationPhonemeFeedback {
  final String phoneme;
  final String status; // 'correct', 'incorrect', 'partial'
  final String observed;
  final String lipShape;
  final String tip;

  const PronunciationPhonemeFeedback({
    required this.phoneme,
    required this.status,
    required this.observed,
    required this.lipShape,
    required this.tip,
  });

  factory PronunciationPhonemeFeedback.fromMap(Map<String, dynamic> map) {
    String parseStatus(dynamic value) {
      final status = (value ?? '').toString().trim().toLowerCase();
      if (['correct', 'incorrect', 'partial'].contains(status)) {
        return status;
      }
      return 'partial';
    }

    return PronunciationPhonemeFeedback(
      phoneme: (map['phoneme'] ?? '').toString().trim(),
      status: parseStatus(map['status']),
      observed: (map['observed'] ?? '').toString().trim(),
      lipShape: (map['lipShape'] ?? '').toString().trim(),
      tip: (map['tip'] ?? '').toString().trim(),
    );
  }
}

class PronunciationAnalysisReport {
  final int overallScore;
  final String heardText;
  final List<String> strengths;
  final List<String> priorities;
  final List<PronunciationPhonemeFeedback> phonemeBreakdown;
  final String nextTryInstruction;

  const PronunciationAnalysisReport({
    required this.overallScore,
    required this.heardText,
    required this.strengths,
    required this.priorities,
    required this.phonemeBreakdown,
    required this.nextTryInstruction,
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
      heardText: (map['heardText'] ?? '').toString().trim(),
      strengths: parseStrings(map['strengths']),
      priorities: parseStrings(map['priorities']),
      phonemeBreakdown: parseBreakdown(map['phonemeBreakdown']),
      nextTryInstruction: (map['nextTryInstruction'] ?? '').toString().trim(),
    );
  }
}
