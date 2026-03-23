import 'speaking_engine_models.dart';

/// Prebuilt speaking exercises for the app.
///
/// Add more templates here and feed them to SpeakingEngine as needed.

const _introduceYourselfScript = [
  'Hallo, ich heiße [Your Name]',
  'Ich komme aus Indien und wohne jetzt in Berlin.',
  'Ich lerne Deutsch, weil ich hier arbeiten möchte.',
];

const _introduceYourselfWordTranslations = {
  'hallo': 'hello',
  'ich': 'I',
  'heiße': 'am called',
  'your name': 'your name',
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
  'möchte': 'would like to',
};

const _introduceYourselfIgnoredWords = {'your name', '...'};

const _orderingCoffeeScript = [
  'Hallo, ich möchte einen Kaffee bestellen.',
  'Ich nehme einen Cappuccino, bitte.',
  'Sonst noch etwas?',
  'Nein, danke. Das ist alles.',
  'Wie viel macht das?',
  'Das macht 3,50 Euro.',
  'Hier ist das Geld.',
  'Danke schön. Auf Wiedersehen!',
];

const _orderingCoffeeWordTranslations = {
  'hallo': 'hello',
  'ich': 'I',
  'möchte': 'would like to',
  'einen': 'a',
  'kaffee': 'coffee',
  'bestellen': 'order',
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
  'nehme': 'take',
  'cappuccino': 'cappuccino',
  'bitte': 'please',
  'sonst': 'else',
  'noch': 'still',
  'etwas': 'something',
  'nein': 'no',
  'danke': 'thank you',
  'das': 'that',
  'ist': 'is',
  'alles': 'everything',
  'wie': 'how',
  'viel': 'much',
  'macht': 'makes',
  'euro': 'euro',
  'geld': 'money',
  'schön': 'beautiful',
  'auf': 'on',
  'wiedersehen': 'goodbye',
};

const _orderingCoffeeIgnoredWords = {'your name', '...'};

const _introduceYourselfPhonetic = [
  'ˈhaloː ɪç ˈhaɪsə',
  'ɪç ˈkɔmə aʊs ˈɪndi̯ən ʊnt ˈvoːnə jɛtst ɪn bɛrˈliːn',
  'ɪç ˈlɛrnə dɔʏtʃ vaɪl ɪç hiːr ˈarbaitən ˈmœçtə',
];

const _orderingCoffeePhonetic = [
  'ˈhaloː ɪç ˈmœçtə ˈaɪnən ˈkafeː bəˈʃtɛlən',
  'ɪç ˈneːmə ˈaɪnən kapʊˈtʃiːnoː ˈbɪtə',
  'zɔnst nɔx ˈɛtvas',
  'naɪn ˈdaŋkə das ɪst ˈaləs',
  'viː fiːl maxt das',
  'das maxt draɪ ˈfʏnftsɪç ˈɔʏroː',
  'hiːr ɪst das ɡɛlt',
  'ˈdaŋkə ʃøːn aʊf ˈviːdɐˌzeːən',
];

final defaultSpeakingExercises = <SpeakingExercise>[
  const SpeakingExercise(
    id: 'introduce-yourself',
    title: 'Introduce Yourself',
    description: 'Practice introducing yourself in German',
    script: _introduceYourselfScript,
    translations: _introduceYourselfWordTranslations,
    ignoreWords: _introduceYourselfIgnoredWords,
    scenario:
        'You have just started a new job and are talking with a colleague.',
    prompt: 'Say your name, where you are from and what you do.',
    usefulPhrases: ['Ich heiße …', 'Ich komme aus …', 'Ich bin … von Beruf.'],
    spokenName: 'Arjak',
    phoneticScript: _introduceYourselfPhonetic,
  ),
  const SpeakingExercise(
    id: 'ordering-coffee',
    title: 'Ordering Coffee',
    description: 'Practice ordering coffee in German',
    script: _orderingCoffeeScript,
    translations: _orderingCoffeeWordTranslations,
    ignoreWords: _orderingCoffeeIgnoredWords,
    scenario: 'You are in a cafe and want to order a coffee.',
    prompt: 'Say your name, where you are from and what you do.',
    usefulPhrases: ['Ich heiße …', 'Ich komme aus …', 'Ich bin … von Beruf.'],
    spokenName: 'Arjak',
    phoneticScript: _orderingCoffeePhonetic,
  ),
];
