import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/user_profile_repository.dart';
import 'auth_provider.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository();
});

final currentUserProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authSession = ref.watch(authSessionProvider);
  final repository = ref.watch(userProfileRepositoryProvider);

  return authSession.when(
    data: (user) {
      if (user == null) return const Stream<Map<String, dynamic>?>.empty();
      return repository.watchProfile(user.id);
    },
    loading: () => const Stream<Map<String, dynamic>?>.empty(),
    error: (_, __) => const Stream<Map<String, dynamic>?>.empty(),
  );
});
