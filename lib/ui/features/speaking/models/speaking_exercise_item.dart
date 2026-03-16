class SpeakingExerciseItem {
  final String title;
  final String description;
  final String scenario;
  final String prompt;
  final List<String> usefulPhrases;

  const SpeakingExerciseItem({
    required this.title,
    required this.description,
    required this.scenario,
    required this.prompt,
    required this.usefulPhrases,
  });
}

const List<SpeakingExerciseItem> speakingExercises = [
  SpeakingExerciseItem(
    title: 'Introduce Yourself',
    description: 'Practice introducing yourself in German to a new colleague.',
    scenario:
        'You have just started a new job. A colleague walks over and says "Hallo! Ich bin Lena." Introduce yourself.',
    prompt: 'Introduce yourself: say your name, where you are from, and what you do.',
    usefulPhrases: [
      'Ich heiße … (My name is …)',
      'Ich komme aus … (I come from …)',
      'Ich bin … von Beruf. (I work as a …)',
      'Freut mich, Sie kennenzulernen! (Nice to meet you!)',
    ],
  ),
  SpeakingExerciseItem(
    title: 'Asking a Stranger for Directions',
    description: 'Ask a passer-by how to get to the nearest train station.',
    scenario:
        'You are standing on a busy street in Berlin and need to reach the nearest U-Bahn station. A friendly stranger is passing by.',
    prompt: 'Ask politely for directions to the nearest subway station.',
    usefulPhrases: [
      'Entschuldigung, können Sie mir helfen? (Excuse me, can you help me?)',
      'Wo ist der nächste Bahnhof? (Where is the nearest station?)',
      'Wie weit ist es? (How far is it?)',
      'Geradeaus gehen, dann links abbiegen. (Go straight, then turn left.)',
    ],
  ),
  SpeakingExerciseItem(
    title: 'Ordering at a Café',
    description: 'Order a coffee and a piece of cake in a German café.',
    scenario:
        'You are sitting in a small café in Munich. The waiter comes to your table and says "Was darf es sein?"',
    prompt: 'Order a cappuccino and a slice of Schwarzwälder Kirschtorte.',
    usefulPhrases: [
      'Ich hätte gerne … (I would like …)',
      'Einen Cappuccino, bitte. (A cappuccino, please.)',
      'Haben Sie auch Kuchen? (Do you also have cake?)',
      'Die Rechnung, bitte. (The bill, please.)',
    ],
  ),
  SpeakingExerciseItem(
    title: 'Talking About Your Hobbies',
    description: 'Tell a new acquaintance about what you enjoy doing.',
    scenario:
        'You are at a German language meetup. Someone asks you "Was machst du in deiner Freizeit?"',
    prompt: 'Describe at least two hobbies and explain why you enjoy them.',
    usefulPhrases: [
      'In meiner Freizeit … (In my free time …)',
      'Ich interessiere mich für … (I am interested in …)',
      'Es macht mir viel Spaß. (I really enjoy it.)',
      'Und du? Was sind deine Hobbys? (And you? What are your hobbies?)',
    ],
  ),
  SpeakingExerciseItem(
    title: 'Shopping for Clothes',
    description: 'Ask for help finding the right size in a clothing store.',
    scenario:
        'You are in a Zara in Hamburg. You find a jacket you like but cannot see your size on the rack.',
    prompt: 'Ask the sales assistant if the jacket is available in your size, and ask where you can try it on.',
    usefulPhrases: [
      'Haben Sie das auch in Größe M? (Do you have this in size M?)',
      'Wo ist die Umkleidekabine? (Where is the fitting room?)',
      'Das passt gut. (That fits well.)',
      'Ich nehme es! (I\'ll take it!)',
    ],
  ),
  SpeakingExerciseItem(
    title: 'Making a Doctor\'s Appointment',
    description: 'Call a doctor\'s office to book an appointment.',
    scenario:
        'You have had a headache for a few days and want to see a doctor. You call the Praxis to make an appointment.',
    prompt: 'Call the receptionist, explain your symptoms briefly, and arrange a time.',
    usefulPhrases: [
      'Ich möchte einen Termin vereinbaren. (I\'d like to make an appointment.)',
      'Ich habe seit einigen Tagen Kopfschmerzen. (I have had headaches for a few days.)',
      'Wann hätten Sie einen freien Termin? (When do you have a free slot?)',
      'Mittwochvormittag passt mir gut. (Wednesday morning suits me well.)',
    ],
  ),
];
