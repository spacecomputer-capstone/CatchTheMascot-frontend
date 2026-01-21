import 'package:app/models/user.dart';

class CurrentUser {
  static User? user;
  static bool get isLoggedIn => user != null;
  static int get coins => user?.coins ?? 0;
  
  static set coins(int value) {
    if (user != null) {
      user!.coins = value;
    }
  }

  static void set(User u) {
    user = u;
  }

  static void clear() {
    user = null;
  }
}
