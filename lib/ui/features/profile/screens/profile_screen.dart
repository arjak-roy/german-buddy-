import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../providers/app_providers.dart';
import '../../../../providers/speaking_session_provider.dart';
import '../../../../ui/features/speaking/engine/speaking_exercises.dart';
import '../models/profile_model.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final authSession = ref.watch(authSessionProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final analysis = ref.watch(pronunciationAnalysisProviderNotifier);
    final speakingPractice = ref.watch(
      speakingSessionNotifierProvider(defaultSpeakingExercises.first),
    );

    String formatTimestamp(dynamic value) {
      if (value == null) return 'N/A';
      final dateTime = value is DateTime
          ? value
          : value.toDate is Function
          ? value.toDate() as DateTime
          : null;
      if (dateTime == null) return 'N/A';
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime.toLocal());
    }

    final fallbackUser = authSession.valueOrNull;

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Failed to load profile: $error'),
          ),
        ),
        data: (profileData) {
          final profileModel = ProfileModel.fromMap(
            profileData,
            fallbackUid: fallbackUser?.id,
          );
          final name = profileModel.displayName;
          final email = profileModel.email;
          final uid = profileModel.uid;
          final level = profileModel.languageLevel;

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 18.0,
            ),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.08),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        (name?.isNotEmpty == true
                                ? name!.substring(0, 1)
                                : (email?.isNotEmpty == true
                                      ? email!.substring(0, 1)
                                      : 'U'))
                            .toUpperCase(),
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name?.isNotEmpty == true ? name! : 'Anonymous User',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email?.isNotEmpty == true
                                ? email!
                                : (fallbackUser?.email ?? 'No email available'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Level $level',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.settings, color: colorScheme.primary),
                      tooltip: 'Profile settings',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileSettingsScreen(
                              uid: uid,
                              createdAt: formatTimestamp(
                                profileData?['createdAt'],
                              ),
                              lastLogin: formatTimestamp(
                                profileData?['lastLoginAt'],
                              ),
                              languageLevel: level,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usage insights',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Chat conversations',
                              value:
                                  profileData?['conversations']?.toString() ??
                                  '0',
                              icon: Icons.chat_bubble_outline,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ProfileMetricCard(
                              label: 'Pronunciation sessions',
                              value:
                                  profileData?['pronunciationSessions']
                                      ?.toString() ??
                                  '0',
                              icon: Icons.record_voice_over_rounded,
                              color: colorScheme.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pronunciation progress',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      if (analysis.allReports.isEmpty &&
                          speakingPractice.speakingSentenceCount == 0)
                        Text(
                          'Complete a pronunciation or speaking session to unlock detailed scores.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        )
                      else ...[
                        if (analysis.allReports.isNotEmpty) ...[
                          Text(
                            'Average score: ${analysis.averageScore.toStringAsFixed(1)}/100',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Best: ${analysis.topPerformer}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Focus: ${analysis.improvementTarget}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (speakingPractice.speakingSentenceCount > 0) ...[
                          Text(
                            'Speaking sessions: ${speakingPractice.speakingSentenceCount}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            'Speaking avg confidence: ${(speakingPractice.speakingAverageConfidence * 100).toStringAsFixed(1)}%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (analysis.allReports.isEmpty &&
                            speakingPractice.speakingSentenceCount > 0)
                          Text(
                            'No pronunciation report yet, but speaking practice data is available.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        const SizedBox(height: 12),
                        Column(
                          children: analysis.allReports.entries.toList().map((
                            entry,
                          ) {
                            final part = entry.key.split('|');
                            final german = part.isNotEmpty
                                ? part[0]
                                : entry.key;
                            final report = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Builder(
                                  builder: (context) {
                                    final normalizedWord = german
                                        .trim()
                                        .toLowerCase();
                                    final speakingScore = speakingPractice
                                        .speakingWordConfidence[normalizedWord];
                                    final speakingTag = speakingScore != null
                                        ? ' • speaking ${(speakingScore * 100).toStringAsFixed(0)}%'
                                        : '';
                                    return Text(
                                      '$german · ${report.overallScore}/100$speakingTag',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    );
                                  },
                                ),
                                subtitle: Text(
                                  report.heardText.isNotEmpty
                                      ? 'Heard: ${report.heardText}'
                                      : 'No transcript available',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                children: [
                                  if (report.strengths.isNotEmpty)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Strengths'),
                                      subtitle: Text(
                                        report.strengths.join(', '),
                                      ),
                                    ),
                                  if (report.priorities.isNotEmpty)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Needs work'),
                                      subtitle: Text(
                                        report.priorities.join(', '),
                                      ),
                                    ),
                                  if (report.phonemeBreakdown.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: report.phonemeBreakdown
                                            .map(
                                              (phoneme) => Chip(
                                                label: Text(
                                                  '${phoneme.phoneme}: ${phoneme.status}',
                                                ),
                                                backgroundColor:
                                                    phoneme.status == 'correct'
                                                    ? Colors.green.withOpacity(
                                                        0.14,
                                                      )
                                                    : (phoneme.status ==
                                                              'incorrect'
                                                          ? Colors.red
                                                                .withOpacity(
                                                                  0.14,
                                                                )
                                                          : Colors.orange
                                                                .withOpacity(
                                                                  0.14,
                                                                )),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: authAction.isLoading
                      ? null
                      : () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('Sign out', style: TextStyle(fontSize: 16)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileAttributeRow extends StatelessWidget {
  final String label;
  final String value;

  const _ProfileAttributeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 94,
            child: Text(
              '$label',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ProfileMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceVariant,
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  final String uid;
  final String createdAt;
  final String lastLogin;
  final String languageLevel;

  const ProfileSettingsScreen({
    super.key,
    required this.uid,
    required this.createdAt,
    required this.lastLogin,
    required this.languageLevel,
  });

  @override
  ConsumerState<ProfileSettingsScreen> createState() =>
      _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late String _languageLevel;

  @override
  void initState() {
    super.initState();
    _languageLevel = widget.languageLevel;
  }

  Future<void> _chooseLanguageLevel() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) {
        final levels = ['A1', 'A2', 'B1', 'B2'];
        String localSelected = _languageLevel;

        return AlertDialog(
          title: const Text('Change German level'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: levels
                    .map(
                      (level) => RadioListTile<String>(
                        value: level,
                        groupValue: localSelected,
                        title: Text(level),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            localSelected = value;
                          });
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(localSelected),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != _languageLevel) {
      setState(() => _languageLevel = selected);
      await ref
          .read(userProfileRepositoryProvider)
          .setLanguageLevel(widget.uid, selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: colorScheme.primary.withOpacity(0.14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account metadata',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _ProfileAttributeRow(label: 'UID', value: widget.uid),
                _ProfileAttributeRow(label: 'Created', value: widget.createdAt),
                _ProfileAttributeRow(
                  label: 'Last login',
                  value: widget.lastLogin,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'German level',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _languageLevel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _chooseLanguageLevel,
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Divider(color: colorScheme.onSurface.withOpacity(0.24)),
                const SizedBox(height: 12),
                Divider(color: colorScheme.onSurface.withOpacity(0.24)),
                const SizedBox(height: 12),
                Text(
                  'These values are read-only and show your account state for support or sync troubleshooting.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
