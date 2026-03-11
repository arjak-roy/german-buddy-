import 'package:flutter/material.dart';

class PronunciationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;

  const PronunciationCard({
    required this.title,
    required this.subtitle,
    required this.progress,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.record_voice_over, color: Colors.blue),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text('${(progress * 100).toInt()}%'),
      ),
    );
  }
}
