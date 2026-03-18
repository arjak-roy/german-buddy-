import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import 'auth_repository.dart';
import '../../firebase_options.dart';

class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? _buildGoogleSignIn();

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  static GoogleSignIn _buildGoogleSignIn() {
    String? clientId;
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      clientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
    }

    const configuredServerClientId = String.fromEnvironment(
      'GOOGLE_SERVER_CLIENT_ID',
    );
    final serverClientId =
        configuredServerClientId.trim().isEmpty ? null : configuredServerClientId;

    return GoogleSignIn(
      clientId: clientId,
      serverClientId: serverClientId,
    );
  }

  @override
  Stream<AppUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
        if (firebaseUser != null) {
          await _upsertUserDocument(firebaseUser);
        }
        return _mapUser(firebaseUser);
      });

  @override
  AppUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _guardFirebaseCall(() {
      return _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _upsertUserDocument(user);
    }
  }

  @override
  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _guardFirebaseCall(() {
      return _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await _upsertUserDocument(user);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw const AuthFailure('Google sign-in was cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _guardFirebaseCall(() {
        return _firebaseAuth.signInWithCredential(credential);
      });

      final user = _firebaseAuth.currentUser;
      if (user != null) {
        await _upsertUserDocument(user);
      }
    } on AuthFailure {
      rethrow;
    } catch (error) {
      throw AuthFailure(_mapGoogleSignInError(error));
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    await _guardFirebaseCall(() {
      return _firebaseAuth.sendPasswordResetEmail(email: email);
    });
  }

  @override
  Future<void> signOut() async {
    await _guardFirebaseCall(_firebaseAuth.signOut);
    await _googleSignIn.signOut();
  }

  Future<void> _upsertUserDocument(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await docRef.set(
      {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'providerIds': user.providerData
            .map((provider) => provider.providerId)
            .toList(),
        'updatedAt': now,
        'lastLoginAt': now,
        'createdAt': now,
      },
      SetOptions(merge: true),
    );
  }

  AppUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
  }

  Future<void> _guardFirebaseCall(Future<dynamic> Function() action) async {
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_mapFirebaseError(error));
    } catch (_) {
      throw const AuthFailure(
        'Authentication is currently unavailable. Please try again.',
      );
    }
  }

  String _mapFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No network connection. Check your internet and retry.';
      default:
        final message = error.message;
        if (message != null && message.trim().isNotEmpty) {
          return message.trim();
        }
        return 'Authentication failed. Please try again.';
    }
  }

  String _mapGoogleSignInError(Object error) {
    if (error is FirebaseAuthException) {
      return _mapFirebaseError(error);
    }

    if (error is PlatformException) {
      final code = error.code.toLowerCase();
      final message = (error.message ?? '').toLowerCase();

      if (code.contains('network') || message.contains('network')) {
        return 'No network connection. Check your internet and retry.';
      }

      final hasApi10 = message.contains('apiexception: 10') ||
          message.contains('10:') ||
          message.contains('developer_error');
      if (hasApi10) {
        return 'Google sign-in is misconfigured for this app build. Add SHA-1 and SHA-256 for your Android app in Firebase, download a fresh google-services.json, then rebuild.';
      }

      if (code.contains('sign_in_canceled') || code.contains('canceled')) {
        return 'Google sign-in was cancelled.';
      }
    }

    final errorText = error.toString();
    final lowered = errorText.toLowerCase();
    if (lowered.contains('network_error') ||
        lowered.contains('network request failed')) {
      return 'No network connection. Check your internet and retry.';
    }

    if (lowered.contains('apiexception: 10') ||
        lowered.contains('developer_error')) {
      return 'Google sign-in is misconfigured for this app build. Add SHA-1 and SHA-256 for your Android app in Firebase, download a fresh google-services.json, then rebuild.';
    }

    return 'Google sign-in failed. Please try again.';
  }
}
