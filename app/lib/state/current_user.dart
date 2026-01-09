import 'package:app/models/user.dart';

class CurrentUser {
  static User? user;
  static bool get isLoggedIn => user != null;

  static void set(User u) {
    user = u;
  }
  static void clear() {
    user = null;
  }
}