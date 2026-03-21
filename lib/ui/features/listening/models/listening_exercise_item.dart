class ListeningExerciseItem {
  final String title;
  final String description;
  final String audioUrl;

  ListeningExerciseItem({
    required this.title,
    required this.description,
    required this.audioUrl,
  });
}

final List<ListeningExerciseItem> listeningExercises = [
  ListeningExerciseItem(
    title: 'Der Apfel',
    description: 'Ein einfaches Hörverständnis über Äpfel.',
    audioUrl: '', // Placeholder
  ),
  ListeningExerciseItem(
    title: 'Im Supermarkt',
    description: 'Dialog im Supermarkt.',
    audioUrl: '',
  ),
  ListeningExerciseItem(
    title: 'Die Schule',
    description: 'Gespräch über die Schule.',
    audioUrl: '',
  ),
];
