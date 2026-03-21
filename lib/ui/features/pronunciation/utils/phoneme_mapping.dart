enum PronunciationViseme { neutral, openA, rounded, spread, consonant, tight }

class PhonemeDefinition {
  final String symbol;
  final PronunciationViseme viseme;
  final List<String> aliases;

  const PhonemeDefinition({
    required this.symbol,
    required this.viseme,
    required this.aliases,
  });
}

// Central inventory for known German phonemes plus practical aliases
// from IPA, simplified transliteration, and app phonetic hints.
const List<PhonemeDefinition> knownGermanPhonemes = [
  PhonemeDefinition(
    symbol: 'a',
    viseme: PronunciationViseme.openA,
    aliases: ['a', 'ah', 'aa', 'aː'],
  ),
  PhonemeDefinition(
    symbol: 'ɐ',
    viseme: PronunciationViseme.openA,
    aliases: ['ɐ', 'ar', 'er'],
  ),
  PhonemeDefinition(
    symbol: 'ɛ',
    viseme: PronunciationViseme.spread,
    aliases: ['ɛ', 'e', 'ä', 'eh'],
  ),
  PhonemeDefinition(
    symbol: 'eː',
    viseme: PronunciationViseme.spread,
    aliases: ['eː', 'ee', 'eh', 'é'],
  ),
  PhonemeDefinition(
    symbol: 'i',
    viseme: PronunciationViseme.spread,
    aliases: ['i', 'iː', 'ie', 'ii', 'ih'],
  ),
  PhonemeDefinition(
    symbol: 'ɪ',
    viseme: PronunciationViseme.spread,
    aliases: ['ɪ', 'i'],
  ),
  PhonemeDefinition(
    symbol: 'o',
    viseme: PronunciationViseme.rounded,
    aliases: ['o', 'oː', 'oh', 'oo'],
  ),
  PhonemeDefinition(
    symbol: 'ɔ',
    viseme: PronunciationViseme.rounded,
    aliases: ['ɔ', 'o'],
  ),
  PhonemeDefinition(
    symbol: 'u',
    viseme: PronunciationViseme.rounded,
    aliases: ['u', 'uː', 'uh', 'uu'],
  ),
  PhonemeDefinition(
    symbol: 'ʊ',
    viseme: PronunciationViseme.rounded,
    aliases: ['ʊ', 'u'],
  ),
  PhonemeDefinition(
    symbol: 'y',
    viseme: PronunciationViseme.rounded,
    aliases: ['y', 'yː', 'ü', 'ue'],
  ),
  PhonemeDefinition(
    symbol: 'ʏ',
    viseme: PronunciationViseme.rounded,
    aliases: ['ʏ', 'ü'],
  ),
  PhonemeDefinition(
    symbol: 'ø',
    viseme: PronunciationViseme.rounded,
    aliases: ['ø', 'øː', 'ö', 'oe'],
  ),
  PhonemeDefinition(
    symbol: 'œ',
    viseme: PronunciationViseme.rounded,
    aliases: ['œ', 'ö'],
  ),
  PhonemeDefinition(
    symbol: 'ə',
    viseme: PronunciationViseme.consonant,
    aliases: ['ə', 'schwa'],
  ),
  PhonemeDefinition(
    symbol: 'ʃ',
    viseme: PronunciationViseme.consonant,
    aliases: ['ʃ', 'sch'],
  ),
  PhonemeDefinition(
    symbol: 'ç',
    viseme: PronunciationViseme.consonant,
    aliases: ['ç', 'ch'],
  ),
  PhonemeDefinition(
    symbol: 'x',
    viseme: PronunciationViseme.consonant,
    aliases: ['x', 'ch'],
  ),
  PhonemeDefinition(
    symbol: 'j',
    viseme: PronunciationViseme.consonant,
    aliases: ['j', 'y'],
  ),
  PhonemeDefinition(
    symbol: 'h',
    viseme: PronunciationViseme.consonant,
    aliases: ['h'],
  ),
  PhonemeDefinition(
    symbol: 'r',
    viseme: PronunciationViseme.consonant,
    aliases: ['r'],
  ),
  PhonemeDefinition(
    symbol: 'l',
    viseme: PronunciationViseme.consonant,
    aliases: ['l'],
  ),
  PhonemeDefinition(
    symbol: 'n',
    viseme: PronunciationViseme.consonant,
    aliases: ['n'],
  ),
  PhonemeDefinition(
    symbol: 'm',
    viseme: PronunciationViseme.tight,
    aliases: ['m'],
  ),
  PhonemeDefinition(
    symbol: 'p',
    viseme: PronunciationViseme.tight,
    aliases: ['p'],
  ),
  PhonemeDefinition(
    symbol: 'b',
    viseme: PronunciationViseme.tight,
    aliases: ['b'],
  ),
  PhonemeDefinition(
    symbol: 'f',
    viseme: PronunciationViseme.tight,
    aliases: ['f'],
  ),
  PhonemeDefinition(
    symbol: 'v',
    viseme: PronunciationViseme.tight,
    aliases: ['v', 'w'],
  ),
  PhonemeDefinition(
    symbol: 'pf',
    viseme: PronunciationViseme.tight,
    aliases: ['pf'],
  ),
  PhonemeDefinition(
    symbol: 'ts',
    viseme: PronunciationViseme.consonant,
    aliases: ['ts', 'z', 'tz'],
  ),
  PhonemeDefinition(
    symbol: 't',
    viseme: PronunciationViseme.consonant,
    aliases: ['t'],
  ),
  PhonemeDefinition(
    symbol: 'd',
    viseme: PronunciationViseme.consonant,
    aliases: ['d'],
  ),
  PhonemeDefinition(
    symbol: 'k',
    viseme: PronunciationViseme.consonant,
    aliases: ['k', 'c'],
  ),
  PhonemeDefinition(
    symbol: 'g',
    viseme: PronunciationViseme.consonant,
    aliases: ['g'],
  ),
  PhonemeDefinition(
    symbol: 'ŋ',
    viseme: PronunciationViseme.consonant,
    aliases: ['ng'],
  ),
  PhonemeDefinition(
    symbol: 'aɪ',
    viseme: PronunciationViseme.openA,
    aliases: ['ei', 'ai', 'ay', 'aɪ'],
  ),
  PhonemeDefinition(
    symbol: 'aʊ',
    viseme: PronunciationViseme.openA,
    aliases: ['au', 'aʊ'],
  ),
  PhonemeDefinition(
    symbol: 'ɔʏ',
    viseme: PronunciationViseme.rounded,
    aliases: ['eu', 'äu', 'ɔʏ', 'oy'],
  ),
];

String _normalizeToken(String input) {
  return input
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9äöüßɐəɛeioɔuʊyʏøœʃçxŋː]"), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<String> _sortedAliases() {
  final out = <String>{};
  for (final phoneme in knownGermanPhonemes) {
    for (final alias in phoneme.aliases) {
      out.add(alias);
    }
  }
  final list = out.toList();
  list.sort((a, b) => b.length.compareTo(a.length));
  return list;
}

final List<String> _aliasScanOrder = _sortedAliases();

PhonemeDefinition? _definitionForAlias(String alias) {
  for (final p in knownGermanPhonemes) {
    if (p.aliases.contains(alias)) return p;
  }
  return null;
}

List<PhonemeDefinition> tokenizeToPhonemes(String raw) {
  final text = _normalizeToken(raw);
  if (text.isEmpty) return const [];

  final input = text.replaceAll(' ', '');
  final out = <PhonemeDefinition>[];
  var i = 0;

  while (i < input.length) {
    PhonemeDefinition? match;
    var matchLen = 0;

    for (final alias in _aliasScanOrder) {
      if (i + alias.length > input.length) continue;
      if (input.substring(i, i + alias.length) != alias) continue;

      final def = _definitionForAlias(alias);
      if (def == null) continue;
      match = def;
      matchLen = alias.length;
      break;
    }

    if (match != null) {
      out.add(match);
      i += matchLen;
      continue;
    }

    // Unknown char: treat as neutral consonant-like unit.
    out.add(
      const PhonemeDefinition(
        symbol: '?',
        viseme: PronunciationViseme.consonant,
        aliases: ['?'],
      ),
    );
    i += 1;
  }

  return out;
}

PronunciationViseme classifyVisemeForSegment(String segment) {
  final phonemes = tokenizeToPhonemes(segment);
  if (phonemes.isEmpty) return PronunciationViseme.neutral;

  // Prefer vowel-like visemes when present so mixed segments like "hai"
  // do not get stuck as consonant due to ties.
  for (final p in phonemes) {
    if (p.viseme == PronunciationViseme.openA ||
        p.viseme == PronunciationViseme.rounded ||
        p.viseme == PronunciationViseme.spread) {
      return p.viseme;
    }
  }

  final counts = <PronunciationViseme, int>{};
  for (final p in phonemes) {
    counts[p.viseme] = (counts[p.viseme] ?? 0) + 1;
  }

  PronunciationViseme winner = PronunciationViseme.neutral;
  var best = -1;
  for (final entry in counts.entries) {
    if (entry.value > best) {
      best = entry.value;
      winner = entry.key;
    }
  }

  return winner;
}

List<PronunciationViseme> visemesForSegments(List<String> segments) {
  return segments.map(classifyVisemeForSegment).toList();
}
