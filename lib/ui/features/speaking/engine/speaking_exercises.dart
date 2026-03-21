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
  ),
];
