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
];