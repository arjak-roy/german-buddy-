import 'package:flutter/material.dart';
import '../models/pronunciation_item.dart';
import 'pronunciation_lesson_screen.dart';

class PronunciationScreen extends StatelessWidget {
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
            child: Container(
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
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose one word and practice it step by step with native German playback, phonetic guidance, recording, and analysis.',
                    style: TextStyle(height: 1.35, color: Color(0xFF334155)),
                  ),
                ],
              ),
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
              mainAxisExtent: 220,
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
                Text(
                  item.german,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.phonetic,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.english,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF475569)),
                ),
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.play_circle_outline_rounded, size: 18),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Open lesson',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700),
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
