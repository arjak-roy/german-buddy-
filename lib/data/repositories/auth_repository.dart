import '../models/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signInWithGoogle();

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();
}
