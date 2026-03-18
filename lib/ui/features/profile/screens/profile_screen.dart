import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../providers/app_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAction = ref.watch(authControllerProvider);
    final authSession = ref.watch(authSessionProvider);
    final profile = ref.watch(currentUserProfileProvider);

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

    return Scaffold(
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Failed to load profile: $error'),
          ),
        ),
        data: (profileData) {
          final name = (profileData?['displayName'] as String?)?.trim();
          final email = (profileData?['email'] as String?)?.trim();
          final uid =
              (profileData?['uid'] as String?) ?? fallbackUser?.id ?? 'Unknown';
          final providers = (profileData?['providerIds'] as List?)
                  ?.map((value) => value.toString())
                  .toList() ??
              <String>[];

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              CircleAvatar(
                radius: 34,
                child: Text(
                  (name?.isNotEmpty == true
                          ? name!.substring(0, 1)
                          : (email?.isNotEmpty == true
                              ? email!.substring(0, 1)
                              : 'U'))
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  name?.isNotEmpty == true ? name! : 'No name set',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  email?.isNotEmpty == true
                      ? email!
                      : (fallbackUser?.email ?? 'No email available'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UID: $uid'),
                      const SizedBox(height: 8),
                      Text(
                        'Providers: ${providers.isEmpty ? 'N/A' : providers.join(', ')}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Created: ${formatTimestamp(profileData?['createdAt'])}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last login: ${formatTimestamp(profileData?['lastLoginAt'])}',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Updated: ${formatTimestamp(profileData?['updatedAt'])}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: authAction.isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ],
          );
        },
      ),
    );
  }
}
