import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/app_providers.dart';
import '../../../../providers/speech_provider.dart';
import '../../../shared/widgets/theme_mode_button.dart';

class BuddyAppBar extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const BuddyAppBar({super.key});

  @override
  ConsumerState<BuddyAppBar> createState() => _BuddyAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

class _BuddyAppBarState extends ConsumerState<BuddyAppBar> {
  SpeechLanguage? _previousLanguage;
  bool _showLanguageSwitch = false;

  @override
  Widget build(BuildContext context) {
    final speech = ref.watch(speechProviderNotifier);
    final showDebug = speech.showDebugPanel;
    final scheme = Theme.of(context).colorScheme;
    final isGerman = speech.isGerman;

    // Detect language change and trigger visual feedback
    if (_previousLanguage != null && _previousLanguage != speech.language) {
      _showLanguageSwitch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              setState(() => _showLanguageSwitch = false);
            }
          });
        }
      });
    }
    _previousLanguage = speech.language;

    return AppBar(
      toolbarHeight: 72,
      backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.9),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('Buddy'),
          const SizedBox(height: 2),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(
              begin: 1.0,
              end: _showLanguageSwitch ? 1.12 : 1.0,
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: _showLanguageSwitch
                        ? [
                            BoxShadow(
                              color: (isGerman ? scheme.primary : Colors.blue)
                                  .withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1.5,
                            ),
                          ]
                        : [],
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isGerman
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: GestureDetector(
                      onTap: () => speech.toggleLanguage(),
                      child: Text(
                        isGerman ? 'DE' : 'EN',
                        style: TextStyle(
                          fontSize: 11,
                          color: isGerman
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
}
