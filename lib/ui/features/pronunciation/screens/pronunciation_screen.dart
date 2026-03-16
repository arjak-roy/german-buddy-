import 'package:flutter/material.dart';
import '../models/pronunciation_item.dart';
import 'pronunciation_lesson_screen.dart';
// import removed: '../../listening/screens/listening_catalogue_screen.dart';

class PronunciationScreen extends StatelessWidget {
  static const _panelTitle = Color(0xFF0F172A);
  static const _panelBody = Color(0xFF334155);

  final bool embedded;

  const PronunciationScreen({super.key, this.embedded = false});

  void _openLesson(BuildContext context, PronunciationItem item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PronunciationLessonScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pronunciation Lab',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _panelTitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose one word and practice it step by step with native German playback, phonetic guidance, recording, and analysis.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.35,
                          color: _panelBody,
                        ),
                      ),
                    ],
                  ),
                ),
                // ...existing code...
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = pronunciationItems[index];
              return _PronunciationGridCard(
                item: item,
                index: index,
                onTap: () => _openLesson(context, item),
              );
            }, childCount: pronunciationItems.length),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 250,
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pronunciation Lab')),
      body: content,
    );
  }
}

class _PronunciationGridCard extends StatelessWidget {
  static const _panelTitle = Color(0xFF0F172A);
  static const _panelBody = Color(0xFF334155);
  static const _panelMuted = Color(0xFF475569);

  final PronunciationItem item;
  final int index;
  final VoidCallback onTap;

  const _PronunciationGridCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorPairs = <List<Color>>[
      [const Color(0xFFFFF7ED), const Color(0xFFFED7AA)],
      [const Color(0xFFECFEFF), const Color(0xFFA5F3FC)],
      [const Color(0xFFF5F3FF), const Color(0xFFC4B5FD)],
      [const Color(0xFFF0FDF4), const Color(0xFFBBF7D0)],
      [const Color(0xFFFEF2F2), const Color(0xFFFECACA)],
    ];
    final colors = colorPairs[index % colorPairs.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Text('${index + 1}'),
                    ),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          item.stars,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.german,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _panelTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.phonetic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _panelBody,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('🇬🇧', style: TextStyle(fontSize: 11)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        item.english,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _panelMuted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: _panelTitle,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Open lesson',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _panelTitle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
