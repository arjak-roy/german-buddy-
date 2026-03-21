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
  return word.toLowerCase().replaceAll(RegExp(r"[^a-z0-9äöüß]"), '').trim();
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
  PronunciationItem(german: 'in', phonetic: 'IN', english: 'in', difficulty: 1),
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
  PronunciationItem(
    german: 'Tschüss',
    phonetic: 'CHYUSS',
    english: 'Bye',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Bitte',
    phonetic: 'BIT-tuh',
    english: 'Please / You’re welcome',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Danke',
    phonetic: 'DAHN-kuh',
    english: 'Thank you',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Entschuldigung',
    phonetic: 'ent-SHOOL-dee-goong',
    english: 'Excuse me / Sorry',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Ja',
    phonetic: 'YAH',
    english: 'Yes',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Nein',
    phonetic: 'NINE',
    english: 'No',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Vielleicht',
    phonetic: 'fee-LYKHT',
    english: 'Maybe',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Guten Morgen',
    phonetic: 'GOO-ten MOR-gen',
    english: 'Good morning',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Gute Nacht',
    phonetic: 'GOO-tuh NAKHT',
    english: 'Good night',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Wie geht es dir?',
    phonetic: 'VEE GAYT es DEER',
    english: 'How are you?',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Essen',
    phonetic: 'ES-sen',
    english: 'To eat / Food',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Trinken',
    phonetic: 'TRIN-ken',
    english: 'To drink',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Kaffee',
    phonetic: 'KAH-fay',
    english: 'Coffee',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Milch',
    phonetic: 'MILKH',
    english: 'Milk',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Zucker',
    phonetic: 'TSOOK-er',
    english: 'Sugar',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Frühstück',
    phonetic: 'FRYOO-shtyuk',
    english: 'Breakfast',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Mittagessen',
    phonetic: 'MIT-tahg-es-sen',
    english: 'Lunch',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Abendessen',
    phonetic: 'AH-bent-es-sen',
    english: 'Dinner',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Apfel',
    phonetic: 'AHP-fel',
    english: 'Apple',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Kartoffel',
    phonetic: 'kar-TOF-fel',
    english: 'Potato',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Fleisch',
    phonetic: 'FLAISH',
    english: 'Meat',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Gemüse',
    phonetic: 'ge-MYOO-zuh',
    english: 'Vegetables',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Obst',
    phonetic: 'OHPST',
    english: 'Fruit',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Käse',
    phonetic: 'KAY-zuh',
    english: 'Cheese',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Hähnchen',
    phonetic: 'HAYN-khen',
    english: 'Chicken',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Reis',
    phonetic: 'RAICE',
    english: 'Rice',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Salat',
    phonetic: 'zah-LAHT',
    english: 'Salad',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Eier',
    phonetic: 'AI-er',
    english: 'Eggs',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Bier',
    phonetic: 'BEER',
    english: 'Beer',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Wein',
    phonetic: 'VINE',
    english: 'Wine',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Haus',
    phonetic: 'HOWS',
    english: 'House',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Zimmer',
    phonetic: 'TSIM-mer',
    english: 'Room',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Küche',
    phonetic: 'KYOO-khuh',
    english: 'Kitchen',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Bad',
    phonetic: 'BAHT',
    english: 'Bathroom',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Bett',
    phonetic: 'BET',
    english: 'Bed',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Tisch',
    phonetic: 'TISH',
    english: 'Table',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Stuhl',
    phonetic: 'SHTOOL',
    english: 'Chair',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Fenster',
    phonetic: 'FEN-ster',
    english: 'Window',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Tür',
    phonetic: 'TYOOR',
    english: 'Door',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Stadt',
    phonetic: 'SHTAHT',
    english: 'City',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Straße',
    phonetic: 'SHTRAH-suh',
    english: 'Street',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Auto',
    phonetic: 'OW-toh',
    english: 'Car',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Fahrrad',
    phonetic: 'FAHR-raht',
    english: 'Bicycle',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Zug',
    phonetic: 'TSOOK',
    english: 'Train',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Bahnhof',
    phonetic: 'BAHN-hohf',
    english: 'Train Station',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Flughafen',
    phonetic: 'FLOOG-hah-fen',
    english: 'Airport',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Karte',
    phonetic: 'KAR-tuh',
    english: 'Ticket / Card',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Geld',
    phonetic: 'GELT',
    english: 'Money',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Rechnung',
    phonetic: 'REKH-noong',
    english: 'Bill',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Zeit',
    phonetic: 'TSAITE',
    english: 'Time',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Heute',
    phonetic: 'HOY-tuh',
    english: 'Today',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Morgen',
    phonetic: 'MOR-gen',
    english: 'Tomorrow',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Gestern',
    phonetic: 'GES-tern',
    english: 'Yesterday',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Woche',
    phonetic: 'VOKH-uh',
    english: 'Week',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Monat',
    phonetic: 'MOH-naht',
    english: 'Month',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Jahr',
    phonetic: 'YAHR',
    english: 'Year',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Uhr',
    phonetic: 'OOR',
    english: 'Clock / O’clock',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Montag',
    phonetic: 'MOHN-tahg',
    english: 'Monday',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Dienstag',
    phonetic: 'DEENS-tahg',
    english: 'Tuesday',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Mittwoch',
    phonetic: 'MIT-vokh',
    english: 'Wednesday',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Donnerstag',
    phonetic: 'DON-ners-tahg',
    english: 'Thursday',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Freitag',
    phonetic: 'FRY-tahg',
    english: 'Friday',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Samstag',
    phonetic: 'ZAHMS-tahg',
    english: 'Saturday',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Sonntag',
    phonetic: 'ZOHN-tahg',
    english: 'Sunday',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Arbeit',
    phonetic: 'AR-baite',
    english: 'Work',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Beruf',
    phonetic: 'be-ROOF',
    english: 'Profession',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Schule',
    phonetic: 'SHOO-luh',
    english: 'School',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Universität',
    phonetic: 'oo-nee-ver-zee-TAYT',
    english: 'University',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Student',
    phonetic: 'shtoo-DENT',
    english: 'Student',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Lehrer',
    phonetic: 'LAY-rer',
    english: 'Teacher',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Buch',
    phonetic: 'BOOKH',
    english: 'Book',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Schreiben',
    phonetic: 'SHRY-ben',
    english: 'To write',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Lesen',
    phonetic: 'LAY-zen',
    english: 'To read',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Sprechen',
    phonetic: 'SHPREKH-en',
    english: 'To speak',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Verstehen',
    phonetic: 'fer-SHTAY-en',
    english: 'To understand',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Helfen',
    phonetic: 'HEL-fen',
    english: 'To help',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Kaufen',
    phonetic: 'KOW-fen',
    english: 'To buy',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Geben',
    phonetic: 'GAY-ben',
    english: 'To give',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Sehen',
    phonetic: 'ZAY-en',
    english: 'To see',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Gehen',
    phonetic: 'GAY-en',
    english: 'To go',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Machen',
    phonetic: 'MAKH-en',
    english: 'To do / make',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Wissen',
    phonetic: 'VIS-sen',
    english: 'To know',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Denken',
    phonetic: 'DEN-ken',
    english: 'To think',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Sagen',
    phonetic: 'ZAH-gen',
    english: 'To say',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Freund',
    phonetic: 'FROYNT',
    english: 'Friend',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Familie',
    phonetic: 'fah-MEEL-yuh',
    english: 'Family',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Vater',
    phonetic: 'FAH-ter',
    english: 'Father',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Mutter',
    phonetic: 'MOOT-ter',
    english: 'Mother',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Kind',
    phonetic: 'KINT',
    english: 'Child',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Bruder',
    phonetic: 'BROO-der',
    english: 'Brother',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Schwester',
    phonetic: 'SHVES-ter',
    english: 'Sister',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Glücklich',
    phonetic: 'GLYUK-likh',
    english: 'Happy',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Traurig',
    phonetic: 'TROW-rikh',
    english: 'Sad',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Müde',
    phonetic: 'MYOO-duh',
    english: 'Tired',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Krank',
    phonetic: 'KRAHNK',
    english: 'Sick',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Wichtig',
    phonetic: 'VIKH-tikh',
    english: 'Important',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Schön',
    phonetic: 'SHERN',
    english: 'Beautiful / Nice',
    difficulty: 3,
  ),
  PronunciationItem(
    german: 'Groß',
    phonetic: 'GROHSS',
    english: 'Big / Tall',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Klein',
    phonetic: 'KLINE',
    english: 'Small',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Neu',
    phonetic: 'NOY',
    english: 'New',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Alt',
    phonetic: 'AHLT',
    english: 'Old',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Gut',
    phonetic: 'GOOT',
    english: 'Good',
    difficulty: 1,
  ),
  PronunciationItem(
    german: 'Schlecht',
    phonetic: 'SHLEKHT',
    english: 'Bad',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Einfach',
    phonetic: 'INE-fahkh',
    english: 'Easy / Simple',
    difficulty: 2,
  ),
  PronunciationItem(
    german: 'Schwierig',
    phonetic: 'SHVEE-rikh',
    english: 'Difficult',
    difficulty: 3,
  ),
];
