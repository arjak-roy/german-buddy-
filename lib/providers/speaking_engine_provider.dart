import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ui/features/speaking/engine/speaking_engine.dart';
import '../ui/features/speaking/engine/speaking_engine_models.dart';

final speakingEngineProvider = Provider.family<SpeakingEngine, SpeakingExercise>((
  ref,
  item,
) {
  // Use script from item.
  final script = item.script;

  // Build ignored words set by combining explicit ignoreWords and bracketed placeholders.
  final extractedIgnored = Set<String>.from(item.ignoreWords);
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
    translations: item.translations,
    ignoreWords: extractedIgnored,
  );
});
