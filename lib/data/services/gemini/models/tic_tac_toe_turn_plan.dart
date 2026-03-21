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
