import 'package:flutter/material.dart';

import 'pronunciation_card.dart';

class PronunciationSection extends StatelessWidget {
  const PronunciationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {
        'title': '“Eichhörnchen”',
        'subtitle': 'The squirrel challenge',
        'progress': 0.85,
      },
      {
        'title': '“Fünfhundertfünfundfünfzig”',
        'subtitle': 'Mastering numbers',
        'progress': 0.0,
      }
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Pronunciation Exercises',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        ...items.map((i) => PronunciationCard(
              title: i['title']! as String,
              subtitle: i['subtitle']! as String,
              progress: i['progress']! as double,
            )),
      ],
    );
  }
}
