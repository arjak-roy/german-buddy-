import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  static Future<void> ensureInitialized() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        return;
      }
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('Firebase init skipped: $error');
    }
  }
}
