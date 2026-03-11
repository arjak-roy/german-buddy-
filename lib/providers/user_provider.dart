import 'package:flutter/foundation.dart';

/// Simple user data holder for demonstration.
class UserProvider extends ChangeNotifier {
  String? _name;

  String? get name => _name;

  void setName(String newName) {
    _name = newName;
    notifyListeners();
  }
}
