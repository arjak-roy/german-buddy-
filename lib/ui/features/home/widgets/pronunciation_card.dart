import 'package:flutter/material.dart';

class PronunciationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String difficulty;
  final VoidCallback? onTap;

  const PronunciationCard({
    required this.title,
    required this.subtitle,
    required this.difficulty,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.record_voice_over, color: Colors.blue),
        ),
        minLeadingWidth: 40,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(difficulty, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
