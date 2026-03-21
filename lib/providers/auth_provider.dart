import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/firebase_auth_repository.dart';
import 'profile_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository();
});

final authSessionProvider = StreamProvider<AppUser?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  Future<void> signIn({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return repository.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> signUp({required String email, required String password}) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return repository.signUpWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    });
  }

  Future<void> signInWithGoogle() async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(repository.signInWithGoogle);
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return repository.sendPasswordResetEmail(email: email.trim());
    });
  }

  Future<void> signOut() async {
    final repository = ref.read(authRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(repository.signOut);
  }

  Future<void> setLanguageLevel(String languageLevel) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;
    final profileRepo = ref.read(userProfileRepositoryProvider);

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() {
      return profileRepo.setLanguageLevel(user.id, languageLevel);
    });
  }
}
