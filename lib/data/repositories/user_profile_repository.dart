import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Stream<Map<String, dynamic>?> watchProfile(String userId) {
    return _users.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data();
    });
  }

  Future<String?> getLanguageLevel(String userId) async {
    final snapshot = await _users.doc(userId).get();
    if (!snapshot.exists) return null;
    final data = snapshot.data();
    final level = data?['languageLevel'];
    if (level is String && level.trim().isNotEmpty) {
      return level.trim();
    }
    return null;
  }

  Future<void> upsertFromFirebaseUser(User user) async {
    final docRef = _users.doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(docRef);
      final existingData = existing.data();
      final existingLevel =
          existingData != null && existingData['languageLevel'] is String
          ? (existingData['languageLevel'] as String)
          : null;

      transaction.set(docRef, {
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'providerIds': user.providerData
            .map((provider) => provider.providerId)
            .toList(),
        if (existingLevel != null) 'languageLevel': existingLevel,
        'updatedAt': now,
        'lastLoginAt': now,
        if (existingData == null) 'createdAt': now,
      }, SetOptions(merge: true));
    });
  }

  Future<void> setLanguageLevel(String userId, String languageLevel) async {
    await _users.doc(userId).set({
      'languageLevel': languageLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
