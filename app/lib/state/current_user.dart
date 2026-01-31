import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/models/user.dart';

class CurrentUser {
  static User? user;
  static bool get isLoggedIn => user != null;

  static Future<void> set(User u) async {
    user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', u.username);
  }

  static Future<void> clear() async {
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
  }

  /// Minimal persistence restore (no Firestore fetch yet)
  static Future<void> restoreIfPossible() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (username != null && user == null) {
      // Temporary placeholder user (safe for now)
      user = User(username, '', [], [], [], 0);
    }
  }

  /// Minimal persistence restore (no Firestore fetch yet)
  static Future<void> restoreIfPossible() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');

    if (username != null && user == null) {
      // Temporary placeholder user (safe for now)
      user = User(
        username,
        '',
        [],
        [],
        [],
        0,
      );
    }
  }
}