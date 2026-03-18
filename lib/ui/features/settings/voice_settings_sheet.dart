import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';

/// Bottom sheet that lists available German TTS voices and lets the user
/// pick one. Use [VoiceSettingsSheet.show] to display it.
class VoiceSettingsSheet extends ConsumerStatefulWidget {
  const VoiceSettingsSheet({super.key});

  /// Shows the voice-picker bottom sheet, passing [VoiceProvider] explicitly
  /// so the sheet works even when built in a separate navigator subtree.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const VoiceSettingsSheet(),
    );
  }

  @override
  ConsumerState<VoiceSettingsSheet> createState() => _VoiceSettingsSheetState();
}

class _VoiceSettingsSheetState extends ConsumerState<VoiceSettingsSheet> {
  FlutterTts? _preview;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    // Trigger loading on first open; no-op if already loaded.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(voiceProviderNotifier).loadVoices();
    });
  }

  @override
  void dispose() {
    _preview?.stop();
    super.dispose();
  }

  Future<void> _previewVoice(String name, String locale) async {
    if (_previewing) return;
    setState(() => _previewing = true);
    try {
      _preview ??= FlutterTts();
      await _preview!.setLanguage(locale);
      await _preview!.setVoice({'name': name, 'locale': locale});
      await _preview!.setPitch(1.0);
      await _preview!.setSpeechRate(0.45);
      await _preview!.speak('Guten Morgen! Willkommen in unserer Bäckerei.');
    } catch (_) {}
    if (mounted) setState(() => _previewing = false);
  }

  @override
  Widget build(BuildContext context) {
    final vp = ref.watch(voiceProviderNotifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.record_voice_over_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'German Voice',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Choose which German voice to use for text-to-speech. '
              'Tap ▶ to preview.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (!vp.loaded)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (vp.germanVoices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.voice_over_off,
                          size: 40, color: scheme.outlineVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No German voices found on this device.\n'
                        'Install a German TTS voice in your system settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: vp.germanVoices.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final voice = vp.germanVoices[i];
                    final name = voice['name']!;
                    final locale = voice['locale']!;
                    final selected = vp.selectedName == name;
                    return ListTile(
                      leading: Radio<String>(
                        value: name,
                        groupValue: vp.selectedName,
                        onChanged: (_) => vp.setVoice(name, locale),
                      ),
                      title:
                          Text(name, style: const TextStyle(fontSize: 14)),
                      subtitle:
                          Text(locale, style: const TextStyle(fontSize: 12)),
                      trailing: _previewing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: const Icon(Icons.play_circle_outline),
                              tooltip: 'Preview voice',
                              onPressed: () => _previewVoice(name, locale),
                            ),
                      onTap: () => vp.setVoice(name, locale),
                      selected: selected,
                      selectedTileColor:
                          scheme.primaryContainer.withOpacity(0.3),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
