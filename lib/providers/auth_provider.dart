import 'package:flutter/foundation.dart';

/// Placeholder authentication provider.
class AuthProvider extends ChangeNotifier {
  bool _loggedIn = true; // Start as logged in for testing

  bool get loggedIn => _loggedIn;

  void login() {
    _loggedIn = true;
    notifyListeners();
  }

  void logout() {
    _loggedIn = false;
    notifyListeners();
  }
}
