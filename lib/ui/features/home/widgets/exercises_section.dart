import 'package:flutter/material.dart';
import '../../listening/screens/listening_catalogue_screen.dart';

class ExercisesSection extends StatelessWidget {
  const ExercisesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Exercises',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        const _ExerciseCard(
          title: 'Speaking Exercises',
          subtitle: 'Practice pronunciation and spoken fluency',
          icon: Icons.mic_none_rounded,
          color: Colors.blue,
        ),
        const _ExerciseCard(
          title: 'Writing Exercises',
          subtitle: 'Build vocabulary and grammar through writing',
          icon: Icons.edit_note_rounded,
          color: Colors.green,
        ),
        const _ExerciseCard(
          title: 'Reading Exercises',
          subtitle: 'Improve comprehension with German texts',
          icon: Icons.menu_book_rounded,
          color: Colors.orange,
        ),
        const _ExerciseCard(
          title: 'Listening Exercises',
          subtitle: 'Train your ear with audio challenges',
          icon: Icons.headphones_rounded,
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ExerciseCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () {
          if (title == 'Listening Exercises') {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ListeningCatalogueScreen(),
              ),
            );
          }
        },
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        minLeadingWidth: 40,
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }
}
