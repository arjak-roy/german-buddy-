import 'package:flutter/material.dart';

import 'resource_card.dart';

class ResourcesSection extends StatelessWidget {
  const ResourcesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': Icons.book, 'title': 'Grammar Guide'},
      {'icon': Icons.language, 'title': 'Vocabulary'},
      {'icon': Icons.play_circle_fill, 'title': 'Video Lessons'},
      {'icon': Icons.picture_as_pdf, 'title': 'Flashcards'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Learning Resources',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: items
                .map(
                  (i) => ResourceCard(
                    icon: i['icon'] as IconData,
                    title: i['title'] as String,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
