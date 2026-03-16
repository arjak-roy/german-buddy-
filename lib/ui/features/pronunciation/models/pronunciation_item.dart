class PronunciationItem {
  final String german;
  final String phonetic;
  final String english;
  final int difficulty;

  const PronunciationItem({
    required this.german,
    required this.phonetic,
    required this.english,
    required this.difficulty,
  });

  List<String> get segments => phonetic.split('-');

  String get stars => List<String>.filled(difficulty, '⭐').join();
}

String _normalizePronunciationWord(String word) {
  return word
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9äöüß]"), '')
      .trim();
}

PronunciationItem? findPronunciationItemByWord(String word) {
  final normalized = _normalizePronunciationWord(word);
  if (normalized.isEmpty) return null;

  for (final item in pronunciationItems) {
    if (_normalizePronunciationWord(item.german) == normalized) {
      return item;
    }
  }
  return null;
}

const pronunciationItems = <PronunciationItem>[
  PronunciationItem(
    german: 'Hallo',
    phonetic: 'HAH-loh',
    english: 'Hello',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Name',
    phonetic: 'NAH-muh',
    english: 'Name',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Brot',
    phonetic: 'BROHT',
    english: 'Bread',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Wasser',
    phonetic: 'VAHS-er',
    english: 'Water',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Katze',
    phonetic: 'KAHT-tsuh',
    english: 'Cat',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'ich',
    phonetic: 'ikh',
    english: 'I',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'heiße',
    phonetic: 'HAI-suh',
    english: 'am called',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Alex',
    phonetic: 'AH-leks',
    english: 'Alex',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'komme',
    phonetic: 'KOH-muh',
    english: 'come',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'aus',
    phonetic: 'OWS',
    english: 'from',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Indien',
    phonetic: 'IN-dee-en',
    english: 'India',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'und',
    phonetic: 'UNT',
    english: 'and',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'wohne',
    phonetic: 'VOH-nuh',
    english: 'live',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'jetzt',
    phonetic: 'YETST',
    english: 'now',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'in',
    phonetic: 'IN',
    english: 'in',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Berlin',
    phonetic: 'ber-LEEN',
    english: 'Berlin',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'lerne',
    phonetic: 'LER-nuh',
    english: 'learn',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Deutsch',
    phonetic: 'DOYCH',
    english: 'German',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'weil',
    phonetic: 'VAIL',
    english: 'because',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'hier',
    phonetic: 'HEER',
    english: 'here',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'arbeiten',
    phonetic: 'AR-bai-ten',
    english: 'to work',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'möchte',
    phonetic: 'MERKH-tuh',
    english: 'would like',
    difficulty: 3,
  ),
];