import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../shared/widgets/theme_mode_button.dart';

class BuddyAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const BuddyAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDebug = ref.watch(speechProviderNotifier).showDebugPanel;
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Buddy'),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.tertiary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'LIVE',
              style: TextStyle(
                fontSize: 10,
                color: scheme.tertiary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        const ThemeModeButton(),
        IconButton(
          icon: Icon(showDebug ? Icons.bug_report : Icons.info_outline),
          tooltip: showDebug ? 'Hide STT debug panel' : 'Show STT debug panel',
          onPressed: () => ref.read(speechProviderNotifier).toggleDebugPanel(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}
