import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/features/speaking/engine/speaking_engine.dart';
import '../ui/features/speaking/models/speaking_exercise_item.dart';

final speakingEngineProvider = Provider.family<SpeakingEngine, SpeakingExerciseItem>((
  ref,
  item,
) {
  // Derive a usable "script" from the item: prefer usefulPhrases, then prompt, then description.
  final script = (item.usefulPhrases.isNotEmpty)
      ? item.usefulPhrases
      : (item.prompt.isNotEmpty ? [item.prompt] : [item.description]);

  // Build ignored words set by looking for bracketed placeholders and literal ellipses.
  final extractedIgnored = <String>{};
  final bracketRE = RegExp(r"\[([^\]]+)\]");
  for (final s in script) {
    for (final m in bracketRE.allMatches(s)) {
      final token = m.group(1)?.trim().toLowerCase();
      if (token != null && token.isNotEmpty) extractedIgnored.add(token);
    }
    if (s.contains('...')) extractedIgnored.add('...');
  }

  return SpeakingEngine(
    script: script,
    translations: {},
    ignoreWords: extractedIgnored,
  );
});
