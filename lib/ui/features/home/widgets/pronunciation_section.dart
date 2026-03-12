import 'package:flutter/material.dart';

import 'pronunciation_card.dart';
import '../../pronunciation/models/pronunciation_item.dart';
import '../../pronunciation/screens/pronunciation_lesson_screen.dart';
import '../../pronunciation/screens/pronunciation_screen.dart';

class PronunciationSection extends StatelessWidget {
  const PronunciationSection({super.key});

  void _openLab(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PronunciationScreen()),
    );
  }

  void _openLesson(BuildContext context, PronunciationItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PronunciationLessonScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = pronunciationItems.take(3).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Pronunciation Exercises',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: () => _openLab(context),
                icon: const Icon(Icons.keyboard_voice_outlined),
                label: const Text('Open Lab'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...items.map(
          (item) => PronunciationCard(
            title: item.german,
            subtitle: '${item.phonetic} • ${item.english}',
            difficulty: item.stars,
            onTap: () => _openLesson(context, item),
          ),
        ),
      ],
    );
  }
}
